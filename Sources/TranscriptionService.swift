import AVFoundation
import Foundation

enum TranscriptionError: LocalizedError {
    case missingRuntime
    case inferenceFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingRuntime:
            "Install whisper.cpp (brew install whisper.cpp) before using PrivateFlow."
        case .inferenceFailed:
            "Local Whisper transcription failed. Check that whisper-cli can run on this Mac."
        case .emptyResponse:
            "Local Whisper returned an empty transcript."
        }
    }
}

enum LocalTranscriptionStage: Sendable, Equatable {
    case model(LocalModelPreparationStage)
    case transcribing
    case retryingWithoutGPU

    func message(for mode: LocalDictationMode) -> String {
        switch self {
        case .model(let stage): stage.message(for: mode)
        case .transcribing: "\(mode.title) model ready — transcribing locally…"
        case .retryingWithoutGPU: "\(mode.title) model ready — retrying on CPU…"
        }
    }
}

/// Runs the selected Whisper model in a local whisper.cpp process. Audio is
/// passed as a file path, never uploaded to a transcription provider.
final class TranscriptionService {
    private let mode: LocalDictationMode
    private let language: String

    init(mode: LocalDictationMode, language: String? = nil) throws {
        self.mode = mode
        self.language = language?.isEmpty == false ? language! : "auto"
    }

    func transcribe(
        fileURL: URL,
        onStage: (@Sendable (LocalTranscriptionStage) -> Void)? = nil
    ) async throws -> String {
        guard let executable = Self.whisperExecutable() else {
            throw TranscriptionError.missingRuntime
        }
        let modelURL = try await LocalModelManager.shared.ensureReady(for: mode) { stage in
            onStage?(.model(stage))
        }
        try Task.checkCancellation()
        return try await transcribe(
            fileURL: fileURL,
            modelURL: modelURL,
            executable: executable,
            onStage: onStage
        )
    }

    // Keep the process runner separate so a synthetic CLI can verify the CPU fallback.
    func transcribe(
        fileURL: URL,
        modelURL: URL,
        executable: URL,
        onStage: (@Sendable (LocalTranscriptionStage) -> Void)? = nil
    ) async throws -> String {
        let outputPrefix = FileManager.default.temporaryDirectory
            .appendingPathComponent("privateflow-\(UUID().uuidString)")
        let outputURL = outputPrefix.appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let audioContext = mode == .extraHeavy ? nil : Self.audioContext(for: fileURL)
        let beamSize = Self.beamSize(for: mode)

        onStage?(.transcribing)
        var status = try await runWhisper(
            executable: executable,
            modelURL: modelURL,
            fileURL: fileURL,
            outputPrefix: outputPrefix,
            audioContext: audioContext,
            beamSize: beamSize,
            useGPU: true
        )
        if status != 0 {
            try Task.checkCancellation()
            onStage?(.retryingWithoutGPU)
            try? FileManager.default.removeItem(at: outputURL)
            status = try await runWhisper(
                executable: executable,
                modelURL: modelURL,
                fileURL: fileURL,
                outputPrefix: outputPrefix,
                audioContext: audioContext,
                beamSize: beamSize,
                useGPU: false
            )
        }
        try Task.checkCancellation()
        guard status == 0 else { throw TranscriptionError.inferenceFailed }
        guard let transcript = try? String(contentsOf: outputURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty else {
            throw TranscriptionError.emptyResponse
        }
        return transcript
    }

    private func runWhisper(
        executable: URL,
        modelURL: URL,
        fileURL: URL,
        outputPrefix: URL,
        audioContext: Int?,
        beamSize: Int?,
        useGPU: Bool
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = Self.arguments(
            modelURL: modelURL,
            fileURL: fileURL,
            outputPrefix: outputPrefix,
            language: language,
            audioContext: audioContext,
            beamSize: beamSize,
            useGPU: useGPU
        )
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                process.terminationHandler = { finished in
                    continuation.resume(returning: finished.terminationStatus)
                }
                do {
                    try Task.checkCancellation()
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    static func arguments(
        modelURL: URL,
        fileURL: URL,
        outputPrefix: URL,
        language: String,
        audioContext: Int? = nil,
        beamSize: Int? = nil,
        useGPU: Bool
    ) -> [String] {
        var arguments = [
            "-m", modelURL.path,
            "-f", fileURL.path,
            "-l", language,
            "-otxt", "-of", outputPrefix.path,
            "-np"
        ]
        if let audioContext { arguments += ["-ac", String(audioContext)] }
        if let beamSize { arguments += ["-bs", String(beamSize)] }
        if !useGPU { arguments.append("-ng") }
        return arguments
    }

    // Normal favors prompt dictation. Heavy and Extra Heavy retain Whisper's
    // default beam search for users who chose those modes for accuracy.
    static func beamSize(for mode: LocalDictationMode) -> Int? {
        mode == .normal ? 1 : nil
    }

    private static func audioContext(for fileURL: URL) -> Int? {
        guard let audioFile = try? AVAudioFile(forReading: fileURL),
              audioFile.processingFormat.sampleRate > 0 else { return nil }
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        return suggestedAudioContext(forDuration: duration)
    }

    // Whisper normally encodes a full 30-second window even for a short clip.
    // Leave ample padding for the final words; short contexts can repeat text.
    static func suggestedAudioContext(forDuration duration: TimeInterval) -> Int? {
        guard duration.isFinite, duration > 0, duration <= 15 else { return nil }
        let paddedFrames = duration * 50 + 384
        return max(768, Int(ceil(paddedFrames / 64)) * 64)
    }

    private static func whisperExecutable() -> URL? {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("whisper-cli")
        let candidates = [
            bundled,
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
