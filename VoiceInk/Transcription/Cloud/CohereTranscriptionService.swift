import Foundation
import MLX
import MLXAudioSTT
import os

final class CohereTranscriptionService: TranscriptionService {
    private weak var modelProvider: (any CohereModelProvider)?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CohereTranscriptionService")

    init(modelProvider: (any CohereModelProvider)? = nil) {
        self.modelProvider = modelProvider
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let cohereModel = model as? CohereLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        let runtimeModel: CohereTranscribeModel
        if let provider = modelProvider,
           await provider.isModelLoaded,
           let loadedModel = await provider.loadedModel,
           await provider.loadedLocalModel?.name == cohereModel.name {
            runtimeModel = loadedModel
        } else if let provider = modelProvider {
            try await provider.loadModel(cohereModel)
            guard let loadedModel = await provider.loadedModel else {
                throw VoiceInkEngineError.modelLoadFailed
            }
            runtimeModel = loadedModel
        } else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        let samples = try readAudioSamples(audioURL)
        let audio = MLXArray(samples)
        let defaults = runtimeModel.defaultGenerationParameters
        let params = STTGenerateParameters(
            maxTokens: defaults.maxTokens,
            temperature: defaults.temperature,
            topP: defaults.topP,
            topK: defaults.topK,
            verbose: defaults.verbose,
            language: resolveLanguageCode(),
            chunkDuration: 30.0,
            minChunkDuration: 1.0
        )

        let result = runtimeModel.generate(audio: audio, generationParameters: params)
        let text = result.text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        logger.notice("Cohere transcription completed for \(cohereModel.displayName, privacy: .public)")

        if text.isEmpty {
            throw VoiceInkEngineError.whisperCoreFailed
        }

        return text
    }

    private func readAudioSamples(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        return stride(from: 44, to: data.count, by: 2).map {
            data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
    }

    private func resolveLanguageCode() -> String {
        let code = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
        if CohereLocalModel.languageNames[code] != nil {
            return code
        }
        return "en"
    }
}
