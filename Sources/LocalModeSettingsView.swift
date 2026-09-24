import SwiftUI

struct LocalModeSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var downloadTask: Task<Void, Never>?
    @State private var isDownloading = false
    @State private var status: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Dictation mode", selection: $appState.dictationMode) {
                ForEach(LocalDictationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ForEach(LocalDictationMode.allCases) { mode in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mode.title).fontWeight(mode == appState.dictationMode ? .semibold : .regular)
                        .frame(width: 85, alignment: .leading)
                    Text(mode.summary)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Text("Only the selected Whisper model is downloaded. Dictation runs on this Mac with whisper.cpp; no cloud AI account is needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isDownloading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Downloading \(appState.dictationMode.title) speech model…")
                }
                .font(.caption)
            } else if let status {
                HStack(spacing: 8) {
                    Label(status, systemImage: failed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(failed ? .orange : .green)
                    if failed {
                        Button("Retry") { prepare(appState.dictationMode) }
                    }
                }
                .font(.caption)
            }
        }
        .onAppear { prepare(appState.dictationMode) }
        .onChange(of: appState.dictationMode) { prepare($0) }
        .onDisappear { downloadTask?.cancel() }
    }

    private func prepare(_ mode: LocalDictationMode) {
        downloadTask?.cancel()
        isDownloading = true
        status = nil
        failed = false
        downloadTask = Task {
            do {
                _ = try await LocalModelManager.shared.ensureReady(for: mode)
                guard !Task.isCancelled, appState.dictationMode == mode else { return }
                status = "\(mode.title) model ready"
            } catch {
                guard !Task.isCancelled, appState.dictationMode == mode else { return }
                failed = true
                status = error.localizedDescription
            }
            if appState.dictationMode == mode { isDownloading = false }
        }
    }
}
