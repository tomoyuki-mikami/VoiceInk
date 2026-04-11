import Foundation
import MLXAudioSTT

@MainActor
protocol QwenModelProvider: AnyObject {
    var isModelLoaded: Bool { get }
    var loadedLocalModel: QwenLocalModel? { get }
    var loadedModel: Qwen3ASRModel? { get }
    var availableModels: [QwenLocalModel] { get }

    func loadModel(_ model: QwenLocalModel) async throws
}
