import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class CohereAddonLocalIntegration: AddonLocalModelIntegration {
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let modelManager: CohereModelManager
    private let transcriptionService: CohereTranscriptionService

    init(modelManager: CohereModelManager) {
        self.modelManager = modelManager
        self.transcriptionService = CohereTranscriptionService(modelProvider: modelManager)

        modelManager.onModelDeleted = { [weak self] modelName in
            self?.onModelDeleted?(modelName)
        }
        modelManager.onModelsChanged = { [weak self] in
            self?.onModelsChanged?()
        }
    }

    var models: [any AddonLocalModel] {
        AddonLocalModels.cohereModels.map { $0 as any AddonLocalModel }
    }

    var recommendedModelNames: [String] {
        ["cohere-transcribe-03-2026-mlx-fp16"]
    }

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        modelManager.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func createModelsDirectoryIfNeeded() {
        modelManager.createModelsDirectoryIfNeeded()
    }

    func refreshAvailableModels() {
        modelManager.refreshAvailableModels()
    }

    func handles(_ model: any TranscriptionModel) -> Bool {
        model is CohereLocalModel
    }

    func isModelDownloaded(_ model: any AddonLocalModel) -> Bool {
        guard let cohereModel = model as? CohereLocalModel else { return false }
        return modelManager.isModelDownloaded(named: cohereModel.name)
    }

    func progressMap(for model: any AddonLocalModel) -> [String: Double] {
        guard let cohereModel = model as? CohereLocalModel,
              modelManager.downloadInProgress.contains(cohereModel.name) else {
            return [:]
        }

        return [cohereModel.name: 0.0]
    }

    func service(for model: any AddonLocalModel) -> TranscriptionService {
        transcriptionService
    }

    func downloadModel(_ model: any AddonLocalModel) async {
        guard let cohereModel = model as? CohereLocalModel else { return }
        await modelManager.downloadModel(cohereModel)
    }

    func deleteModel(_ model: any AddonLocalModel) async {
        guard let cohereModel = model as? CohereLocalModel else { return }
        await modelManager.deleteModel(cohereModel)
    }

    func prepareModel(_ model: any AddonLocalModel) async throws {
        guard let cohereModel = model as? CohereLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        try await modelManager.loadModel(cohereModel)
    }

    func unloadModelResources() {
        modelManager.unloadModel()
    }

    func cleanupResources() async {
        modelManager.unloadModel()
    }

    func showModelInFinder(_ model: any AddonLocalModel) {
        guard let cohereModel = model as? CohereLocalModel else { return }
        NSWorkspace.shared.selectFile(cohereModel.storageDirectory.path, inFileViewerRootedAtPath: "")
    }

    func cardView(
        for model: any AddonLocalModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView {
        guard let cohereModel = model as? CohereLocalModel else {
            return AnyView(EmptyView())
        }

        return AnyView(
            CohereModelCardView(
                model: cohereModel,
                isDownloaded: isDownloaded,
                isCurrent: isCurrent,
                isPreparing: modelManager.downloadInProgress.contains(cohereModel.name),
                deleteAction: deleteAction,
                setDefaultAction: setDefaultAction,
                downloadAction: downloadAction
            )
        )
    }
}
