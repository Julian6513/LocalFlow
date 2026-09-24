import Foundation

enum LocalDictationMode: String, CaseIterable, Identifiable, Sendable {
    case normal
    case heavy
    case extraHeavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .heavy: "Heavy"
        case .extraHeavy: "Extra Heavy"
        }
    }

    var whisperModel: String {
        switch self {
        case .normal: "small"
        case .heavy: "large-v3-turbo"
        case .extraHeavy: "large-v3"
        }
    }

    var whisperSHA1: String {
        switch self {
        case .normal: "55356645c2b361a969dfd0ef2c5a50d530afd8d5"
        case .heavy: "4af2b29d7ec73d781377bfd1758ca957a807e941"
        case .extraHeavy: "ad82bf6a9043ceed055076d0fd39f5f186ff8062"
        }
    }

    var recommendedMac: String {
        switch self {
        case .normal: "M1 MacBook Air, 8 GB unified memory"
        case .heavy: "M1 MacBook Air, 8 GB unified memory"
        case .extraHeavy: "M1 Pro MacBook Pro, 16 GB unified memory"
        }
    }

    var summary: String {
        "Whisper \(whisperModel) · \(recommendedMac)"
    }

    var whisperFileName: String { "ggml-\(whisperModel).bin" }

    var whisperDownloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(whisperFileName)")!
    }
}
