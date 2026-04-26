import Foundation
import MLX
import MLXAudioSTT
import os

final class QwenTranscriptionService: TranscriptionService {
    private weak var modelProvider: (any QwenModelProvider)?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "QwenTranscriptionService")

    init(modelProvider: (any QwenModelProvider)? = nil) {
        self.modelProvider = modelProvider
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard let qwenModel = model as? QwenLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        let runtimeModel: Qwen3ASRModel
        if let provider = modelProvider,
           await provider.isModelLoaded,
           let loadedModel = await provider.loadedModel,
           await provider.loadedLocalModel?.name == qwenModel.name {
            runtimeModel = loadedModel
        } else if let provider = modelProvider {
            try await provider.loadModel(qwenModel)
            guard let loadedModel = await provider.loadedModel else {
                throw VoiceInkEngineError.modelLoadFailed
            }
            runtimeModel = loadedModel
        } else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        let samples = try readAudioSamples(audioURL)
        let audio = MLXArray(samples)
        let params = STTGenerateParameters(
            maxTokens: 2048,
            temperature: 0.0,
            language: resolveLanguageName(),
            chunkDuration: 30.0,
            minChunkDuration: 1.0
        )

        let result = runtimeModel.generate(audio: audio, generationParameters: params)
        let text = result.text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        logger.notice("Qwen transcription completed for \(qwenModel.displayName, privacy: .public)")

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

    private func resolveLanguageName() -> String {
        let code = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
        if code == "auto" || code.isEmpty {
            return "English"
        }
        return QwenLocalModel.languageNames[code] ?? "English"
    }
}
