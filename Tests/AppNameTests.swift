import Foundation

enum AppNameTests {
    static func run() throws {
        let support = FileManager.default.temporaryDirectory
            .appendingPathComponent("privateflow-storage-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: support) }
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        TestSupport.expectEqual(AppName.storageName(in: support), "PrivateFlow")

        try FileManager.default.createDirectory(
            at: support.appendingPathComponent("LocalFlow"), withIntermediateDirectories: true
        )
        TestSupport.expectEqual(AppName.storageName(in: support), "LocalFlow")

        try FileManager.default.createDirectory(
            at: support.appendingPathComponent("PrivateFlow"), withIntermediateDirectories: true
        )
        TestSupport.expectEqual(AppName.storageName(in: support), "PrivateFlow")

        TestSupport.expectEqual(
            AppName.storageName(in: support, currentName: "PrivateFlow Dev", legacyName: "LocalFlow Dev"),
            "PrivateFlow Dev"
        )
        try FileManager.default.createDirectory(
            at: support.appendingPathComponent("LocalFlow Dev"), withIntermediateDirectories: true
        )
        TestSupport.expectEqual(
            AppName.storageName(in: support, currentName: "PrivateFlow Dev", legacyName: "LocalFlow Dev"),
            "LocalFlow Dev"
        )
    }
}
