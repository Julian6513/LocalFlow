import Foundation

public struct ModelConfig {
    public let maxCompletionTokens: Int?
    public let reasoningEffort: String?
    public let includeReasoning: Bool?
    public let shouldStripThinkTags: Bool
}

public struct ModelConfiguration {
    public static let llmModels: [String] = []
    public static let visionModels: [String] = []
    public static let transcriptionModels = ["small", "large-v3-turbo", "large-v3"]

    public static func config(for model: String) -> ModelConfig {
        ModelConfig(
            maxCompletionTokens: nil,
            reasoningEffort: nil,
            includeReasoning: nil,
            shouldStripThinkTags: false
        )
    }

    /// Utility method to remove <think>...</think> tags and everything inside them.
    /// This also handles unclosed tags gracefully (e.g. if the model runs out of tokens).
    public static func stripThinkTags(_ text: String) -> String {
        var cleaned = text
        
        // First, replace fully closed tags: <think>...</think>
        // We use a group with + to catch multiple consecutive think blocks.
        let closedRegexPattern = "^(?:\\s*<think>[\\s\\S]*?</think>)+"
        if let regex = try? NSRegularExpression(pattern: closedRegexPattern, options: []) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // Next, if there is an unclosed <think> tag remaining (meaning it started thinking but got truncated),
        // we strip from the opening <think> tag to the very end of the string.
        let openRegexPattern = "^\\s*<think>[\\s\\S]*$"
        if let regex = try? NSRegularExpression(pattern: openRegexPattern, options: []) {
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
