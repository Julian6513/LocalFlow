import Foundation

@main
struct PrivateFlowTests {
    static func main() async throws {
        try AppNameTests.run()
        AppContextServiceTests.run()
        ModelConfigurationTests.run()
        LocalDictationModeTests.run()
        ShortcutCoreTests.run()
        SemanticVersionTests.run()
        LLMCooldownManagerTests.run()
        TranscriptionErrorPresentationCoreTests.run()
        try await LocalTranscriptionTests.run()
        TranscriptTextCoreTests.run()
        print("PrivateFlowTests passed")
    }
}
