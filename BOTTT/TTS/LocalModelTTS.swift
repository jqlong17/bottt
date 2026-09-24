import Foundation

/// Kokoro、Piper、Supertonic 都走常驻进程。`id` 决定这次用哪一个模型。
final class LocalModelTTS: TTSProvider {
    let id: String

    private(set) var isSpeaking = false
    var onSpeakingChanged: ((Bool) -> Void)?
    var onPlaybackStarted: ((TimeInterval) -> Void)?

    init(id: String) {
        self.id = id
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        setSpeaking(true)
        SpeechBridge.shared.onPlaybackStarted = { [weak self] duration in
            self?.onPlaybackStarted?(duration)
        }
        SpeechBridge.shared.speak(engine: id, text: trimmed) { [weak self] speaking in
            self?.setSpeaking(speaking)
        }
    }

    func stop() {
        SpeechBridge.shared.stop()
        setSpeaking(false)
    }

    private func setSpeaking(_ speaking: Bool) {
        let apply = {
            guard self.isSpeaking != speaking else { return }
            self.isSpeaking = speaking
            self.onSpeakingChanged?(speaking)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}
