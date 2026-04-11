import Foundation

/// Protocol that VoiceInkEngine conforms to for power mode session management.
@MainActor
protocol PowerModeStateProvider: AnyObject {
    var currentTranscriptionModel: (any TranscriptionModel)? { get }
    var allAvailableModels: [any TranscriptionModel] { get }

    func setDefaultTranscriptionModel(_ model: any TranscriptionModel)
    func cleanupModelResources() async
    func prepareTranscriptionModel(_ model: any TranscriptionModel) async throws
}
