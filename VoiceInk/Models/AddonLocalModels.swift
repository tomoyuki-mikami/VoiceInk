import Foundation

protocol AddonLocalModel: TranscriptionModel {
    var addonIdentifier: String { get }
}

enum AddonLocalModels {
    static let qwenModels: [QwenLocalModel] = [
        QwenLocalModel(
            name: "qwen3-asr-0.6b-4bit",
            displayName: "Qwen3 0.6B (4-bit)",
            repoId: "mlx-community/Qwen3-ASR-0.6B-4bit",
            size: "~400 MB",
            ramRequirement: "8 GB+ RAM",
            supportedLanguages: QwenLocalModel.supportedLanguageDictionary(),
            description: "Qwen3-ASR の軽量モデル。Apple Silicon でのローカル文字起こし向け。",
            speed: 0.88,
            accuracy: 0.9,
            ramUsage: 1.0
        ),
        QwenLocalModel(
            name: "qwen3-asr-0.6b-8bit",
            displayName: "Qwen3 0.6B (8-bit)",
            repoId: "mlx-community/Qwen3-ASR-0.6B-8bit",
            size: "~800 MB",
            ramRequirement: "16 GB+ RAM",
            supportedLanguages: QwenLocalModel.supportedLanguageDictionary(),
            description: "Qwen3-ASR の軽量高精度版。速度と精度のバランス向け。",
            speed: 0.82,
            accuracy: 0.92,
            ramUsage: 1.6
        ),
        QwenLocalModel(
            name: "qwen3-asr-1.7b-4bit",
            displayName: "Qwen3 1.7B (4-bit)",
            repoId: "mlx-community/Qwen3-ASR-1.7B-4bit",
            size: "~1 GB",
            ramRequirement: "16 GB+ RAM",
            supportedLanguages: QwenLocalModel.supportedLanguageDictionary(),
            description: "Qwen3-ASR の中量モデル。多言語精度を重視したいとき向け。",
            speed: 0.7,
            accuracy: 0.95,
            ramUsage: 2.4
        ),
        QwenLocalModel(
            name: "qwen3-asr-1.7b-8bit",
            displayName: "Qwen3 1.7B (8-bit)",
            repoId: "mlx-community/Qwen3-ASR-1.7B-8bit",
            size: "~2 GB",
            ramRequirement: "32 GB+ RAM",
            supportedLanguages: QwenLocalModel.supportedLanguageDictionary(),
            description: "Qwen3-ASR の高精度モデル。メモリに余裕がある環境向け。",
            speed: 0.58,
            accuracy: 0.97,
            ramUsage: 4.0
        )
    ]

    static let japaneseParakeetModels: [JapaneseParakeetLocalModel] = [
        JapaneseParakeetLocalModel(
            name: "parakeet-tdt_ctc-0.6b-ja",
            displayName: "Parakeet Japanese",
            description: "NVIDIA の日本語向け Parakeet モデル。VoiceInk では安定した日本語 CTC 経路で動作します。",
            size: "494 MB",
            supportedLanguages: ["ja": "Japanese"],
            speed: 0.9,
            accuracy: 0.95,
            ramUsage: 0.8
        )
    ]

    static var allModels: [any AddonLocalModel] {
        qwenModels.map { $0 as any AddonLocalModel } +
        japaneseParakeetModels.map { $0 as any AddonLocalModel }
    }
}

struct QwenLocalModel: AddonLocalModel {
    static let languageNames: [String: String] = [
        "zh": "Chinese", "en": "English", "yue": "Cantonese",
        "ar": "Arabic", "de": "German", "fr": "French",
        "es": "Spanish", "pt": "Portuguese", "id": "Indonesian",
        "it": "Italian", "ko": "Korean", "ru": "Russian",
        "th": "Thai", "vi": "Vietnamese", "ja": "Japanese",
        "tr": "Turkish", "hi": "Hindi", "ms": "Malay",
        "nl": "Dutch", "sv": "Swedish", "da": "Danish",
        "fi": "Finnish", "pl": "Polish", "cs": "Czech",
        "fa": "Persian", "el": "Greek", "hu": "Hungarian",
        "mk": "Macedonian", "ro": "Romanian"
    ]

    static func supportedLanguageDictionary() -> [String: String] {
        let supportedCodes = Array(languageNames.keys) + ["auto"]
        return PredefinedModels.allLanguages.filter { supportedCodes.contains($0.key) }
    }

    let id = UUID()
    let name: String
    let displayName: String
    let repoId: String
    let size: String
    let ramRequirement: String
    let supportedLanguages: [String: String]
    let description: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let provider: ModelProvider = .localAddon
    let addonIdentifier = "qwen3-asr"

    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }

    var storageDirectory: URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
            .appendingPathComponent("QwenModels")
        return appSupportDirectory
            .appendingPathComponent("mlx-audio")
            .appendingPathComponent(repoId.replacingOccurrences(of: "/", with: "_"))
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: storageDirectory.path)
    }
}

struct JapaneseParakeetLocalModel: AddonLocalModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let size: String
    let supportedLanguages: [String: String]
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let provider: ModelProvider = .localAddon
    let addonIdentifier = "parakeet-japanese"

    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }
}
