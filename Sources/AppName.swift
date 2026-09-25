import Foundation

enum AppName {
    static let displayName: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PrivateFlow"

    // Upgraded installs may still have their models and run history in the
    // former app directory. Keep using it until the user moves that directory.
    static var storageName: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if displayName == "PrivateFlow Dev" {
            return storageName(in: support, currentName: "PrivateFlow Dev", legacyName: "LocalFlow Dev")
        }
        return storageName(in: support)
    }

    static var modelStorageName: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return storageName(in: support)
    }

    static func storageName(
        in applicationSupport: URL,
        currentName: String = "PrivateFlow",
        legacyName: String = "LocalFlow",
        fileManager: FileManager = .default
    ) -> String {
        if fileManager.fileExists(atPath: applicationSupport.appendingPathComponent(currentName).path) {
            return currentName
        }
        if fileManager.fileExists(atPath: applicationSupport.appendingPathComponent(legacyName).path) {
            return legacyName
        }
        return currentName
    }
}
