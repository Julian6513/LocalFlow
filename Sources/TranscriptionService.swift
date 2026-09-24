import Foundation

enum TranscriptionError: LocalizedError {
    case missingRuntime
    case inferenceFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingRuntime:
            "Install whisper.cpp (brew install whisper.cpp) before using LocalFlow."
        case .inferenceFailed:
            "Local Whisper transcription failed. Check that whisper-cli can run on this Mac."
        case .emptyResponse:
            "Local Whisper returned an empty transcript."
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

    func transcribe(fileURL: URL) async throws -> String {
        guard let executable = Self.whisperExecutable() else {
            throw TranscriptionError.missingRuntime
        }
        let modelURL = try await LocalModelManager.shared.ensureReady(for: mode)
        try Task.checkCancellation()

        let outputPrefix = FileManager.default.temporaryDirectory
            .appendingPathComponent("localflow-\(UUID().uuidString)")
        let outputURL = outputPrefix.appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-m", modelURL.path,
            "-f", fileURL.path,
            "-l", language,
            "-otxt", "-of", outputPrefix.path,
            "-np"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let status = try await withTaskCancellationHandler {
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
        try Task.checkCancellation()
        guard status == 0 else { throw TranscriptionError.inferenceFailed }
        guard let transcript = try? String(contentsOf: outputURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty else {
            throw TranscriptionError.emptyResponse
        }
        return transcript
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
