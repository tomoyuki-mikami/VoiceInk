import Foundation
import os
import HuggingFace
import MLXAudioSTT

@MainActor
final class QwenModelManager: ObservableObject {
    @Published var availableModels: [QwenLocalModel] = PredefinedModels.qwenModels
    @Published var downloadInProgress: Set<String> = []
    @Published var isModelLoaded = false
    @Published var loadedLocalModel: QwenLocalModel?
    @Published var loadedModel: Qwen3ASRModel?

    let modelsDirectory: URL

    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "QwenModelManager")

    init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
    }

    func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("❌ Failed to create Qwen models directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshAvailableModels() {
        availableModels = PredefinedModels.qwenModels
        onModelsChanged?()
    }

    func isModelDownloaded(named name: String) -> Bool {
        guard let model = PredefinedModels.qwenModels.first(where: { $0.name == name }) else {
            return false
        }
        return FileManager.default.fileExists(atPath: model.storageDirectory.path)
    }

    func loadModel(_ model: QwenLocalModel) async throws {
        if loadedLocalModel?.name == model.name, loadedModel != nil {
            isModelLoaded = true
            return
        }

        downloadInProgress.insert(model.name)
        defer { downloadInProgress.remove(model.name) }

        do {
            let cache = HubCache(cacheDirectory: modelsDirectory)
            let loaded = try await Qwen3ASRModel.fromPretrained(model.repoId, cache: cache)
            loadedModel = loaded
            loadedLocalModel = model
            isModelLoaded = true
            onModelsChanged?()
        } catch {
            loadedModel = nil
            loadedLocalModel = nil
            isModelLoaded = false
            logger.error("❌ Failed to load Qwen model \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func downloadModel(_ model: QwenLocalModel) async {
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

    func deleteModel(_ model: QwenLocalModel) async {
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
            logger.error("❌ Failed to delete Qwen model \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension QwenModelManager: QwenModelProvider {}
