import Foundation

@main
struct LocalFlowTests {
    static func main() {
        AppContextServiceTests.run()
        ModelConfigurationTests.run()
        LocalDictationModeTests.run()
        ShortcutCoreTests.run()
        SemanticVersionTests.run()
        LLMCooldownManagerTests.run()
        TranscriptionErrorPresentationCoreTests.run()
        TranscriptTextCoreTests.run()
        print("LocalFlowTests passed")
    }
}
