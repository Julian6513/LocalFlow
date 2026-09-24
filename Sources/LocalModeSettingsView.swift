import SwiftUI

struct LocalModeSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Dictation mode", selection: $appState.dictationMode) {
                ForEach(LocalDictationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(appState.isRecording || appState.isTranscribing)

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

            if let preparationStage = appState.localModelPreparationStage,
               preparationStage != .ready {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(preparationStage.message(for: appState.dictationMode))
                }
                .font(.caption)
            } else if let error = appState.localModelPreparationError {
                HStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Retry") { appState.prepareSelectedModel() }
                }
                .font(.caption)
            } else if appState.localModelPreparationStage == .ready {
                Label("\(appState.dictationMode.title) model download complete — ready on this Mac", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .onAppear { appState.prepareSelectedModel() }
    }
}
