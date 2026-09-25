import Foundation

enum LocalDictationModeTests {
    static func run() {
        TestSupport.expectEqual(LocalDictationMode.allCases.count, 3)
        TestSupport.expectEqual(LocalDictationMode.normal.whisperModel, "small")
        TestSupport.expectEqual(LocalDictationMode.heavy.whisperModel, "large-v3-turbo")
        TestSupport.expectEqual(LocalDictationMode.extraHeavy.whisperModel, "large-v3")
        for mode in LocalDictationMode.allCases {
            TestSupport.expect(mode.whisperDownloadURL.lastPathComponent == mode.whisperFileName, "Wrong model download URL")
            TestSupport.expect(mode.whisperSHA1.count == 40, "Missing model checksum")
        }
    }
}
