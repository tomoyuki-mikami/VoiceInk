import Foundation
import SwiftUI
import Combine

@MainActor
final class AddonLocalModelCatalog: ObservableObject {
    private let integrations: [any AddonLocalModelIntegration]
    private var cancellables: Set<AnyCancellable> = []

    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    init(
        qwenModelManager: QwenModelManager,
        cohereModelManager: CohereModelManager? = nil,
        japaneseParakeetModelManager: JapaneseParakeetModelManager? = nil
    ) {
        self.integrations = [
            QwenAddonLocalIntegration(modelManager: qwenModelManager),
            CohereAddonLocalIntegration(
                modelManager: cohereModelManager ?? CohereModelManager()
            ),
            JapaneseParakeetAddonLocalIntegration(
                modelManager: japaneseParakeetModelManager ?? JapaneseParakeetModelManager()
            )
        ]

        bindManagers()
        wireCallbacks()
    }

    var availableModels: [any AddonLocalModel] {
        integrations.flatMap(\.models)
    }

    var availableTranscriptionModels: [any TranscriptionModel] {
        availableModels.map { $0 as any TranscriptionModel }
    }

    func includes(_ model: any TranscriptionModel) -> Bool {
        contains(model)
    }

    func merged(into models: [any TranscriptionModel]) -> [any TranscriptionModel] {
        var mergedModels = models

        for addonModel in availableTranscriptionModels where !mergedModels.contains(where: { $0.name == addonModel.name }) {
            mergedModels.append(addonModel)
        }

        return mergedModels
    }

    func createModelsDirectoryIfNeeded() {
        integrations.forEach { $0.createModelsDirectoryIfNeeded() }
    }

    func refreshAvailableModels() {
        integrations.forEach { $0.refreshAvailableModels() }
        onModelsChanged?()
    }

    var recommendedModelNames: [String] {
        integrations.flatMap(\.recommendedModelNames)
    }

    func contains(_ model: any TranscriptionModel) -> Bool {
        integration(for: model) != nil
    }

    func isModelDownloaded(named name: String) -> Bool {
        guard let model = availableModels.first(where: { $0.name == name }) else { return false }
        return integration(for: model)?.isModelDownloaded(model) ?? false
    }

    func isModelDownloaded(_ model: any TranscriptionModel) -> Bool {
        guard let addonModel = addonModel(from: model),
              let integration = integration(for: addonModel) else {
            return false
        }

        return integration.isModelDownloaded(addonModel)
    }

    func progressMap(for model: any TranscriptionModel) -> [String: Double] {
        guard let addonModel = addonModel(from: model),
              let integration = integration(for: addonModel) else {
            return [:]
        }

        return integration.progressMap(for: addonModel)
    }

    func service(for model: any TranscriptionModel) -> TranscriptionService? {
        guard let addonModel = addonModel(from: model),
              let integration = integration(for: addonModel) else {
            return nil
        }

        return integration.service(for: addonModel)
    }

    func downloadModel(_ model: any AddonLocalModel) async {
        if let integration = integration(for: model) {
            await integration.downloadModel(model)
        }
    }

    func downloadModel(_ model: any TranscriptionModel) async {
        guard let addonModel = model as? any AddonLocalModel else { return }
        await downloadModel(addonModel)
    }

    func deleteModel(_ model: any AddonLocalModel) async {
        if let integration = integration(for: model) {
            await integration.deleteModel(model)
        }
    }

    func deleteModel(_ model: any TranscriptionModel) async {
        guard let addonModel = model as? any AddonLocalModel else { return }
        await deleteModel(addonModel)
    }

    func prepareModel(_ model: any AddonLocalModel) async throws {
        guard let integration = integration(for: model) else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        try await integration.prepareModel(model)
    }

    func unloadModelResources() {
        integrations.forEach { $0.unloadModelResources() }
    }

    func cleanupResources() async {
        for integration in integrations {
            await integration.cleanupResources()
        }
    }

    func showModelInFinder(_ model: any AddonLocalModel) {
        if let integration = integration(for: model) {
            integration.showModelInFinder(model)
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
        guard let integration = integration(for: model) else {
            return AnyView(EmptyView())
        }

        return integration.cardView(
            for: model,
            isDownloaded: isDownloaded,
            isCurrent: isCurrent,
            deleteAction: deleteAction,
            setDefaultAction: setDefaultAction,
            downloadAction: downloadAction
        )
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
        integrations.forEach { integration in
            integration.objectWillChangePublisher
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    private func wireCallbacks() {
        integrations.forEach { integration in
            integration.onModelDeleted = { [weak self] modelName in
                self?.onModelDeleted?(modelName)
            }
            integration.onModelsChanged = { [weak self] in
                self?.onModelsChanged?()
            }
        }
    }

    private func integration(for model: any TranscriptionModel) -> (any AddonLocalModelIntegration)? {
        integrations.first { $0.handles(model) }
    }

    private func integration(for model: any AddonLocalModel) -> (any AddonLocalModelIntegration)? {
        integrations.first { $0.handles(model) }
    }

    private func addonModel(from model: any TranscriptionModel) -> (any AddonLocalModel)? {
        model as? any AddonLocalModel
    }
}
