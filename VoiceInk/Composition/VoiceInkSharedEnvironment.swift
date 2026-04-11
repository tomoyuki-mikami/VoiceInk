import SwiftUI

struct VoiceInkSharedEnvironmentModifier: ViewModifier {
    let runtime: VoiceInkAppRuntime

    func body(content: Content) -> some View {
        content
            .environmentObject(runtime.engine)
            .environmentObject(runtime.whisperModelManager)
            .environmentObject(runtime.addonLocalModelCatalog)
            .environmentObject(runtime.fluidAudioModelManager)
            .environmentObject(runtime.transcriptionModelManager)
            .environmentObject(runtime.recorderUIManager)
            .environmentObject(runtime.hotkeyManager)
            .environmentObject(runtime.updaterViewModel)
            .environmentObject(runtime.menuBarManager)
            .environmentObject(runtime.aiService)
            .environmentObject(runtime.enhancementService)
    }
}

extension View {
    func voiceInkSharedEnvironment(_ runtime: VoiceInkAppRuntime) -> some View {
        modifier(VoiceInkSharedEnvironmentModifier(runtime: runtime))
    }
}
