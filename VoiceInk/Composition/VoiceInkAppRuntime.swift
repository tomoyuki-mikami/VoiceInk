import SwiftUI
import SwiftData

@MainActor
final class VoiceInkAppRuntime: ObservableObject {
    let aiService: AIService
    let updaterViewModel: UpdaterViewModel
    let enhancementService: AIEnhancementService
    let whisperModelManager: WhisperModelManager
    let addonLocalModelCatalog: AddonLocalModelCatalog
    let fluidAudioModelManager: FluidAudioModelManager
    let transcriptionModelManager: TranscriptionModelManager
    let recorderUIManager: RecorderUIManager
    let hotkeyManager: HotkeyManager
    let menuBarManager: MenuBarManager
    let activeWindowService: ActiveWindowService
    let prewarmService: ModelPrewarmService
    let engine: VoiceInkEngine

    init(container: ModelContainer) {
        let aiService = AIService()
        self.aiService = aiService

        let updaterViewModel = UpdaterViewModel()
        self.updaterViewModel = updaterViewModel

        let enhancementService = AIEnhancementService(aiService: aiService, modelContext: container.mainContext)
        self.enhancementService = enhancementService

        let dependencies = VoiceInkAppDependencies.make(
            container: container,
            enhancementService: enhancementService
        )

        self.whisperModelManager = dependencies.whisperModelManager
        self.addonLocalModelCatalog = dependencies.addonLocalModelCatalog
        self.fluidAudioModelManager = dependencies.fluidAudioModelManager
        self.transcriptionModelManager = dependencies.transcriptionModelManager
        self.recorderUIManager = dependencies.recorderUIManager
        self.prewarmService = dependencies.prewarmService
        self.engine = dependencies.engine

        self.hotkeyManager = HotkeyManager(
            engine: dependencies.engine,
            recorderUIManager: dependencies.recorderUIManager
        )

        let menuBarManager = MenuBarManager()
        menuBarManager.configure(modelContainer: container, engine: dependencies.engine)
        self.menuBarManager = menuBarManager

        let activeWindowService = ActiveWindowService.shared
        activeWindowService.configure(with: enhancementService)
        self.activeWindowService = activeWindowService

        Task {
            await dependencies.recorderUIManager.resetOnLaunch()
        }
    }
}
