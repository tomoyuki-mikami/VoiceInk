import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
final class AddonLocalModelCatalog: ObservableObject {
    let qwenModelManager: QwenModelManager
    let japaneseParakeetModelManager: JapaneseParakeetModelManager

    private let qwenTranscriptionService: QwenTranscriptionService
    private let japaneseParakeetTranscriptionService: JapaneseParakeetTranscriptionService
    private var cancellables: Set<AnyCancellable> = []

    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    init(
        qwenModelManager: QwenModelManager,
        japaneseParakeetModelManager: JapaneseParakeetModelManager? = nil
    ) {
        self.qwenModelManager = qwenModelManager
        self.japaneseParakeetModelManager = japaneseParakeetModelManager ?? JapaneseParakeetModelManager()
        self.qwenTranscriptionService = QwenTranscriptionService(modelProvider: qwenModelManager)
        self.japaneseParakeetTranscriptionService = JapaneseParakeetTranscriptionService()

        bindManagers()
        wireCallbacks()
    }

    var availableModels: [any AddonLocalModel] {
        AddonLocalModels.allModels
    }

    var availableTranscriptionModels: [any TranscriptionModel] {
        availableModels.map { $0 as any TranscriptionModel }
    }

    func includes(_ model: any TranscriptionModel) -> Bool {
        model is any AddonLocalModel
    }

    func merged(into models: [any TranscriptionModel]) -> [any TranscriptionModel] {
        var mergedModels = models

        for addonModel in availableTranscriptionModels where !mergedModels.contains(where: { $0.name == addonModel.name }) {
            mergedModels.append(addonModel)
        }

        return mergedModels
    }

    func createModelsDirectoryIfNeeded() {
        qwenModelManager.createModelsDirectoryIfNeeded()
    }

    func refreshAvailableModels() {
        qwenModelManager.refreshAvailableModels()
        onModelsChanged?()
    }

    func isModelDownloaded(named name: String) -> Bool {
        if let model = AddonLocalModels.qwenModels.first(where: { $0.name == name }) {
            return qwenModelManager.isModelDownloaded(named: model.name)
        }

        if let model = AddonLocalModels.japaneseParakeetModels.first(where: { $0.name == name }) {
            return japaneseParakeetModelManager.isModelDownloaded(model)
        }

        return false
    }

    func isModelDownloaded(_ model: any TranscriptionModel) -> Bool {
        guard includes(model) else { return false }
        return isModelDownloaded(named: model.name)
    }

    func progressMap(for model: any TranscriptionModel) -> [String: Double] {
        if let qwenModel = model as? QwenLocalModel, qwenModelManager.downloadInProgress.contains(qwenModel.name) {
            return [qwenModel.name: 0.0]
        }

        if let japaneseModel = model as? JapaneseParakeetLocalModel, japaneseParakeetModelManager.downloadInProgress {
            return [japaneseModel.name: japaneseParakeetModelManager.downloadProgress]
        }

        return [:]
    }

    func service(for model: any TranscriptionModel) -> TranscriptionService? {
        switch model {
        case is QwenLocalModel:
            return qwenTranscriptionService
        case is JapaneseParakeetLocalModel:
            return japaneseParakeetTranscriptionService
        default:
            return nil
        }
    }

    func downloadModel(_ model: any AddonLocalModel) async {
        switch model {
        case let qwenModel as QwenLocalModel:
            await qwenModelManager.downloadModel(qwenModel)
        case let japaneseModel as JapaneseParakeetLocalModel:
            await japaneseParakeetModelManager.downloadModel(japaneseModel)
        default:
            break
        }
    }

    func downloadModel(_ model: any TranscriptionModel) async {
        guard let addonModel = model as? any AddonLocalModel else { return }
        await downloadModel(addonModel)
    }

    func deleteModel(_ model: any AddonLocalModel) async {
        switch model {
        case let qwenModel as QwenLocalModel:
            await qwenModelManager.deleteModel(qwenModel)
        case let japaneseModel as JapaneseParakeetLocalModel:
            await japaneseParakeetModelManager.deleteModel(japaneseModel)
        default:
            break
        }
    }

    func deleteModel(_ model: any TranscriptionModel) async {
        guard let addonModel = model as? any AddonLocalModel else { return }
        await deleteModel(addonModel)
    }

    func prepareModel(_ model: any AddonLocalModel) async throws {
        switch model {
        case let qwenModel as QwenLocalModel:
            try await qwenModelManager.loadModel(qwenModel)
        case is JapaneseParakeetLocalModel:
            try await japaneseParakeetTranscriptionService.prepareModel()
        default:
            throw VoiceInkEngineError.modelLoadFailed
        }
    }

    func unloadModelResources() {
        qwenModelManager.unloadModel()
    }

    func cleanupResources() async {
        qwenModelManager.unloadModel()
        await japaneseParakeetTranscriptionService.cleanup()
    }

    func showModelInFinder(_ model: any AddonLocalModel) {
        switch model {
        case let qwenModel as QwenLocalModel:
            NSWorkspace.shared.selectFile(qwenModel.storageDirectory.path, inFileViewerRootedAtPath: "")
        case let japaneseModel as JapaneseParakeetLocalModel:
            japaneseParakeetModelManager.showModelInFinder(japaneseModel)
        default:
            break
        }
    }

    private func addonCardView(
        for model: any AddonLocalModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView {
        switch model {
        case let qwenModel as QwenLocalModel:
            return AnyView(
                QwenModelCardView(
                    model: qwenModel,
                    isDownloaded: isDownloaded,
                    isCurrent: isCurrent,
                    isPreparing: qwenModelManager.downloadInProgress.contains(qwenModel.name),
                    deleteAction: deleteAction,
                    setDefaultAction: setDefaultAction,
                    downloadAction: downloadAction
                )
            )
        case let japaneseModel as JapaneseParakeetLocalModel:
            return AnyView(
                JapaneseParakeetModelCardView(
                    model: japaneseModel,
                    isDownloaded: isDownloaded,
                    isCurrent: isCurrent,
                    isDownloading: japaneseParakeetModelManager.downloadInProgress,
                    downloadProgress: japaneseParakeetModelManager.downloadProgress,
                    deleteAction: deleteAction,
                    setDefaultAction: setDefaultAction,
                    downloadAction: downloadAction,
                    showInFinderAction: { self.showModelInFinder(japaneseModel) }
                )
            )
        default:
            return AnyView(EmptyView())
        }
    }

    func cardView(
        for model: any TranscriptionModel,
        isDownloaded: Bool,
        isCurrent: Bool,
        deleteAction: @escaping () -> Void,
        setDefaultAction: @escaping () -> Void,
        downloadAction: @escaping () -> Void
    ) -> AnyView? {
        guard let addonModel = model as? any AddonLocalModel else {
            return nil
        }

        return addonCardView(
            for: addonModel,
            isDownloaded: isDownloaded,
            isCurrent: isCurrent,
            deleteAction: deleteAction,
            setDefaultAction: setDefaultAction,
            downloadAction: downloadAction
        )
    }

    private func bindManagers() {
        qwenModelManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        japaneseParakeetModelManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func wireCallbacks() {
        qwenModelManager.onModelDeleted = { [weak self] modelName in
            self?.onModelDeleted?(modelName)
        }
        qwenModelManager.onModelsChanged = { [weak self] in
            self?.onModelsChanged?()
        }

        japaneseParakeetModelManager.onModelDeleted = { [weak self] modelName in
            self?.onModelDeleted?(modelName)
        }
        japaneseParakeetModelManager.onModelsChanged = { [weak self] in
            self?.onModelsChanged?()
        }
    }
}
