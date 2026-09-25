import Foundation

@main
struct LocalFlowTests {
    static func main() async throws {
        AppContextServiceTests.run()
        ModelConfigurationTests.run()
        LocalDictationModeTests.run()
        ShortcutCoreTests.run()
        SemanticVersionTests.run()
        LLMCooldownManagerTests.run()
        TranscriptionErrorPresentationCoreTests.run()
        try await LocalTranscriptionTests.run()
        TranscriptTextCoreTests.run()
        print("LocalFlowTests passed")
    }
}
