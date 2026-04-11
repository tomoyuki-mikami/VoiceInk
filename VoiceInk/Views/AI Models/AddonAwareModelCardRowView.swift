import SwiftUI

struct AddonAwareModelCardRowView: View {
    let model: any TranscriptionModel
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let fluidAudioModelManager: FluidAudioModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let isDownloaded: Bool
    let isCurrent: Bool
    let downloadProgress: [String: Double]
    let modelURL: URL?
    let isWarming: Bool

    var deleteAction: () -> Void
    var setDefaultAction: () -> Void
    var downloadAction: () -> Void
    var editAction: ((CustomCloudModel) -> Void)?

    var body: some View {
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
            ModelCardRowView(
                model: model,
                fluidAudioModelManager: fluidAudioModelManager,
                transcriptionModelManager: transcriptionModelManager,
                isDownloaded: isDownloaded,
                isCurrent: isCurrent,
                downloadProgress: downloadProgress,
                modelURL: modelURL,
                isWarming: isWarming,
                deleteAction: deleteAction,
                setDefaultAction: setDefaultAction,
                downloadAction: downloadAction,
                editAction: editAction
            )
        }
    }
}
