import Foundation

@MainActor
final class AddonAwareModelPreparationCoordinator {
    private weak var whisperModelManager: WhisperModelManager?
    private weak var addonLocalModelCatalog: AddonLocalModelCatalog?
    private let fluidAudioTranscriptionService: FluidAudioTranscriptionService

    init(
        whisperModelManager: WhisperModelManager,
        addonLocalModelCatalog: AddonLocalModelCatalog,
        fluidAudioTranscriptionService: FluidAudioTranscriptionService
    ) {
        self.whisperModelManager = whisperModelManager
        self.addonLocalModelCatalog = addonLocalModelCatalog
        self.fluidAudioTranscriptionService = fluidAudioTranscriptionService
    }

    func prepareTranscriptionModel(_ model: any TranscriptionModel) async throws {
        if let addonModel = model as? any AddonLocalModel {
            try await addonLocalModelCatalog?.prepareModel(addonModel)
            return
        }

        if model.provider == .whisper,
           let whisperModelManager,
           let localModel = whisperModelManager.availableModels.first(where: { $0.name == model.name }),
           whisperModelManager.whisperContext == nil {
            try await whisperModelManager.loadModel(localModel)
            return
        }

        if let fluidAudioModel = model as? FluidAudioModel {
            try await fluidAudioTranscriptionService.loadModel(for: fluidAudioModel)
        }
    }

    func shouldPrewarm(_ model: any TranscriptionModel) -> Bool {
        if addonLocalModelCatalog?.contains(model) == true {
            return true
        }

        switch model.provider {
        case .whisper, .fluidAudio:
            return true
        default:
            return false
        }
    }
}
