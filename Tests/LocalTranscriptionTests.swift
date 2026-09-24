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

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("localflow-transcription-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("fake-whisper-cli")
        let fixture = """
        #!/bin/sh
        output=''
        gpu='yes'
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -of) shift; output="$1" ;;
                -ng) gpu='no' ;;
            esac
            shift
        done
        if [ "$gpu" = 'yes' ]; then exit 6; fi
        printf 'synthetic transcript\\n' > "${output}.txt"
        """
        try fixture.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        let audio = directory.appendingPathComponent("synthetic.wav")
        let model = directory.appendingPathComponent("synthetic.bin")
        try Data().write(to: audio)
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
