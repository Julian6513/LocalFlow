import CryptoKit
import Foundation

enum LocalModelPreparationStage: Sendable, Equatable {
    case checking
    case downloading(percent: Int?)
    case verifying
    case ready

    func message(for mode: LocalDictationMode) -> String {
        switch self {
        case .checking: "Checking \(mode.title) model…"
        case .downloading(let percent):
            if let percent { "Downloading \(mode.title) model… \(percent)%" }
            else { "Downloading \(mode.title) model…" }
        case .verifying: "Verifying \(mode.title) model…"
        case .ready: "\(mode.title) model download complete"
        }
    }
}

private final class ModelDownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int) -> Void
    private let lock = NSLock()
    private var lastPercent = -1

    init(onProgress: @escaping @Sendable (Int) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let percent = min(100, Int(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100))
        lock.lock()
        let changed = percent != lastPercent
        if changed { lastPercent = percent }
        lock.unlock()
        if changed { onProgress(percent) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

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
        return support.appendingPathComponent(AppName.modelStorageName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(mode.whisperFileName)
    }

    func ensureReady(
        for mode: LocalDictationMode,
        onStage: (@Sendable (LocalModelPreparationStage) -> Void)? = nil
    ) async throws -> URL {
        let modelURL = try await ensureWhisperModel(for: mode, onStage: onStage)
        try Task.checkCancellation()
        return modelURL
    }

    private func ensureWhisperModel(
        for mode: LocalDictationMode,
        onStage: (@Sendable (LocalModelPreparationStage) -> Void)?
    ) async throws -> URL {
        try Task.checkCancellation()
        onStage?(.checking)
        let destination = try Self.modelURL(for: mode)
        if verifiedWhisperModels.contains(mode.whisperModel),
           FileManager.default.fileExists(atPath: destination.path) {
            onStage?(.ready)
            return destination
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            onStage?(.verifying)
            guard try Self.sha1(of: destination) == mode.whisperSHA1 else {
                try? FileManager.default.removeItem(at: destination)
                throw LocalModelError.invalidModelFile
            }
            verifiedWhisperModels.insert(mode.whisperModel)
            onStage?(.ready)
            return destination
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let (temporaryURL, response): (URL, URLResponse)
        onStage?(.downloading(percent: nil))
        do {
            if let onStage {
                let delegate = ModelDownloadProgressDelegate { percent in
                    onStage(.downloading(percent: percent))
                }
                (temporaryURL, response) = try await session.download(
                    from: mode.whisperDownloadURL,
                    delegate: delegate
                )
            } else {
                (temporaryURL, response) = try await session.download(from: mode.whisperDownloadURL)
            }
        } catch {
            throw LocalModelError.downloadFailed(error.localizedDescription)
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LocalModelError.downloadFailed("the model host returned an error")
        }
        onStage?(.verifying)
        guard try Self.sha1(of: temporaryURL) == mode.whisperSHA1 else {
            throw LocalModelError.invalidModelFile
        }
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        verifiedWhisperModels.insert(mode.whisperModel)
        onStage?(.ready)
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
