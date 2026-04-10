import Foundation

// MARK: - RecorderStateProvider

extension VoiceInkEngine: RecorderStateProvider {}

// MARK: - PowerModeStateProvider

extension VoiceInkEngine: PowerModeStateProvider {
    var currentTranscriptionModel: (any TranscriptionModel)? {
        transcriptionModelManager.currentTranscriptionModel
    }

    var allAvailableModels: [any TranscriptionModel] {
        transcriptionModelManager.allAvailableModels
    }

    var availableModels: [WhisperModel] {
        whisperModelManager.availableModels
    }

    var availableAddonModels: [any AddonLocalModel] {
        addonLocalModelCatalog.availableModels
    }

    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        transcriptionModelManager.setDefaultTranscriptionModel(model)
    }

    func cleanupModelResources() async {
        await cleanupResources()
    }

    func loadModel(_ model: WhisperModel) async throws {
        try await whisperModelManager.loadModel(model)
    }

    func loadAddonModel(_ model: any AddonLocalModel) async throws {
        try await addonLocalModelCatalog.prepareModel(model)
    }
}
