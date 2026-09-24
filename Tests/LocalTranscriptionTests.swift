import Foundation

private final class StageRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: [LocalTranscriptionStage] = []

    func append(_ stage: LocalTranscriptionStage) {
        lock.lock()
        stages.append(stage)
        lock.unlock()
    }

    func snapshot() -> [LocalTranscriptionStage] {
        lock.lock()
        defer { lock.unlock() }
        return stages
    }
}

enum LocalTranscriptionTests {
    static func run() async throws {
        TestSupport.expectEqual(
            LocalModelPreparationStage.downloading(percent: 42).message(for: .heavy),
            "Downloading Heavy model… 42%"
        )
        TestSupport.expectEqual(
            LocalTranscriptionStage.transcribing.message(for: .heavy),
            "Heavy model ready — transcribing locally…"
        )
        TestSupport.expectEqual(TranscriptionService.suggestedAudioContext(forDuration: 1), 768)
        TestSupport.expectEqual(TranscriptionService.suggestedAudioContext(forDuration: 6), 768)
        TestSupport.expectEqual(TranscriptionService.suggestedAudioContext(forDuration: 12), 1024)
        TestSupport.expectEqual(TranscriptionService.suggestedAudioContext(forDuration: 16), nil)

        let testURL = URL(fileURLWithPath: "/synthetic.wav")
        let arguments = TranscriptionService.arguments(
            modelURL: testURL,
            fileURL: testURL,
            outputPrefix: testURL,
            language: "en",
            audioContext: 768,
            useGPU: true
        )
        TestSupport.expect(arguments.contains("-ac"), "Short Heavy dictation should set an audio context")
        TestSupport.expect(arguments.contains("768"), "Audio context should match the short clip")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("localflow-transcription-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("fake-whisper-cli")
        let fixture = """
        #!/bin/sh
        output=''
        gpu='yes'
        context=''
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -of) shift; output="$1" ;;
                -ac) shift; context="$1" ;;
                -ng) gpu='no' ;;
            esac
            shift
        done
        if [ "$context" != '768' ]; then exit 4; fi
        if [ "$gpu" = 'yes' ]; then exit 6; fi
        printf 'synthetic transcript\\n' > "${output}.txt"
        """
        try fixture.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let audio = directory.appendingPathComponent("synthetic.wav")
        let model = directory.appendingPathComponent("synthetic.bin")
        var wave = Data("RIFF".utf8)
        func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
            var encoded = value.littleEndian
            withUnsafeBytes(of: &encoded) { wave.append(contentsOf: $0) }
        }
        appendLittleEndian(UInt32(36 + 32_000))
        wave.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16))
        appendLittleEndian(UInt16(1))
        appendLittleEndian(UInt16(1))
        appendLittleEndian(UInt32(16_000))
        appendLittleEndian(UInt32(32_000))
        appendLittleEndian(UInt16(2))
        appendLittleEndian(UInt16(16))
        wave.append(contentsOf: "data".utf8)
        appendLittleEndian(UInt32(32_000))
        wave.append(contentsOf: repeatElement(UInt8(0), count: 32_000))
        try wave.write(to: audio)
        try Data().write(to: model)

        let recorder = StageRecorder()
        let service = try TranscriptionService(mode: .heavy, language: "en")
        let transcript = try await service.transcribe(
            fileURL: audio,
            modelURL: model,
            executable: executable,
            onStage: { recorder.append($0) }
        )
        TestSupport.expectEqual(transcript, "synthetic transcript")
        TestSupport.expectEqual(recorder.snapshot(), [.transcribing, .retryingWithoutGPU])
    }
}
