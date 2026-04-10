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

    var availableQwenModels: [QwenLocalModel] {
        qwenModelManager.availableModels
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

    func loadQwenModel(_ model: QwenLocalModel) async throws {
        try await qwenModelManager.loadModel(model)
    }
}
