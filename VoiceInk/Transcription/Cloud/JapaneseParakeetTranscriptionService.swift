import Foundation
import FluidAudio
import os.log

final class JapaneseParakeetTranscriptionService: TranscriptionService {
    private static let chunkSamples = 192_000
    private static let chunkOverlapSamples = 32_000

    private var ctcJaManager: CtcJaManager?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink.parakeetja", category: "JapaneseParakeetTranscriptionService")

    func prepareModel() async throws {
        if ctcJaManager == nil {
            ctcJaManager = try await CtcJaManager.load()
        }
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model is JapaneseParakeetLocalModel else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        try await prepareModel()

        guard let ctcJaManager else {
            throw ASRError.notInitialized
        }

        let audioSamples = try readAudioSamples(from: audioURL)
        let text = try await transcribeJapaneseAudio(audioSamples, using: ctcJaManager)
        logger.notice("Japanese Parakeet transcription completed")
        return TextNormalizer.shared.normalizeSentence(text)
    }

    func cleanup() async {
        ctcJaManager = nil
    }

    private func readAudioSamples(from url: URL) throws -> [Float] {
        do {
            let data = try Data(contentsOf: url)
            guard data.count > 44 else {
                throw ASRError.invalidAudioData
            }

            return stride(from: 44, to: data.count, by: 2).map {
                data[$0..<$0 + 2].withUnsafeBytes {
                    let short = Int16(littleEndian: $0.load(as: Int16.self))
                    return max(-1.0, min(Float(short) / 32767.0, 1.0))
                }
            }
        } catch {
            throw ASRError.invalidAudioData
        }
    }

    private func transcribeJapaneseAudio(_ audioSamples: [Float], using manager: CtcJaManager) async throws -> String {
        if audioSamples.count <= Self.chunkSamples {
            return try await manager.transcribe(audio: audioSamples)
        }

        let step = max(Self.chunkSamples - Self.chunkOverlapSamples, 1)
        var chunkTexts: [String] = []
        var startIndex = 0

        while startIndex < audioSamples.count {
            let endIndex = min(startIndex + Self.chunkSamples, audioSamples.count)
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
            mergedText = mergeChunkText(current: mergedText, next: chunkText)
        }

        return mergedText
    }

    private func mergeChunkText(current: String, next: String) -> String {
        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNext = next.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCurrent.isEmpty else { return trimmedNext }
        guard !trimmedNext.isEmpty else { return trimmedCurrent }

        let currentChars = Array(trimmedCurrent)
        let nextChars = Array(trimmedNext)
        let maxOverlap = min(40, currentChars.count, nextChars.count)

        for overlapLength in stride(from: maxOverlap, through: 1, by: -1) {
            let currentSuffix = String(currentChars.suffix(overlapLength))
            let nextPrefix = String(nextChars.prefix(overlapLength))
            if currentSuffix == nextPrefix {
                return trimmedCurrent + String(nextChars.dropFirst(overlapLength))
            }
        }

        return trimmedCurrent + " " + trimmedNext
    }
}
