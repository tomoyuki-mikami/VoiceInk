import Foundation
import SwiftData
import os

@MainActor
final class AddonAwareTranscriptionServiceRegistry: TranscriptionServiceRegistry {
    private weak var addonLocalModelCatalog: AddonLocalModelCatalog?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AddonAwareTranscriptionServiceRegistry")

    init(
        modelProvider: any LocalModelProvider,
        addonLocalModelCatalog: AddonLocalModelCatalog,
        modelsDirectory: URL,
        modelContext: ModelContext
    ) {
        self.addonLocalModelCatalog = addonLocalModelCatalog
        super.init(
            modelProvider: modelProvider,
            modelsDirectory: modelsDirectory,
            modelContext: modelContext
        )
    }

    override func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        if let addonService = addonLocalModelCatalog?.service(for: model) {
            logger.debug("Transcribing with \(model.displayName, privacy: .public) using \(String(describing: type(of: addonService)), privacy: .public)")
            return try await addonService.transcribe(audioURL: audioURL, model: model)
        }

        return try await super.transcribe(audioURL: audioURL, model: model)
    }

    override func createSession(for model: any TranscriptionModel, onPartialTranscript: ((String) -> Void)? = nil) -> TranscriptionSession {
        if let addonService = addonLocalModelCatalog?.service(for: model) {
            return FileTranscriptionSession(service: addonService)
        }

        return super.createSession(for: model, onPartialTranscript: onPartialTranscript)
    }

    override func cleanup() async {
        await super.cleanup()
        await addonLocalModelCatalog?.cleanupResources()
    }
}
