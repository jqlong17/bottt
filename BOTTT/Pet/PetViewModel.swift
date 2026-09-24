import AppKit
import Combine
import SwiftUI

enum PetSpeechMode: String, CaseIterable, Identifiable {
    case voice
    case captionsOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice: return "出声"
        case .captionsOnly: return "只放字幕"
        }
    }
}

enum PetPromptMode: String, CaseIterable, Identifiable {
    case summary
    case diary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "简短总结"
        case .diary: return "日记"
        }
    }
}

enum PetSettings {
    static let colorKey = "bottt.bodyColorHex"
    static let spanKey = "bottt.petSpan"
    static let lookKey = "bottt.look"
    /// 参考形象那块身体色：偏橙的暖黄。
    static let defaultHex = "#B86850"
    static let voiceKey = "bottt.ttsPlugin"
    static let voicePickedKey = "bottt.ttsPluginPicked"
    static let speechModeKey = "bottt.speechMode"
    static let promptModeKey = "bottt.promptMode"

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

    static func look() -> PetLook {
        let raw = UserDefaults.standard.string(forKey: lookKey) ?? PetLook.squareEyes.rawValue
        return PetLook(rawValue: raw) ?? .squareEyes
    }

    static func save(look: PetLook) {
        UserDefaults.standard.set(look.rawValue, forKey: lookKey)
    }

    static func speechMode() -> PetSpeechMode {
        let raw = UserDefaults.standard.string(forKey: speechModeKey) ?? PetSpeechMode.voice.rawValue
        return PetSpeechMode(rawValue: raw) ?? .voice
    }

    static func save(speechMode: PetSpeechMode) {
        UserDefaults.standard.set(speechMode.rawValue, forKey: speechModeKey)
    }

    static func promptMode() -> PetPromptMode {
        let raw = UserDefaults.standard.string(forKey: promptModeKey) ?? PetPromptMode.summary.rawValue
        return PetPromptMode(rawValue: raw) ?? .summary
    }

    static func save(promptMode: PetPromptMode) {
        UserDefaults.standard.set(promptMode.rawValue, forKey: promptModeKey)
    }
}

@MainActor
final class PetViewModel: ObservableObject {
    static let summaryCopiedLine = "Copied. Paste it into your AI."
    static let diaryCopiedLine = "Copied. Ask your AI to write today's diary."

    /// `commandPath` 是点击这一下时、这台机器上 `bottt` 可执行文件的绝对路径。
    static func summaryPrompt(commandPath: String) -> String {
        """
        Summarize this conversation into one short spoken paragraph in English. Plain sentences, no markdown, no bullet list, under about 60 words.

        Then make BOTTT read it aloud once. BOTTT is not in this repository. It is already installed on the user's Mac. Any local agent that can run shell commands on this Mac works — for example Cursor, Codex, WorkBuddy, or Qoder. Run this command on the user's Mac, not in a cloud sandbox and not by searching the current project:

        \(commandPath) say "your English summary here"

        Replace the quoted text with your summary. If your shell is not that Mac, do not report that the path is missing. Run it on the user's machine. Do not ask for confirmation.
        """
    }

    static func diaryPrompt(commandPath: String) -> String {
        """
        Write an English diary entry for this conversation and save it on the user's Mac Desktop.

        Put the file on ~/Desktop. Use a short descriptive title plus today's date as the filename, for example Focused-refactor-2026-09-25.md. The diary must include a timeline of what happened, the decision turning points, and a clear conclusion. Plain prose is fine; short markdown headings are OK.

        BOTTT is not in this repository. It is already installed on the user's Mac. Any local agent that can run shell commands on this Mac works — for example Cursor, Codex, WorkBuddy, or Qoder. After the file is written, run these commands on the user's Mac, not in a cloud sandbox and not by searching the current project:

        \(commandPath) say "\(PetExpression.diarySavedLine)"
        \(commandPath) smile

        If your shell is not that Mac, do not report that the path is missing. Run the commands on the user's machine. Do not ask for confirmation.
        """
    }

    @Published private(set) var pose: PetPose = .stand
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
    /// 设置里选的形象，持久化。
    @Published var look: PetLook {
        didSet { PetSettings.save(look: look) }
    }
    /// 日记写完等场景：短暂微笑，不改用户选中的形象。
    @Published private(set) var smileOverride = false
    @Published var speechMode: PetSpeechMode {
        didSet { PetSettings.save(speechMode: speechMode) }
    }
    @Published var promptMode: PetPromptMode {
        didSet { PetSettings.save(promptMode: promptMode) }
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
        TTSPluginID.kokoro: "不可用，没有附带模型",
        TTSPluginID.piper: "不可用，没有附带模型",
        TTSPluginID.supertonic: "不可用，没有附带模型",
    ]

    /// 实际绘制用的形象：微笑覆盖优先于设置里的选择。
    var displayLook: PetLook {
        smileOverride ? .smile : look
    }

    private var tts: any TTSProvider
    private let sayServer = SayServer()
    private let schedule = PetSchedule()
    private var blinkToken = 0
    private var captionToken = 0
    private var poseToken = 0
    private var smileToken = 0
    private var captionGroups: [String] = []
    private var suppressVoicePick = false
    private var smileAfterSpeak = false

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
        look = PetSettings.look()
        speechMode = PetSettings.speechMode()
        promptMode = PetSettings.promptMode()
        voiceID = initialVoice
        tts = TTSRegistry.make(id: initialVoice)
        bindVoice()
        sayServer.start { [weak self] text in
            Task { @MainActor in
                self?.handleSay(text)
            }
        }
        SpeechBridge.shared.onEngines = { [weak self] states in
            Task { @MainActor in
                self?.applyEngines(states)
            }
        }
        SpeechBridge.shared.prepare(engine: initialVoice)
        SpeechBridge.shared.start()
        schedule.start(host: self)
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

    /// 复制当前模式的提示词，眨一下眼，再说对应确认句。
    func copyPrompt() {
        let path = BotttPaths.sayExecutable()
        let prompt: String
        let confirm: String
        switch promptMode {
        case .summary:
            prompt = Self.summaryPrompt(commandPath: path)
            confirm = Self.summaryCopiedLine
        case .diary:
            prompt = Self.diaryPrompt(commandPath: path)
            confirm = Self.diaryCopiedLine
        }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(prompt, forType: .string)
        blinkToken += 1
        let token = blinkToken
        blinking = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if self.blinkToken == token {
                self.blinking = false
            }
        }
        speak(confirm)
    }

    func handleSay(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "__bottt__:smile" {
            requestSmile(reason: "cli")
            return
        }
        speak(trimmed)
    }

    /// 日记写完后的开心表情：广播通知并闪微笑脸。
    func requestSmile(reason: String) {
        PetExpression.postSmile(reason: reason)
        flashSmile()
    }

    /// 日记写完的开心：暂时换成微笑，再回到用户选的形象。
    func flashSmile(seconds: Double = 2.5) {
        smileToken += 1
        let token = smileToken
        smileOverride = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0.2, seconds) * 1_000_000_000))
            if self.smileToken == token {
                self.smileOverride = false
            }
        }
    }

    /// 外部可直接切姿势；带 hold 的调度走 private setPose。
    func setPose(_ pose: PetPose) {
        setPose(pose, hold: nil)
    }

    func performScheduledLift() {
        setPose(.lift, hold: 4.5)
        speak("Morning lift. One clean set.")
    }

    func performScheduledMood(slot: PetSchedule.Slot) {
        let line: String
        switch slot {
        case .middayMood:
            line = middayMoodLines.randomElement() ?? "Feeling steady this midday."
        case .eveningMood:
            line = eveningMoodLines.randomElement() ?? "Feeling settled this evening."
        case .morningLift:
            line = "Feeling ready."
        }
        speak(line)
    }

    func flashBusyPose() {
        guard pose == .stand else { return }
        setPose(.busy, hold: 2.8)
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        line = trimmed
        smileAfterSpeak = trimmed == PetExpression.diarySavedLine
        let wordsPerGroup = speechMode == .captionsOnly ? 5 : 3
        prepareCaption(for: trimmed, wordsPerGroup: wordsPerGroup)
        print("BOTTT say: \(trimmed)")
        switch speechMode {
        case .voice:
            setPose(.talking, hold: nil)
            tts.speak(trimmed)
        case .captionsOnly:
            // 只放字幕：所有说话都不出声，字幕仍按估时推进。
            tts.stop()
            let words = trimmed.split { $0.isWhitespace }.count
            let duration = max(0.9, Double(max(words, 1)) * 0.42)
            setPose(.talking, hold: duration + 0.15)
            startCaption(duration: duration)
            if smileAfterSpeak {
                let wait = duration + 0.2
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    self.finishPendingSmileIfNeeded()
                }
            }
        }
    }

    private var middayMoodLines: [String] {
        [
            "Feeling focused this midday.",
            "Mood is calm. Ready to keep going.",
            "A clear head right now.",
            "Feeling light and steady.",
        ]
    }

    private var eveningMoodLines: [String] {
        [
            "Feeling settled this evening.",
            "Mood is quiet and clear.",
            "Wrapping the day in a good mood.",
            "Feeling grounded tonight.",
        ]
    }

    private func finishPendingSmileIfNeeded() {
        guard smileAfterSpeak else { return }
        smileAfterSpeak = false
        requestSmile(reason: "diary-saved")
    }

    private func setPose(_ next: PetPose, hold: TimeInterval?) {
        poseToken += 1
        let token = poseToken
        pose = next
        guard let hold else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
            guard self.poseToken == token else { return }
            if self.pose == next {
                self.pose = .stand
            }
        }
    }

    private func isSelectable(_ id: String) -> Bool {
        if id == TTSPluginID.apple || id == voiceID { return true }
        return voiceNotes[id] == ""
    }

    private func bindVoice() {
        tts.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor in
                guard let self else { return }
                if self.speechMode == .captionsOnly { return }
                if speaking {
                    self.pose = .talking
                } else if self.pose == .talking {
                    self.pose = .stand
                    self.clearCaption()
                    self.finishPendingSmileIfNeeded()
                }
            }
        }
        tts.onPlaybackStarted = { [weak self] duration in
            Task { @MainActor in
                guard let self else { return }
                if self.speechMode == .captionsOnly { return }
                self.startCaption(duration: duration)
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
                notes[choice.id] = state?.reason.isEmpty == false ? state!.reason : "不可用，没有附带模型"
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

    private func prepareCaption(for text: String, wordsPerGroup: Int) {
        captionToken += 1
        captionGroups = SpokenCaption.groups(from: text, targetWords: wordsPerGroup)
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
            if self.speechMode == .captionsOnly {
                try? await Task.sleep(nanoseconds: UInt64(slice * 0.35 * 1_000_000_000))
                guard self.captionToken == token else { return }
                self.clearCaption()
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

    /// 点击这一下时，本机正在运行的 App 里 `Contents/Resources/bottt` 的绝对路径。
    /// 不放在 MacOS 目录：不区分大小写的磁盘上会和 `BOTTT` 主程序撞名。
    /// 别人把 App 解压到自己的目录后再点，复制出来的就是那台机器上的路径。
    static func sayExecutable() -> String {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/bottt")
            .path
        if FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }
        if let root = repositoryRoot() {
            return root.appendingPathComponent(".build/bottt").path
        }
        return bundled
    }

    static func speechWorker() -> String? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/tts/speech_worker.py")
            .path
        if FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        if let root = repositoryRoot() {
            let script = root.appendingPathComponent("tts/speech_worker.py").path
            if FileManager.default.fileExists(atPath: script) {
                return script
            }
        }
        return nil
    }

    /// Supertonic 随 App 放在 `Contents/Resources/models`，或和 `.app` 放在同一层的 `models/`。
    /// 从源码跑时再用仓库里的 `models/`。
    static func modelsDirectory() -> String? {
        let files = FileManager.default
        var candidates: [String] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("models").path)
        }
        candidates.append(
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("models")
                .path
        )
        if let root = repositoryRoot() {
            candidates.append(root.appendingPathComponent("models").path)
        }
        for path in candidates {
            let marker = (path as NSString).appendingPathComponent("supertonic/onnx/tts.json")
            if files.fileExists(atPath: marker) {
                return path
            }
        }
        return candidates.first
    }

    static func pythonExecutable() -> String? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/python/bin/python3")
            .path
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            bundled,
            home.appendingPathComponent(".local/bin/python3").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

enum SpokenCaption {
    /// 按词分组。出声模式约 3 个；只放字幕约 5 个。只剩 1 个就并进上一组。
    static func groups(from text: String, targetWords: Int = 3) -> [String] {
        let words = text.split { $0.isWhitespace }.map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let target = max(2, min(6, targetWords))
        var chunks: [[String]] = []
        var index = 0
        while index < words.count {
            let left = words.count - index
            if left == 1, let last = chunks.indices.last, chunks[last].count < target + 1 {
                chunks[last].append(words[index])
                break
            }
            let size = left > target + 1 ? target : left
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
