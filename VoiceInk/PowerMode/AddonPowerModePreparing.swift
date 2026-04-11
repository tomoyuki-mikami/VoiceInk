import Foundation

@MainActor
protocol AddonPowerModePreparing: AnyObject {
    func canPrepareForPowerMode(_ model: any TranscriptionModel) -> Bool
    func prepareTranscriptionModel(_ model: any TranscriptionModel) async throws
}

extension VoiceInkEngine: AddonPowerModePreparing {
    func canPrepareForPowerMode(_ model: any TranscriptionModel) -> Bool {
        addonLocalModelCatalog.contains(model) || model.provider == .fluidAudio
    }

    func prepareTranscriptionModel(_ model: any TranscriptionModel) async throws {
        try await prepareSelectedModel(model)
    }
}
