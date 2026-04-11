import Foundation
import FluidAudio
import AppKit
import os

@MainActor
final class JapaneseParakeetModelManager: ObservableObject {
    @Published var downloadInProgress = false
    @Published var downloadProgress: Double = 0.0

    var onModelDeleted: ((String) -> Void)?
    var onModelsChanged: (() -> Void)?

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "JapaneseParakeetModelManager")

    func isModelDownloaded(_ model: JapaneseParakeetLocalModel) -> Bool {
        UserDefaults.standard.bool(forKey: defaultsKey(for: model.name))
    }

    func downloadModel(_ model: JapaneseParakeetLocalModel) async {
        if isModelDownloaded(model) {
            return
        }

        downloadInProgress = true
        downloadProgress = 0.0

        let timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in
                if self.downloadProgress < 0.9 {
                    self.downloadProgress += 0.005
                }
            }
        }

        do {
            _ = try await CtcJaModels.downloadAndLoad()
            UserDefaults.standard.set(true, forKey: defaultsKey(for: model.name))
            downloadProgress = 1.0
        } catch {
            UserDefaults.standard.set(false, forKey: defaultsKey(for: model.name))
            logger.error("❌ Japanese Parakeet download failed for \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        timer.invalidate()
        downloadInProgress = false
        downloadProgress = 0.0
        onModelsChanged?()
    }

    func deleteModel(_ model: JapaneseParakeetLocalModel) async {
        let cacheDirectory = CtcJaModels.defaultCacheDirectory()

        do {
            if FileManager.default.fileExists(atPath: cacheDirectory.path) {
                try FileManager.default.removeItem(at: cacheDirectory)
            }
            UserDefaults.standard.set(false, forKey: defaultsKey(for: model.name))
        } catch {
            logger.error("❌ Failed to delete Japanese Parakeet model \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        onModelDeleted?(model.name)
        onModelsChanged?()
    }

    func showModelInFinder(_ model: JapaneseParakeetLocalModel) {
        let cacheDirectory = CtcJaModels.defaultCacheDirectory()
        guard FileManager.default.fileExists(atPath: cacheDirectory.path) else {
            return
        }

        NSWorkspace.shared.selectFile(cacheDirectory.path, inFileViewerRootedAtPath: "")
    }

    private func defaultsKey(for modelName: String) -> String {
        "JapaneseParakeetModelDownloaded_\(modelName)"
    }
}
