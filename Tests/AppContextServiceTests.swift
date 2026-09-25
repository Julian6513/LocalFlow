import Foundation

enum AppContextServiceTests {
    static func run() {
        let output = "The user is editing a project note. They want to tighten the release wording. A third sentence should be dropped."
        let summary = AppContextService.activitySummary(from: output, model: "")
        TestSupport.expectEqual(
            summary,
            "The user is editing a project note. They want to tighten the release wording."
        )
        TestSupport.expect(!ModelConfiguration.llmModels.contains("openai/gpt-oss-20b"), "Cloud model exposed")
    }
}
