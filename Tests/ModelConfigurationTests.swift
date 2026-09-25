import Foundation

enum ModelConfigurationTests {
    static func run() {
        TestSupport.expectEqual(ModelConfiguration.llmModels, [])
        TestSupport.expectEqual(ModelConfiguration.visionModels, [])
        TestSupport.expectEqual(Set(ModelConfiguration.transcriptionModels), Set(["small", "large-v3-turbo", "large-v3"]))
        TestSupport.expectEqual(
            ModelConfiguration.stripThinkTags("<think>hidden</think> Visible output"),
            "Visible output"
        )
        TestSupport.expectEqual(ModelConfiguration.stripThinkTags("<think>unfinished"), "")
    }
}
