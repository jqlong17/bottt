import AppKit
import Combine
import SwiftUI

enum PetSettings {
    static let colorKey = "bottt.bodyColorHex"
    static let spanKey = "bottt.petSpan"
    /// 参考形象那块身体色：偏橙的暖黄。
    static let defaultHex = "#B86850"

    static func color() -> Color {
        let hex = UserDefaults.standard.string(forKey: colorKey) ?? defaultHex
        return Color(hexRGB: hex) ?? Color(hexRGB: defaultHex)!
    }

    static func save(color: Color) {
        UserDefaults.standard.set(color.hexRGB, forKey: colorKey)
    }

    static func span() -> Double {
        let stored = UserDefaults.standard.object(forKey: spanKey) as? Double
        let value = stored ?? Double(PetMetrics.defaultSpan)
        return min(Double(PetMetrics.maxSpan), max(Double(PetMetrics.minSpan), value))
    }

    static func save(span: Double) {
        let clamped = min(Double(PetMetrics.maxSpan), max(Double(PetMetrics.minSpan), span))
        UserDefaults.standard.set(clamped, forKey: spanKey)
    }

    static let voiceKey = "bottt.ttsPlugin"
    static let voicePickedKey = "bottt.ttsPluginPicked"
}

@MainActor
final class PetViewModel: ObservableObject {
    enum Mood: Equatable {
        case idle
        case talking
    }

    static let copiedLine = "Copied. Paste it into your AI."

    /// `commandPath` 是点击这一下时、这台机器上 `bottt` 可执行文件的绝对路径。
    static func summaryPrompt(commandPath: String) -> String {
        """
        Summarize this conversation into one short spoken paragraph in English. Plain sentences, no markdown, no bullet list, under about 60 words.

        Then make BOTTT read it aloud once. BOTTT is not in this repository. It is already installed on the user's Mac. Run this command on the user's Mac, not in a cloud sandbox and not by searching the current project:

        \(commandPath) say "your English summary here"

        Replace the quoted text with your summary. If your shell is not that Mac, do not report that the path is missing. Run it on the user's machine. Do not ask for confirmation.
        """
    }

    @Published private(set) var mood: Mood = .idle
    @Published private(set) var line: String = ""
    @Published private(set) var caption = ""
    @Published private(set) var blinking = false
    @Published var showSettings = false
    @Published var bodyColor: Color {
        didSet { PetSettings.save(color: bodyColor) }
    }
    @Published var petSpan: Double {
        didSet { PetSettings.save(span: petSpan) }
    }
    @Published var voiceID: String {
        didSet {
            guard voiceID != oldValue else { return }
            UserDefaults.standard.set(voiceID, forKey: PetSettings.voiceKey)
            if !suppressVoicePick {
                UserDefaults.standard.set(true, forKey: PetSettings.voicePickedKey)
            }
            installVoice()
        }
    }
    /// 空字符串表示这个本地插件已经能说。缺省或其它文字是不可用原因。
    @Published private(set) var voiceNotes: [String: String] = [
        TTSPluginID.kokoro: "模型还在下载",
        TTSPluginID.piper: "模型还在下载",
        TTSPluginID.supertonic: "模型还在下载",
    ]

    private var tts: any TTSProvider
    private let sayServer = SayServer()
    private var blinkToken = 0
    private var captionToken = 0
    private var captionGroups: [String] = []
    private var suppressVoicePick = false

    init() {
        let picked = UserDefaults.standard.bool(forKey: PetSettings.voicePickedKey)
        let stored = UserDefaults.standard.string(forKey: PetSettings.voiceKey)
        let initialVoice: String
        if picked, let stored, TTSRegistry.choices.contains(where: { $0.id == stored }) {
            initialVoice = stored
        } else {
            initialVoice = TTSPluginID.supertonic
        }
        UserDefaults.standard.set(initialVoice, forKey: PetSettings.voiceKey)
        bodyColor = PetSettings.color()
        petSpan = PetSettings.span()
        voiceID = initialVoice
        tts = TTSRegistry.make(id: initialVoice)
        bindVoice()
        sayServer.start { [weak self] text in
            Task { @MainActor in
                self?.speak(text)
            }
        }
        SpeechBridge.shared.onEngines = { [weak self] states in
            Task { @MainActor in
                self?.applyEngines(states)
            }
        }
        SpeechBridge.shared.prepare(engine: initialVoice)
        SpeechBridge.shared.start()
    }

    func voiceChoices() -> [TTSChoice] {
        TTSRegistry.choices.filter { isSelectable($0.id) }
    }

    func blockedVoices() -> [(TTSChoice, String)] {
        TTSRegistry.choices.compactMap { choice in
            guard let note = voiceNotes[choice.id], !note.isEmpty else { return nil }
            return (choice, note)
        }
    }

    /// 复制提示词，眨一下眼，再用当前插件说一句短确认。不读剪贴板里的长提示词。
    func copyPrompt() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(Self.summaryPrompt(commandPath: BotttPaths.sayExecutable()), forType: .string)
        blinkToken += 1
        let token = blinkToken
        blinking = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if self.blinkToken == token {
                self.blinking = false
            }
        }
        speak(Self.copiedLine)
    }

    private func isSelectable(_ id: String) -> Bool {
        if id == TTSPluginID.apple || id == voiceID { return true }
        return voiceNotes[id] == ""
    }

    private func bindVoice() {
        tts.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor in
                self?.mood = speaking ? .talking : .idle
                if !speaking {
                    self?.clearCaption()
                }
            }
        }
        tts.onPlaybackStarted = { [weak self] duration in
            Task { @MainActor in
                self?.startCaption(duration: duration)
            }
        }
    }

    private func installVoice() {
        tts.stop()
        tts = TTSRegistry.make(id: voiceID)
        bindVoice()
        SpeechBridge.shared.prepare(engine: voiceID)
    }

    private func applyEngines(_ states: [String: SpeechBridge.EngineState]) {
        var notes = voiceNotes
        for choice in TTSRegistry.choices where choice.id != TTSPluginID.apple {
            let state = states[choice.id]
            switch state?.state {
            case "ok", "files":
                notes[choice.id] = ""
            case "missing":
                notes[choice.id] = state?.reason.isEmpty == false ? state!.reason : "模型还在下载"
            case "slow", "error":
                notes[choice.id] = state?.reason.isEmpty == false ? state!.reason : "不可用"
            default:
                break
            }
        }
        voiceNotes = notes
        let picked = UserDefaults.standard.bool(forKey: PetSettings.voicePickedKey)
        guard !picked, voiceID == TTSPluginID.apple else { return }
        let order = [TTSPluginID.piper, TTSPluginID.supertonic, TTSPluginID.kokoro]
        guard let ready = order.first(where: { states[$0]?.state == "ok" }) else { return }
        suppressVoicePick = true
        voiceID = ready
        suppressVoicePick = false
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        line = trimmed
        mood = .talking
        prepareCaption(for: trimmed)
        print("BOTTT say: \(trimmed)")
        tts.speak(trimmed)
    }

    private func prepareCaption(for text: String) {
        captionToken += 1
        captionGroups = SpokenCaption.groups(from: text)
        caption = ""
    }

    private func startCaption(duration: TimeInterval) {
        captionToken += 1
        let token = captionToken
        let groups = captionGroups
        guard !groups.isEmpty else { return }
        let slice = max(duration, 0.35) / Double(groups.count)
        showCaption(groups[0])
        guard groups.count > 1 else { return }
        Task { @MainActor in
            for index in 1..<groups.count {
                try? await Task.sleep(nanoseconds: UInt64(slice * 1_000_000_000))
                guard self.captionToken == token else { return }
                self.showCaption(groups[index])
            }
        }
    }

    private func showCaption(_ text: String) {
        caption = text
        SpeechLog.write("caption \(text)")
    }

    private func clearCaption() {
        captionToken += 1
        if !caption.isEmpty {
            caption = ""
            SpeechLog.write("caption clear")
        }
    }
}

enum BotttPaths {
    /// 从正在运行的 App 往上找到仓库根（目录里有 `tts/speech_worker.py`）。
    static func repositoryRoot() -> URL? {
        var url = Bundle.main.bundleURL
        let files = FileManager.default
        for _ in 0..<12 {
            if files.fileExists(atPath: url.appendingPathComponent("tts/speech_worker.py").path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { return nil }
            url = parent
        }
        return nil
    }

    /// 点击这一下时，本机 `bottt` 可执行文件的绝对路径。换一台机器、换一个目录，点出来的路径就跟着变。
    static func sayExecutable() -> String {
        if let root = repositoryRoot() {
            return root.appendingPathComponent(".build/bottt").path
        }
        return Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("bottt")
            .standardizedFileURL
            .path
    }

    static func pythonExecutable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/python3").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum SpokenCaption {
    /// 按词分组，每组 2–4 个。优先 3 个；只剩 1 个就并进上一组，变成 4 个。
    static func groups(from text: String) -> [String] {
        let words = text.split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        var chunks: [[String]] = []
        var index = 0
        while index < words.count {
            let left = words.count - index
            if left == 1, let last = chunks.indices.last, chunks[last].count < 4 {
                chunks[last].append(words[index])
                break
            }
            let size = left > 4 ? 3 : left
            chunks.append(Array(words[index..<(index + size)]))
            index += size
        }
        return chunks.map { $0.joined(separator: " ") }
    }
}

extension Color {
    init?(hexRGB: String) {
        var text = hexRGB.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        guard text.count == 6, let value = Int(text, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var hexRGB: String {
        let ns = NSColor(self).usingColorSpace(.sRGB)
            ?? NSColor(srgbRed: 184 / 255, green: 104 / 255, blue: 80 / 255, alpha: 1)
        let red = Int((ns.redComponent * 255).rounded())
        let green = Int((ns.greenComponent * 255).rounded())
        let blue = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
