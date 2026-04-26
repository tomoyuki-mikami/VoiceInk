import Foundation

@MainActor
final class AddonAwareTranscriptionModelManager: TranscriptionModelManager {
    private weak var addonLocalModelCatalog: AddonLocalModelCatalog?
    private weak var whisperModelManagerRef: WhisperModelManager?
    private weak var fluidAudioModelManagerRef: FluidAudioModelManager?

    init(
        whisperModelManager: WhisperModelManager,
        addonLocalModelCatalog: AddonLocalModelCatalog,
        fluidAudioModelManager: FluidAudioModelManager
    ) {
        self.addonLocalModelCatalog = addonLocalModelCatalog
        self.whisperModelManagerRef = whisperModelManager
        self.fluidAudioModelManagerRef = fluidAudioModelManager
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
            case .whisper:
                return whisperModelManagerRef?.availableModels.contains { $0.name == model.name } ?? false
            case .fluidAudio:
                return fluidAudioModelManagerRef?.isFluidAudioModelDownloaded(named: model.name) ?? false
            case .nativeApple:
                if #available(macOS 26, *) {
                    return true
                } else {
                    return false
                }
            case .custom:
                return true
            default:
                if let cloudProvider = CloudProviderRegistry.provider(for: model.provider) {
                    return APIKeyManager.shared.hasAPIKey(forProvider: cloudProvider.providerKey)
                }
                return false
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
        var models = TranscriptionModelRegistry.models

        for whisperModel in whisperModelManagerRef?.availableModels ?? [] {
            if !models.contains(where: { $0.name == whisperModel.name }) {
                let importedModel = ImportedWhisperModel(fileBaseName: whisperModel.name)
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
            whisperModelManagerRef?.loadedWhisperModel = nil
            whisperModelManagerRef?.isModelLoaded = false
            addonLocalModelCatalog?.unloadModelResources()
            UserDefaults.standard.removeObject(forKey: "CurrentModel")
        }
        refreshAllAvailableModels()
    }
}
