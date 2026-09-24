import AVFoundation
import Foundation

/// 一个常驻 Python 进程。Kokoro / Piper / Supertonic 共用它，切换插件不重新加载已经进过内存的模型。
final class SpeechBridge {
    static let shared = SpeechBridge()

    struct EngineState: Equatable {
        var state: String
        var reason: String
    }

    var onEngines: (([String: EngineState]) -> Void)?
    var onPlaybackStarted: ((TimeInterval) -> Void)?

    private let queue = DispatchQueue(label: "local.bottt.speech")
    /// 只给当前选中的本地插件做首包探测。另外两个下完可以选，但不会抢先加载。
    private var wanted = TTSPluginID.supertonic
    private var process: Process?
    private var input: FileHandle?
    private var reader: PipeReader?
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var attached = false
    private var playToken = 0
    private var remainingByToken: [Int: Int] = [:]
    private var probed: Set<String> = []
    private var resolved: [String: EngineState] = [:]
    private var reported: [String: EngineState] = [:]

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.launchIfNeeded()
            self.refreshStatus()
            self.probeWanted()
            self.schedulePoll()
        }
    }

    /// 切换插件时调用。模型仍留在常驻进程里，只是下一次说话改走这一个。
    func prepare(engine: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.wanted = engine
            guard [TTSPluginID.kokoro, TTSPluginID.piper, TTSPluginID.supertonic].contains(engine) else { return }
            self.launchIfNeeded()
            self.refreshStatus()
            self.probeWanted()
        }
    }

    func speak(engine: String, text: String, onSpeaking: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.launchIfNeeded()
            self.playToken += 1
            let token = self.playToken
            DispatchQueue.main.async {
                self.stopPlayback()
                onSpeaking(true)
            }
            SpeechLog.write("request engine=\(engine) text=\(text)")
            self.send(["cmd": "say", "engine": engine, "text": text])
            var rate = 24_000
            var buffers: [AVAudioPCMBuffer] = []
            var ended = false
            while true {
                guard let line = self.reader?.readLine() else {
                    SpeechLog.write("say fail engine=\(engine) 音频流中断")
                    DispatchQueue.main.async {
                        guard token == self.playToken else { return }
                        onSpeaking(false)
                    }
                    return
                }
                if line == "END" {
                    ended = true
                    break
                }
                if line.hasPrefix("FAIL ") {
                    let reason = String(line.dropFirst(5))
                    SpeechLog.write("say fail engine=\(engine) \(reason)")
                    self.note(engine, EngineState(state: "error", reason: reason))
                    DispatchQueue.main.async {
                        guard token == self.playToken else { return }
                        onSpeaking(false)
                    }
                    return
                }
                let parts = line.split(separator: " ")
                guard parts.count == 4, parts[0] == "AUDIO",
                      let sampleRate = Int(parts[1]),
                      let count = Int(parts[3]), count >= 0 else {
                    continue
                }
                guard let pcm = self.reader?.readExact(count) else {
                    SpeechLog.write("say fail engine=\(engine) 音频长度不对")
                    DispatchQueue.main.async {
                        guard token == self.playToken else { return }
                        onSpeaking(false)
                    }
                    return
                }
                rate = sampleRate
                if let buffer = Self.buffer(pcm: pcm, rate: Double(rate)) {
                    buffers.append(buffer)
                }
            }
            guard ended else { return }
            DispatchQueue.main.async {
                guard token == self.playToken else { return }
                if buffers.isEmpty {
                    SpeechLog.write("play empty engine=\(engine)")
                    onSpeaking(false)
                    return
                }
                self.play(buffers, token: token, engine: engine) {
                    onSpeaking(false)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.playToken += 1
        }
        DispatchQueue.main.async { [weak self] in
            self?.stopPlayback()
        }
    }

    private func launchIfNeeded() {
        if process?.isRunning == true { return }
        guard let python = BotttPaths.pythonExecutable(),
              let script = BotttPaths.speechWorker() else {
            noteAll(EngineState(state: "error", reason: "本机没有语音进程"))
            return
        }
        guard FileManager.default.isExecutableFile(atPath: python),
              FileManager.default.fileExists(atPath: script) else {
            noteAll(EngineState(state: "error", reason: "本机没有语音进程"))
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: python)
        proc.arguments = ["-u", script]
        if let root = BotttPaths.repositoryRoot() {
            proc.currentDirectoryURL = root
        }
        var environment = ProcessInfo.processInfo.environment
        if let models = BotttPaths.modelsDirectory() {
            environment["BOTTT_MODELS"] = models
        }
        proc.environment = environment
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                fputs(text, stderr)
            }
        }
        do {
            try proc.run()
        } catch {
            noteAll(EngineState(state: "error", reason: "语音进程没有起来"))
            return
        }
        process = proc
        input = inPipe.fileHandleForWriting
        reader = PipeReader(handle: outPipe.fileHandleForReading)
        if readUntil(prefix: "READY") == nil {
            SpeechLog.write("worker not ready")
            noteAll(EngineState(state: "error", reason: "语音进程没有起来"))
        }
    }

    private func readUntil(prefix: String, limit: Int = 40) -> String? {
        for _ in 0..<limit {
            guard let line = reader?.readLine() else { return nil }
            if line == prefix || line.hasPrefix(prefix) {
                return line
            }
            SpeechLog.write("skip \(line.prefix(180))")
        }
        return nil
    }

    private func refreshStatus() {
        send(["cmd": "status"])
        guard let line = readUntil(prefix: "STATUS ") else {
            SpeechLog.write("status missing")
            return
        }
        let json = String(line.dropFirst(7))
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
            SpeechLog.write("status parse failed")
            return
        }
        var states: [String: EngineState] = [:]
        for (key, value) in object {
            states[key] = EngineState(state: value["state"] ?? "missing", reason: value["reason"] ?? "")
        }
        publish(states)
    }

    private func probeWanted() {
        let name = wanted
        guard [TTSPluginID.kokoro, TTSPluginID.piper, TTSPluginID.supertonic].contains(name) else { return }
        guard !probed.contains(name) else { return }
        guard reported[name]?.state == "files" else { return }
        probed.insert(name)
        SpeechLog.write("probe \(name)")
        send(["cmd": "probe", "engine": name])
        guard let reply = readUntil(prefix: "PROBE \(name) ") else {
            note(name, EngineState(state: "error", reason: "没有探测结果"))
            return
        }
        let rest = reply.dropFirst("PROBE \(name) ".count)
        let parts = rest.split(separator: " ", maxSplits: 1).map(String.init)
        guard let kind = parts.first else { return }
        if kind == "ok" {
            let ms = parts.count > 1 ? parts[1] : ""
            SpeechLog.write("probe \(name) ok \(ms)ms")
            note(name, EngineState(state: "ok", reason: ""))
        } else if kind == "slow" {
            let ms = parts.count > 1 ? parts[1] : ""
            note(name, EngineState(state: "slow", reason: "首包 \(ms)ms，超过大约 1 秒"))
        } else if kind == "missing" {
            probed.remove(name)
            note(name, EngineState(state: "missing", reason: parts.count > 1 ? parts[1] : "不可用，没有附带模型"))
        } else {
            note(name, EngineState(state: "error", reason: parts.count > 1 ? parts[1] : "装不上"))
        }
    }

    private func send(_ object: [String: String]) {
        guard let input,
              let data = try? JSONSerialization.data(withJSONObject: object),
              var line = String(data: data, encoding: .utf8) else { return }
        line.append("\n")
        input.write(Data(line.utf8))
    }

    private func note(_ engine: String, _ state: EngineState) {
        resolved[engine] = state
        publish(reported)
    }

    private func noteAll(_ state: EngineState) {
        var snapshot: [String: EngineState] = [:]
        for name in ["kokoro", "piper", "supertonic"] {
            resolved[name] = state
            snapshot[name] = state
        }
        publish(snapshot)
    }

    private func publish(_ states: [String: EngineState]) {
        var merged = states
        for (key, value) in resolved {
            merged[key] = value
        }
        reported = merged
        DispatchQueue.main.async {
            self.latest = merged
            self.onEngines?(merged)
        }
    }

    private(set) var latest: [String: EngineState] = [:]

    private func schedulePoll() {
        queue.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self else { return }
            self.refreshStatus()
            self.probeWanted()
            self.schedulePoll()
        }
    }

    private func play(_ buffers: [AVAudioPCMBuffer], token: Int, engine: String, done: @escaping () -> Void) {
        guard let format = buffers.first?.format else {
            done()
            return
        }
        if !attached {
            audioEngine.attach(player)
            attached = true
        }
        audioEngine.disconnectNodeOutput(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                SpeechLog.write("audio engine start failed \(error.localizedDescription)")
                done()
                return
            }
        }
        let frames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        let duration = Double(frames) / format.sampleRate
        SpeechLog.write("play engine=\(engine) rate=\(Int(format.sampleRate)) frames=\(frames) source=onnx-worker")
        onPlaybackStarted?(duration)
        remainingByToken[token] = buffers.count
        for buffer in buffers {
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, token == self.playToken else { return }
                    let left = (self.remainingByToken[token] ?? 1) - 1
                    self.remainingByToken[token] = left
                    if left == 0 {
                        self.remainingByToken[token] = nil
                        done()
                    }
                }
            }
        }
        if !player.isPlaying {
            player.play()
        }
    }

    private func stopPlayback() {
        if player.isPlaying {
            player.stop()
        }
    }

    private static func buffer(pcm: Data, rate: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { return nil }
        let count = pcm.count / 2
        guard count > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let dest = buffer.floatChannelData?[0] else { return nil }
        // 管道里读到的字节不一定按 Int16 对齐，ARM 上直接 bind 会崩。
        var samples = [Int16](repeating: 0, count: count)
        samples.withUnsafeMutableBytes { raw in
            pcm.copyBytes(to: raw)
        }
        for index in 0..<count {
            dest[index] = Float(Int16(littleEndian: samples[index])) / 32768
        }
        return buffer
    }
}

enum SpeechLog {
    private static let queue = DispatchQueue(label: "local.bottt.speech-log")

    static func write(_ message: String) {
        queue.sync {
            let dir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/BOTTT", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("speech.log")
            let line = Data((message + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                try? line.write(to: url)
            }
        }
    }
}

private final class PipeReader {
    private let handle: FileHandle
    /// 普通字节数组。Data 切掉大块音频后下标会错位，removeSubrange 会把进程打崩。
    private var buffer: [UInt8] = []

    init(handle: FileHandle) {
        self.handle = handle
        let fd = handle.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }
    }

    func readLine() -> String? {
        while true {
            guard let newline = buffer.firstIndex(of: 10) else {
                if !pull() { return nil }
                continue
            }
            guard newline >= 0, newline < buffer.count else { return nil }
            let line = String(bytes: buffer[..<newline], encoding: .utf8)
            let dropCount = newline + 1
            guard dropCount > 0, dropCount <= buffer.count else { return nil }
            buffer.removeFirst(dropCount)
            return line
        }
    }

    func readExact(_ count: Int) -> Data? {
        guard count >= 0 else { return nil }
        if count == 0 { return Data() }
        while buffer.count < count {
            if !pull() { return nil }
        }
        guard count <= buffer.count else { return nil }
        let data = Data(buffer[..<count])
        buffer.removeFirst(count)
        return data
    }

    /// `readData(ofLength:)` 会一直等到凑满长度。管道上对端在等下一条命令时，短行会把这里卡死。
    private func pull() -> Bool {
        var tmp = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = Darwin.read(handle.fileDescriptor, &tmp, tmp.count)
            if n > 0 {
                buffer.append(contentsOf: tmp.prefix(n))
                return true
            }
            if n == 0 { return false }
            if errno == EINTR { continue }
            return false
        }
    }
}
