import SwiftUI
import AppKit

struct ModelCardRowView: View {
    let model: any TranscriptionModel
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let fluidAudioModelManager: FluidAudioModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let isDownloaded: Bool
    let isCurrent: Bool
    let downloadProgress: [String: Double]
    let modelURL: URL?
    let isWarming: Bool

    // Actions
    var deleteAction: () -> Void
    var setDefaultAction: () -> Void
    var downloadAction: () -> Void
    var editAction: ((CustomCloudModel) -> Void)?
    var body: some View {
        Group {
            if let addonCard = addonLocalModelCatalog.cardView(
                for: model,
                isDownloaded: isDownloaded,
                isCurrent: isCurrent,
                deleteAction: deleteAction,
                setDefaultAction: setDefaultAction,
                downloadAction: downloadAction
            ) {
                addonCard
            } else {
            switch model.provider {
            case .local:
                if let localModel = model as? LocalModel {
                    LocalModelCardView(
                        model: localModel,
                        isDownloaded: isDownloaded,
                        isCurrent: isCurrent,
                        downloadProgress: downloadProgress,
                        modelURL: modelURL,
                        isWarming: isWarming,
                        deleteAction: deleteAction,
                        setDefaultAction: setDefaultAction,
                        downloadAction: downloadAction
                    )
                } else if let importedModel = model as? ImportedLocalModel {
                    ImportedLocalModelCardView(
                        model: importedModel,
                        isDownloaded: isDownloaded,
                        isCurrent: isCurrent,
                        modelURL: modelURL,
                        deleteAction: deleteAction,
                        setDefaultAction: setDefaultAction
                    )
                }
            case .fluidAudio:
                if let fluidAudioModel = model as? FluidAudioModel {
                    FluidAudioModelCardRowView(
                        model: fluidAudioModel,
                        fluidAudioModelManager: fluidAudioModelManager,
                        transcriptionModelManager: transcriptionModelManager
                    )
                }
            case .localAddon:
                // Add-on cards are rendered by AddonLocalModelCatalog before this switch.
                EmptyView()
            case .nativeApple:
                if let nativeAppleModel = model as? NativeAppleModel {
                    NativeAppleModelCardView(
                        model: nativeAppleModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction
                    )
                }
            case .groq, .elevenLabs, .deepgram, .mistral, .gemini, .soniox, .speechmatics:
                if let cloudModel = model as? CloudModel {
                    CloudModelCardView(
                        model: cloudModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction
                    )
                }
            case .custom:
                if let customModel = model as? CustomCloudModel {
                    CustomModelCardView(
                        model: customModel,
                        isCurrent: isCurrent,
                        setDefaultAction: setDefaultAction,
                        deleteAction: deleteAction,
                        editAction: editAction ?? { _ in }
                    )
                }
            }
            }
        }
    }
}
