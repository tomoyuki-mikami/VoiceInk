import Foundation
import SwiftData

@MainActor
struct VoiceInkAppDependencies {
    let whisperModelManager: WhisperModelManager
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let fluidAudioModelManager: FluidAudioModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let engine: VoiceInkEngine
    let recorderUIManager: RecorderUIManager
    let prewarmService: ModelPrewarmService

    static func make(
        container: ModelContainer,
        enhancementService: AIEnhancementService
    ) -> VoiceInkAppDependencies {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
        let whisperModelsDirectory = appSupportDirectory.appendingPathComponent("WhisperModels")
        let qwenModelsDirectory = appSupportDirectory.appendingPathComponent("QwenModels")

        let whisperModelManager = WhisperModelManager(modelsDirectory: whisperModelsDirectory)
        let qwenModelManager = QwenModelManager(modelsDirectory: qwenModelsDirectory)
        let addonLocalModelCatalog = AddonLocalModelCatalog(qwenModelManager: qwenModelManager)
        let fluidAudioModelManager = FluidAudioModelManager()
        let transcriptionModelManager = AddonAwareTranscriptionModelManager(
            whisperModelManager: whisperModelManager,
            addonLocalModelCatalog: addonLocalModelCatalog,
            fluidAudioModelManager: fluidAudioModelManager
        )

        let recorderUIManager = RecorderUIManager()
        let engine = VoiceInkEngine(
            modelContext: container.mainContext,
            whisperModelManager: whisperModelManager,
            addonLocalModelCatalog: addonLocalModelCatalog,
            transcriptionModelManager: transcriptionModelManager,
            enhancementService: enhancementService
        )
        recorderUIManager.configure(engine: engine, recorder: engine.recorder)
        engine.recorderUIManager = recorderUIManager

        whisperModelManager.createModelsDirectoryIfNeeded()
        whisperModelManager.loadAvailableModels()
        addonLocalModelCatalog.createModelsDirectoryIfNeeded()
        addonLocalModelCatalog.refreshAvailableModels()
        transcriptionModelManager.refreshAllAvailableModels()
        transcriptionModelManager.loadCurrentTranscriptionModel()

        let prewarmService = ModelPrewarmService(
            transcriptionModelManager: transcriptionModelManager,
            whisperModelManager: whisperModelManager,
            addonLocalModelCatalog: addonLocalModelCatalog,
            modelContext: container.mainContext
        )

        return VoiceInkAppDependencies(
            whisperModelManager: whisperModelManager,
            addonLocalModelCatalog: addonLocalModelCatalog,
            fluidAudioModelManager: fluidAudioModelManager,
            transcriptionModelManager: transcriptionModelManager,
            engine: engine,
            recorderUIManager: recorderUIManager,
            prewarmService: prewarmService
        )
    }
}
