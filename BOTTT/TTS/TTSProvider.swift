import Foundation

/// 可替换的朗读插件。界面只依赖这几个能力，不关心背后是系统语音还是以后的本地模型。
protocol TTSProvider: AnyObject {
    var id: String { get }
    var isSpeaking: Bool { get }
    /// 开始或结束朗读时在主线程回调。宠物用它在 idle / talking 之间切换。
    var onSpeakingChanged: ((Bool) -> Void)? { get set }
    /// 真正开始出声时回调，参数是这段音频的秒数。点击确认和 bottt say 都靠它推字幕。
    var onPlaybackStarted: ((TimeInterval) -> Void)? { get set }

    func speak(_ text: String)
    func stop()
}
