import Foundation

enum TTSPluginID {
    static let apple = "apple"
    static let kokoro = "kokoro"
    static let piper = "piper"
    static let supertonic = "supertonic"
}

struct TTSChoice: Identifiable, Equatable {
    let id: String
    let title: String
}

enum TTSRegistry {
    /// 启动默认用已经在本地的 Supertonic。用户在设置里手动选过之后，沿用那一个。
    static let defaultPluginID = TTSPluginID.supertonic

    static let choices: [TTSChoice] = [
        TTSChoice(id: TTSPluginID.kokoro, title: "Kokoro-82M"),
        TTSChoice(id: TTSPluginID.piper, title: "Piper"),
        TTSChoice(id: TTSPluginID.supertonic, title: "Supertonic 3"),
        TTSChoice(id: TTSPluginID.apple, title: "苹果语音"),
    ]

    static func make(id: String = defaultPluginID) -> any TTSProvider {
        switch id {
        case TTSPluginID.kokoro, TTSPluginID.piper, TTSPluginID.supertonic:
            return LocalModelTTS(id: id)
        default:
            return AppleSpeechTTS()
        }
    }
}
