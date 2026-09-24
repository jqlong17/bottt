import AVFoundation
import Foundation
import os

/// 系统语音。合成器跟着这个对象活着，避免一句话没说完就被释放。
final class AppleSpeechTTS: NSObject, TTSProvider, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let id = TTSPluginID.apple

    private let engine = AVSpeechSynthesizer()
    private let log = Logger(subsystem: "local.bottt.desktop", category: "tts")
    private var activeUtterance: AVSpeechUtterance?
    private var didLogVoice = false

    private(set) var isSpeaking = false
    var onSpeakingChanged: ((Bool) -> Void)?
    var onPlaybackStarted: ((TimeInterval) -> Void)?

    override init() {
        super.init()
        engine.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.preUtteranceDelay = 0
        utterance.voice = preferredVoice()
        logVoiceOnce(utterance.voice)
        SpeechLog.write("request engine=apple source=AVSpeechSynthesizer")

        activeUtterance = utterance
        if engine.isSpeaking {
            engine.stopSpeaking(at: .immediate)
        }
        setSpeaking(true)
        let words = text.split { $0.isWhitespace }.count
        onPlaybackStarted?(max(0.9, Double(max(words, 1)) * 0.42))
        engine.speak(utterance)
    }

    func stop() {
        activeUtterance = nil
        if engine.isSpeaking {
            engine.stopSpeaking(at: .immediate)
        }
        setSpeaking(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === activeUtterance else { return }
        activeUtterance = nil
        setSpeaking(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard utterance === activeUtterance else { return }
        activeUtterance = nil
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

    /// Ava (Premium) → Samantha (Enhanced) → en-US。
    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let english = voices.filter { $0.language.lowercased().hasPrefix("en") }

        if let ava = english.first(where: { isVoice($0, named: "ava") && $0.quality == .premium }) {
            return ava
        }
        if let samantha = english.first(where: { isVoice($0, named: "samantha") && $0.quality == .enhanced }) {
            return samantha
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    private func isVoice(_ voice: AVSpeechSynthesisVoice, named name: String) -> Bool {
        let voiceName = voice.name.lowercased()
        if voiceName == name || voiceName.hasPrefix(name + " ") || voiceName.hasPrefix(name + "(") {
            return true
        }
        return voice.identifier.lowercased().hasSuffix("." + name)
    }

    private func logVoiceOnce(_ voice: AVSpeechSynthesisVoice?) {
        guard !didLogVoice else { return }
        didLogVoice = true
        let identifier = voice?.identifier ?? "nil"
        log.info("Apple voice \(identifier, privacy: .public)")
        print("BOTTT voice: \(identifier)")
    }
}
