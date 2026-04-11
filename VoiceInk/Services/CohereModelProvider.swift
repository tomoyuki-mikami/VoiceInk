import Foundation
import MLXAudioSTT

@MainActor
protocol CohereModelProvider: AnyObject {
    var isModelLoaded: Bool { get }
    var loadedLocalModel: CohereLocalModel? { get }
    var loadedModel: CohereTranscribeModel? { get }
    var availableModels: [CohereLocalModel] { get }

    func loadModel(_ model: CohereLocalModel) async throws
}
