import Foundation
import SwiftUI
import Combine

@MainActor
final class JapaneseParakeetAddonLocalIntegration: AddonLocalModelIntegration {
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let modelManager: JapaneseParakeetModelManager
    private let transcriptionService: JapaneseParakeetTranscriptionService

    init(modelManager: JapaneseParakeetModelManager) {
        self.modelManager = modelManager
        self.transcriptionService = JapaneseParakeetTranscriptionService()

        modelManager.onModelDeleted = { [weak self] modelName in
            self?.onModelDeleted?(modelName)
        }
        modelManager.onModelsChanged = { [weak self] in
            self?.onModelsChanged?()
        }
    }

    var models: [any AddonLocalModel] {
        AddonLocalModels.japaneseParakeetModels.map { $0 as any AddonLocalModel }
    }

    var recommendedModelNames: [String] {
        ["parakeet-tdt_ctc-0.6b-ja"]
    }

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        modelManager.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func createModelsDirectoryIfNeeded() {}

    func refreshAvailableModels() {
        onModelsChanged?()
    }

    func handles(_ model: any TranscriptionModel) -> Bool {
        model is JapaneseParakeetLocalModel
    }

    func isModelDownloaded(_ model: any AddonLocalModel) -> Bool {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel else { return false }
        return modelManager.isModelDownloaded(japaneseModel)
    }

    func progressMap(for model: any AddonLocalModel) -> [String: Double] {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel,
              modelManager.downloadInProgress else {
            return [:]
        }

        return [japaneseModel.name: modelManager.downloadProgress]
    }

    func service(for model: any AddonLocalModel) -> TranscriptionService {
        transcriptionService
    }

    func downloadModel(_ model: any AddonLocalModel) async {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel else { return }
        await modelManager.downloadModel(japaneseModel)
    }

    func deleteModel(_ model: any AddonLocalModel) async {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel else { return }
        await modelManager.deleteModel(japaneseModel)
    }

    func prepareModel(_ model: any AddonLocalModel) async throws {
        guard model is JapaneseParakeetLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        try await transcriptionService.prepareModel()
    }

    func unloadModelResources() {}

    func cleanupResources() async {
        await transcriptionService.cleanup()
    }

    func showModelInFinder(_ model: any AddonLocalModel) {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel else { return }
        modelManager.showModelInFinder(japaneseModel)
    }

    func cardView(
        for model: any AddonLocalModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView {
        guard let japaneseModel = model as? JapaneseParakeetLocalModel else {
            return AnyView(EmptyView())
        }

        return AnyView(
            JapaneseParakeetModelCardView(
                model: japaneseModel,
                isDownloaded: isDownloaded,
                isCurrent: isCurrent,
                isDownloading: modelManager.downloadInProgress,
                downloadProgress: modelManager.downloadProgress,
                deleteAction: deleteAction,
                setDefaultAction: setDefaultAction,
                downloadAction: downloadAction,
                showInFinderAction: { self.showModelInFinder(japaneseModel) }
            )
        )
    }
}
