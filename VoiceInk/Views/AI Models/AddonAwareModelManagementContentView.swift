import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ModelDeletionRequest {
    let title: String
    let message: String
    let action: () -> Void
}

struct AddonAwareModelManagementContentView: View {
    let selectedFilter: ModelFilter
    let whisperModelManager: WhisperModelManager
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let fluidAudioModelManager: FluidAudioModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let customModelManager: CustomModelManager
    let warmupCoordinator: WhisperModelWarmupCoordinator

    @Binding var customModelToEdit: CustomCloudModel?

    var requestDeleteConfirmation: (ModelDeletionRequest) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(filteredModels, id: \.id) { model in
                let isWarming = (model as? LocalModel).map { localModel in
                    warmupCoordinator.isWarming(modelNamed: localModel.name)
                } ?? false

                AddonAwareModelCardRowView(
                    model: model,
                    addonLocalModelCatalog: addonLocalModelCatalog,
                    fluidAudioModelManager: fluidAudioModelManager,
                    transcriptionModelManager: transcriptionModelManager,
                    isDownloaded: isModelDownloaded(model),
                    isCurrent: transcriptionModelManager.currentTranscriptionModel?.name == model.name,
                    downloadProgress: downloadProgress(for: model),
                    modelURL: whisperModelManager.availableModels.first { $0.name == model.name }?.url,
                    isWarming: isWarming,
                    deleteAction: {
                        guard let request = deletionRequest(for: model) else { return }
                        requestDeleteConfirmation(request)
                    },
                    setDefaultAction: {
                        Task {
                            transcriptionModelManager.setDefaultTranscriptionModel(model)
                        }
                    },
                    downloadAction: {
                        if let localModel = model as? LocalModel {
                            Task { await whisperModelManager.downloadModel(localModel) }
                        } else if addonLocalModelCatalog.contains(model) {
                            Task { await addonLocalModelCatalog.downloadModel(model) }
                        }
                    },
                    editAction: model.provider == .custom ? { customModel in
                        customModelToEdit = customModel
                    } : nil
                )
            }

            if selectedFilter == .local {
                importLocalModelCard
            }

            if selectedFilter == .custom {
                customModelSection
            }
        }
    }

    private var importLocalModelCard: some View {
        HStack(spacing: 8) {
            Button(action: { presentImportPanel() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import Local Model…")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(CardBackground(isSelected: false))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            InfoTip(
                "Add a custom fine-tuned whisper model to use with VoiceInk. Select the downloaded .bin file.",
                learnMoreURL: "https://tryvoiceink.com/docs/custom-local-whisper-models"
            )
            .help("Read more about custom local models")
        }
    }

    private var customModelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                Text("Only OpenAI-compatible transcription APIs are supported.")
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 4)

            AddCustomModelCardView(
                customModelManager: customModelManager,
                onModelAdded: {
                    transcriptionModelManager.refreshAllAvailableModels()
                    customModelToEdit = nil
                },
                editingModel: customModelToEdit
            )
        }
    }

    private var filteredModels: [any TranscriptionModel] {
        switch selectedFilter {
        case .recommended:
            let recommendedNames = [
                "ggml-base.en",
                "parakeet-tdt-0.6b-v2",
                "ggml-large-v3-turbo-q5_0",
                "whisper-large-v3-turbo"
            ] + addonLocalModelCatalog.recommendedModelNames
            return transcriptionModelManager.allAvailableModels.filter {
                recommendedNames.contains($0.name)
            }.sorted { model1, model2 in
                let index1 = recommendedNames.firstIndex(of: model1.name) ?? Int.max
                let index2 = recommendedNames.firstIndex(of: model2.name) ?? Int.max
                return index1 < index2
            }
        case .local:
            return transcriptionModelManager.allAvailableModels.filter {
                $0.provider == .local ||
                addonLocalModelCatalog.contains($0) ||
                $0.provider == .nativeApple ||
                $0.provider == .fluidAudio
            }
        case .cloud:
            let cloudProviders: [ModelProvider] = [.groq, .elevenLabs, .deepgram, .mistral, .gemini, .soniox, .speechmatics]
            return transcriptionModelManager.allAvailableModels.filter { cloudProviders.contains($0.provider) }
        case .custom:
            return transcriptionModelManager.allAvailableModels.filter { $0.provider == .custom }
        }
    }

    private func isModelDownloaded(_ model: any TranscriptionModel) -> Bool {
        if addonLocalModelCatalog.contains(model) {
            return addonLocalModelCatalog.isModelDownloaded(model)
        }

        switch model.provider {
        case .local:
            return whisperModelManager.availableModels.contains { $0.name == model.name }
        default:
            return false
        }
    }

    private func downloadProgress(for model: any TranscriptionModel) -> [String: Double] {
        if addonLocalModelCatalog.contains(model) {
            return addonLocalModelCatalog.progressMap(for: model)
        }

        return whisperModelManager.downloadProgress
    }

    private func deletionRequest(for model: any TranscriptionModel) -> ModelDeletionRequest? {
        if let customModel = model as? CustomCloudModel {
            return ModelDeletionRequest(
                title: "Delete Custom Model",
                message: "Are you sure you want to delete the custom model '\(customModel.displayName)'?"
            ) {
                customModelManager.removeCustomModel(withId: customModel.id)
                transcriptionModelManager.refreshAllAvailableModels()
            }
        }

        if let downloadedModel = whisperModelManager.availableModels.first(where: { $0.name == model.name }) {
            return ModelDeletionRequest(
                title: "Delete Model",
                message: "Are you sure you want to delete the model '\(downloadedModel.name)'?"
            ) {
                Task {
                    await whisperModelManager.deleteModel(downloadedModel)
                }
            }
        }

        if addonLocalModelCatalog.isModelDownloaded(model) {
            return ModelDeletionRequest(
                title: "Delete Model",
                message: "Are you sure you want to delete the model '\(model.displayName)'?"
            ) {
                Task {
                    await addonLocalModelCatalog.deleteModel(model)
                }
            }
        }

        return nil
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.title = "Select a Whisper ggml .bin model"

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await whisperModelManager.importLocalModel(from: url)
            }
        }
    }
}
