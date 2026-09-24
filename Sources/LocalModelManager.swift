import CryptoKit
import Foundation

enum LocalModelError: LocalizedError {
    case downloadFailed(String)
    case invalidModelFile

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason): "Could not download the Whisper model: \(reason)"
        case .invalidModelFile: "The downloaded Whisper model failed its checksum. Try again."
        }
    }
}

/// Downloads only the selected GGML speech model into Application Support.
actor LocalModelManager {
    static let shared = LocalModelManager()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3600
        configuration.timeoutIntervalForResource = 3600
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
    private var verifiedWhisperModels: Set<String> = []

    static func modelURL(for mode: LocalDictationMode) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appendingPathComponent("LocalFlow", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(mode.whisperFileName)
    }

    func ensureReady(for mode: LocalDictationMode) async throws -> URL {
        let modelURL = try await ensureWhisperModel(for: mode)
        try Task.checkCancellation()
        return modelURL
    }

    private func ensureWhisperModel(for mode: LocalDictationMode) async throws -> URL {
        try Task.checkCancellation()
        let destination = try Self.modelURL(for: mode)
        if verifiedWhisperModels.contains(mode.whisperModel),
           FileManager.default.fileExists(atPath: destination.path) { return destination }
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try Self.sha1(of: destination) == mode.whisperSHA1 else {
                try? FileManager.default.removeItem(at: destination)
                throw LocalModelError.invalidModelFile
            }
            verifiedWhisperModels.insert(mode.whisperModel)
            return destination
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let (temporaryURL, response): (URL, URLResponse)
        do {
            (temporaryURL, response) = try await session.download(from: mode.whisperDownloadURL)
        } catch {
            throw LocalModelError.downloadFailed(error.localizedDescription)
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LocalModelError.downloadFailed("the model host returned an error")
        }
        guard try Self.sha1(of: temporaryURL) == mode.whisperSHA1 else {
            throw LocalModelError.invalidModelFile
        }
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        verifiedWhisperModels.insert(mode.whisperModel)
        return destination
    }

    private static func sha1(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = Insecure.SHA1()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
            try Task.checkCancellation()
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
