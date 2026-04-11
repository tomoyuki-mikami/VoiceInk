import SwiftUI

struct ModelDeletionRequest {
    let title: String
    let message: String
    let action: () -> Void
}

struct AddonAwareModelManagementContentView: View {
    let selectedFilter: ModelFilter
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let transcriptionModelManager: TranscriptionModelManager

    var requestDeleteConfirmation: (ModelDeletionRequest) -> Void

    var body: some View {
        if selectedFilter == .local && !addonLocalModelCatalog.availableModels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Additional Local Models")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(addonLocalModelCatalog.availableModels, id: \.name) { model in
                    let transcriptionModel = model as any TranscriptionModel
                    let isDownloaded = addonLocalModelCatalog.isModelDownloaded(model)

                    if let card = addonLocalModelCatalog.cardView(
                        for: transcriptionModel,
                        isDownloaded: isDownloaded,
                        isCurrent: transcriptionModelManager.currentTranscriptionModel?.name == model.name,
                        deleteAction: {
                            guard let request = deletionRequest(for: model) else { return }
                            requestDeleteConfirmation(request)
                        },
                        setDefaultAction: {
                            Task {
                                transcriptionModelManager.setDefaultTranscriptionModel(transcriptionModel)
                            }
                        },
                        downloadAction: {
                            Task {
                                await addonLocalModelCatalog.downloadModel(model)
                            }
                        }
                    ) {
                        card
                    }
                }
            }
        }
    }

    private func deletionRequest(for model: any AddonLocalModel) -> ModelDeletionRequest? {
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
}
