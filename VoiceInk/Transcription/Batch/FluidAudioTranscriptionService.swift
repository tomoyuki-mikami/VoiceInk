import Foundation
import CoreML
import AVFoundation
import FluidAudio
import os.log

class FluidAudioTranscriptionService: TranscriptionService {
    private static let japaneseParakeetModelName = "parakeet-tdt_ctc-0.6b-ja"
    private static let japaneseChunkSamples = 192_000
    private static let japaneseChunkOverlapSamples = 32_000

    private var asrManager: AsrManager?
    private var ctcJaManager: CtcJaManager?
    private var vadManager: VadManager?
    private var activeVersion: AsrModelVersion?
    private var cachedModels: AsrModels?
    private var loadingTask: (version: AsrModelVersion, task: Task<AsrModels, Error>)?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink.fluidaudio", category: "FluidAudioTranscriptionService")

    private func version(for model: any TranscriptionModel) -> AsrModelVersion {
        FluidAudioModelManager.asrVersion(for: model.name)
    }

    private func ensureModelsLoaded(for version: AsrModelVersion) async throws {
        if asrManager != nil, activeVersion == version {
            return
        }

        // Clean up existing manager but preserve cachedModels for reuse
        await asrManager?.cleanup()
        asrManager = nil
        vadManager = nil
        activeVersion = nil

        let models = try await getOrLoadModels(for: version)

        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.asrManager = manager
        self.activeVersion = version
    }

    private func ensureJapaneseModelsLoaded() async throws {
        if ctcJaManager != nil {
            return
        }

        ctcJaManager = try await CtcJaManager.load()
    }

    // Returns cached models or loads from disk; deduplicates concurrent loads
    func getOrLoadModels(for version: AsrModelVersion) async throws -> AsrModels {
        if let cached = cachedModels, cached.version == version {
            return cached
        }

        // Deduplicate concurrent loads for the same version
        if let (existingVersion, existingTask) = loadingTask, existingVersion == version {
            return try await existingTask.value
        }

        let task = Task {
            try await AsrModels.loadFromCache(
                configuration: nil,
                version: version
            )
        }
        loadingTask = (version, task)

        do {
            let models = try await task.value
            self.cachedModels = models
            // Only clear if we're still the current loading task
            if loadingTask?.version == version {
                self.loadingTask = nil
            }
            return models
        } catch {
            // Only clear if we're still the current loading task
            if loadingTask?.version == version {
                self.loadingTask = nil
            }
            throw error
        }
    }

    func loadModel(for model: FluidAudioModel) async throws {
        if model.name == Self.japaneseParakeetModelName {
            try await ensureJapaneseModelsLoaded()
        } else {
            try await ensureModelsLoaded(for: version(for: model))
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        if model.name == Self.japaneseParakeetModelName {
            try await ensureJapaneseModelsLoaded()
            guard let ctcJaManager else {
                throw ASRError.notInitialized
            }

            let audioSamples = try readAudioSamples(from: audioURL)
            let text = try await transcribeJapaneseAudio(audioSamples, using: ctcJaManager)
            return TextNormalizer.shared.normalizeSentence(text)
        }

        let targetVersion = version(for: model)
        try await ensureModelsLoaded(for: targetVersion)

        guard let asrManager = asrManager else {
            throw ASRError.notInitialized
        }

        let audioSamples = try readAudioSamples(from: audioURL)

        let durationSeconds = Double(audioSamples.count) / 16000.0
        let isVADEnabled = UserDefaults.standard.bool(forKey: "IsVADEnabled")

        var speechAudio = audioSamples
        if durationSeconds >= 20.0, isVADEnabled {
            let vadConfig = VadConfig(defaultThreshold: 0.7)
            if vadManager == nil {
                do {
                    vadManager = try await VadManager(config: vadConfig)
                } catch {
                    logger.notice("VAD init failed; falling back to full audio: \(error.localizedDescription, privacy: .public)")
                    vadManager = nil
                }
            }

            if let vadManager {
                do {
                    let segments = try await vadManager.segmentSpeechAudio(audioSamples)
                    speechAudio = segments.isEmpty ? audioSamples : segments.flatMap { $0 }
                } catch {
                    logger.notice("VAD segmentation failed; using full audio: \(error.localizedDescription, privacy: .public)")
                    speechAudio = audioSamples
                }
            }
        }

        // Pad with 1s of silence to capture final punctuation at sequence boundary
        let trailingSilenceSamples = 16_000
        let maxSingleChunkSamples = 240_000
        if speechAudio.count + trailingSilenceSamples <= maxSingleChunkSamples {
            speechAudio += [Float](repeating: 0, count: trailingSilenceSamples)
        }

        var decoderState = TdtDecoderState.make(decoderLayers: await asrManager.decoderLayerCount)
        let result = try await asrManager.transcribe(speechAudio, decoderState: &decoderState)

        return TextNormalizer.shared.normalizeSentence(result.text)
    }

    private func readAudioSamples(from url: URL) throws -> [Float] {
        do {
            let data = try Data(contentsOf: url)
            guard data.count > 44 else {
                throw ASRError.invalidAudioData
            }

            let floats = stride(from: 44, to: data.count, by: 2).map {
                return data[$0..<$0 + 2].withUnsafeBytes {
                    let short = Int16(littleEndian: $0.load(as: Int16.self))
                    return max(-1.0, min(Float(short) / 32767.0, 1.0))
                }
            }

            return floats
        } catch {
            throw ASRError.invalidAudioData
        }
    }

    private func transcribeJapaneseAudio(_ audioSamples: [Float], using manager: CtcJaManager) async throws -> String {
        if audioSamples.count <= Self.japaneseChunkSamples {
            return try await manager.transcribe(audio: audioSamples)
        }

        let chunkSize = Self.japaneseChunkSamples
        let overlap = Self.japaneseChunkOverlapSamples
        let step = max(chunkSize - overlap, 1)

        var chunkTexts: [String] = []
        var startIndex = 0

        while startIndex < audioSamples.count {
            let endIndex = min(startIndex + chunkSize, audioSamples.count)
            let chunk = Array(audioSamples[startIndex..<endIndex])
            let text = try await manager.transcribe(audio: chunk)

            if !text.isEmpty {
                chunkTexts.append(text)
            }

            if endIndex == audioSamples.count {
                break
            }
            startIndex += step
        }

        guard var mergedText = chunkTexts.first else {
            return ""
        }

        for chunkText in chunkTexts.dropFirst() {
            mergedText = mergeJapaneseChunkText(current: mergedText, next: chunkText)
        }

        return mergedText
    }

    private func mergeJapaneseChunkText(current: String, next: String) -> String {
        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNext = next.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCurrent.isEmpty else { return trimmedNext }
        guard !trimmedNext.isEmpty else { return trimmedCurrent }

        let currentChars = Array(trimmedCurrent)
        let nextChars = Array(trimmedNext)
        let maxOverlap = min(40, currentChars.count, nextChars.count)

        var bestOverlap = 0
        if maxOverlap > 0 {
            for overlapLength in stride(from: maxOverlap, through: 1, by: -1) {
                let currentSuffix = String(currentChars.suffix(overlapLength))
                let nextPrefix = String(nextChars.prefix(overlapLength))
                if currentSuffix == nextPrefix {
                    bestOverlap = overlapLength
                    break
                }
            }
        }

        if bestOverlap > 0 {
            return trimmedCurrent + String(nextChars.dropFirst(bestOverlap))
        }

        return trimmedCurrent + " " + trimmedNext
    }

    // Releases ASR/VAD resources but preserves cached models for reuse
    func cleanup() async {
        if let manager = asrManager {
            await manager.cleanup()
        }
        asrManager = nil
        ctcJaManager = nil
        vadManager = nil
        activeVersion = nil
    }

}
