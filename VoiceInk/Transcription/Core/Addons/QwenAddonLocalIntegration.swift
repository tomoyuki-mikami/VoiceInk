import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class QwenAddonLocalIntegration: AddonLocalModelIntegration {
    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let modelManager: QwenModelManager
    private let transcriptionService: QwenTranscriptionService

    init(modelManager: QwenModelManager) {
        self.modelManager = modelManager
        self.transcriptionService = QwenTranscriptionService(modelProvider: modelManager)

        modelManager.onModelDeleted = { [weak self] modelName in
            self?.onModelDeleted?(modelName)
        }
        modelManager.onModelsChanged = { [weak self] in
            self?.onModelsChanged?()
        }
    }

    var models: [any AddonLocalModel] {
        AddonLocalModels.qwenModels.map { $0 as any AddonLocalModel }
    }

    var recommendedModelNames: [String] {
        ["qwen3-asr-0.6b-4bit"]
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
        model is QwenLocalModel
    }

    func isModelDownloaded(_ model: any AddonLocalModel) -> Bool {
        guard let qwenModel = model as? QwenLocalModel else { return false }
        return modelManager.isModelDownloaded(named: qwenModel.name)
    }

    func progressMap(for model: any AddonLocalModel) -> [String: Double] {
        guard let qwenModel = model as? QwenLocalModel,
              modelManager.downloadInProgress.contains(qwenModel.name) else {
            return [:]
        }

        return [qwenModel.name: 0.0]
    }

    func service(for model: any AddonLocalModel) -> TranscriptionService {
        transcriptionService
    }

    func downloadModel(_ model: any AddonLocalModel) async {
        guard let qwenModel = model as? QwenLocalModel else { return }
        await modelManager.downloadModel(qwenModel)
    }

    func deleteModel(_ model: any AddonLocalModel) async {
        guard let qwenModel = model as? QwenLocalModel else { return }
        await modelManager.deleteModel(qwenModel)
    }

    func prepareModel(_ model: any AddonLocalModel) async throws {
        guard let qwenModel = model as? QwenLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        try await modelManager.loadModel(qwenModel)
    }

    func unloadModelResources() {
        modelManager.unloadModel()
    }

    func cleanupResources() async {
        modelManager.unloadModel()
    }

    func showModelInFinder(_ model: any AddonLocalModel) {
        guard let qwenModel = model as? QwenLocalModel else { return }
        NSWorkspace.shared.selectFile(qwenModel.storageDirectory.path, inFileViewerRootedAtPath: "")
    }

    func cardView(
        for model: any AddonLocalModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView {
        guard let qwenModel = model as? QwenLocalModel else {
            return AnyView(EmptyView())
        }

        return AnyView(
            QwenModelCardView(
                model: qwenModel,
                isDownloaded: isDownloaded,
                isCurrent: isCurrent,
                isPreparing: modelManager.downloadInProgress.contains(qwenModel.name),
                deleteAction: deleteAction,
                setDefaultAction: setDefaultAction,
                downloadAction: downloadAction
            )
        )
    }
}
