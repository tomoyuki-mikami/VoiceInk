import Foundation

@MainActor
final class AddonAwareTranscriptionModelManager: TranscriptionModelManager {
    private weak var addonLocalModelCatalog: AddonLocalModelCatalog?

    init(
        whisperModelManager: WhisperModelManager,
        addonLocalModelCatalog: AddonLocalModelCatalog,
        fluidAudioModelManager: FluidAudioModelManager
    ) {
        self.addonLocalModelCatalog = addonLocalModelCatalog
        super.init(
            whisperModelManager: whisperModelManager,
            fluidAudioModelManager: fluidAudioModelManager
        )

        addonLocalModelCatalog.onModelDeleted = { [weak self] modelName in
            self?.handleModelDeleted(modelName)
        }
        addonLocalModelCatalog.onModelsChanged = { [weak self] in
            self?.refreshAllAvailableModels()
        }
    }

    override var usableModels: [any TranscriptionModel] {
        allAvailableModels.filter { model in
            if addonLocalModelCatalog?.contains(model) == true {
                return addonLocalModelCatalog?.isModelDownloaded(model) ?? false
            }

            switch model.provider {
            case .local:
                return whisperModelManager?.availableModels.contains { $0.name == model.name } ?? false
            case .fluidAudio:
                return fluidAudioModelManager?.isFluidAudioModelDownloaded(named: model.name) ?? false
            case .nativeApple:
                if #available(macOS 26, *) {
                    return true
                } else {
                    return false
                }
            case .groq:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Groq")
            case .elevenLabs:
                return APIKeyManager.shared.hasAPIKey(forProvider: "ElevenLabs")
            case .deepgram:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Deepgram")
            case .mistral:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Mistral")
            case .gemini:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Gemini")
            case .soniox:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Soniox")
            case .speechmatics:
                return APIKeyManager.shared.hasAPIKey(forProvider: "Speechmatics")
            case .custom:
                return true
            }
        }
    }

    override func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        super.setDefaultTranscriptionModel(model)

        if addonLocalModelCatalog?.contains(model) != true {
            addonLocalModelCatalog?.unloadModelResources()
        }
    }

    override func refreshAllAvailableModels() {
        let currentModelName = currentTranscriptionModel?.name
        var models = PredefinedModels.models

        for whisperModel in whisperModelManager?.availableModels ?? [] {
            if !models.contains(where: { $0.name == whisperModel.name }) {
                let importedModel = ImportedLocalModel(fileBaseName: whisperModel.name)
                models.append(importedModel)
            }
        }

        models = addonLocalModelCatalog?.merged(into: models) ?? models
        allAvailableModels = models

        if let currentName = currentModelName,
           let updatedModel = allAvailableModels.first(where: { $0.name == currentName }) {
            setDefaultTranscriptionModel(updatedModel)
        }
    }

    override func handleModelDeleted(_ modelName: String) {
        if currentTranscriptionModel?.name == modelName {
            currentTranscriptionModel = nil
            UserDefaults.standard.removeObject(forKey: "CurrentTranscriptionModel")
            whisperModelManager?.loadedLocalModel = nil
            whisperModelManager?.isModelLoaded = false
            addonLocalModelCatalog?.unloadModelResources()
            UserDefaults.standard.removeObject(forKey: "CurrentModel")
        }
        refreshAllAvailableModels()
    }
}
