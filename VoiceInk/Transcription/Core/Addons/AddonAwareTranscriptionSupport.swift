import Foundation
import SwiftData

@MainActor
enum AddonAwareTranscriptionSupport {
    static func makeServiceRegistry(
        modelProvider: any LocalModelProvider,
        addonLocalModelCatalog: AddonLocalModelCatalog,
        modelsDirectory: URL,
        modelContext: ModelContext
    ) -> TranscriptionServiceRegistry {
        AddonAwareTranscriptionServiceRegistry(
            modelProvider: modelProvider,
            addonLocalModelCatalog: addonLocalModelCatalog,
            modelsDirectory: modelsDirectory,
            modelContext: modelContext
        )
    }

    static func makeModelPreparationCoordinator(
        whisperModelManager: WhisperModelManager,
        addonLocalModelCatalog: AddonLocalModelCatalog
    ) -> AddonAwareModelPreparationCoordinator {
        AddonAwareModelPreparationCoordinator(
            whisperModelManager: whisperModelManager,
            addonLocalModelCatalog: addonLocalModelCatalog,
            fluidAudioTranscriptionService: FluidAudioTranscriptionService()
        )
    }
}
