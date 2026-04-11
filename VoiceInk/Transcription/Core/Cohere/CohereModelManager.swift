import Foundation
import os
import HuggingFace
import MLXAudioSTT

@MainActor
final class CohereModelManager: ObservableObject {
    @Published var availableModels: [CohereLocalModel] = AddonLocalModels.cohereModels
    @Published var downloadInProgress: Set<String> = []
    @Published var isModelLoaded = false
    @Published var loadedLocalModel: CohereLocalModel?
    @Published var loadedModel: CohereTranscribeModel?

    let cacheDirectory: URL

    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CohereModelManager")

    init(cacheDirectory: URL = HubCache.default.cacheDirectory) {
        self.cacheDirectory = cacheDirectory
    }

    func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory.appendingPathComponent("mlx-audio"),
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("❌ Failed to create Cohere models directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshAvailableModels() {
        availableModels = AddonLocalModels.cohereModels
        onModelsChanged?()
    }

    func isModelDownloaded(named name: String) -> Bool {
        guard let model = AddonLocalModels.cohereModels.first(where: { $0.name == name }) else {
            return false
        }
        return FileManager.default.fileExists(atPath: model.storageDirectory.path)
    }

    func loadModel(_ model: CohereLocalModel) async throws {
        if loadedLocalModel?.name == model.name, loadedModel != nil {
            isModelLoaded = true
            return
        }

        downloadInProgress.insert(model.name)
        defer { downloadInProgress.remove(model.name) }

        do {
            let loaded = try await CohereTranscribeModel.fromPretrained(model.repoId)
            loadedModel = loaded
            loadedLocalModel = model
            isModelLoaded = true
            onModelsChanged?()
        } catch {
            loadedModel = nil
            loadedLocalModel = nil
            isModelLoaded = false
            logger.error("❌ Failed to load Cohere model \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func downloadModel(_ model: CohereLocalModel) async {
        do {
            try await loadModel(model)
        } catch {
            await NotificationManager.shared.showNotification(
                title: "Failed to prepare \(model.displayName)",
                type: .error,
                duration: 4.0
            )
        }
    }

    func unloadModel() {
        loadedModel = nil
        loadedLocalModel = nil
        isModelLoaded = false
    }

    func cleanupResources() async {
        unloadModel()
    }

    func deleteModel(_ model: CohereLocalModel) async {
        do {
            if FileManager.default.fileExists(atPath: model.storageDirectory.path) {
                try FileManager.default.removeItem(at: model.storageDirectory)
            }

            if loadedLocalModel?.name == model.name {
                unloadModel()
            }

            onModelDeleted?(model.name)
            onModelsChanged?()
        } catch {
            logger.error("❌ Failed to delete Cohere model \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension CohereModelManager: CohereModelProvider {}
