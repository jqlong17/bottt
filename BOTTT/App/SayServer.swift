import Darwin
import Foundation

enum BotttSay {
    static var socketPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/Library/Application Support/BOTTT/bottt.sock"
    }
}

/// 本机 Unix socket。`bottt say` 连上来把英文交给正在跑的 App。
final class SayServer {
    private var listenFD: Int32 = -1
    private let queue = DispatchQueue(label: "local.bottt.say")
    private var stopped = false

    func start(onSay: @escaping (String) -> Void) {
        let directory = (BotttSay.socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        queue.async { [weak self] in
            self?.listen(onSay: onSay)
        }
    }

    func stop() {
        stopped = true
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        unlink(BotttSay.socketPath)
    }

    private func listen(onSay: @escaping (String) -> Void) {
        let path = BotttSay.socketPath
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        listenFD = fd

        var addr = sockaddr_un()
        memset(&addr, 0, MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        guard copyPath(path, into: &addr) else {
            close(fd)
            listenFD = -1
            return
        }

        let bound = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, Darwin.listen(fd, 4) == 0 else {
            let err = errno
            close(fd)
            listenFD = -1
            unlink(path)
            fputs("BOTTT listen failed (\(err))\n", stderr)
            return
        }

        while !stopped {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if stopped { break }
                continue
            }
            let text = readAll(client)
            close(client)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            onSay(trimmed)
        }
    }

    private func readAll(_ fd: Int32) -> String {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while data.count < 8000 {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

func copyPath(_ path: String, into addr: inout sockaddr_un) -> Bool {
    let bytes = Array(path.utf8)
    guard bytes.count < 104 else { return false }
    var rawPath = [UInt8](repeating: 0, count: 104)
    for (index, byte) in bytes.enumerated() {
        rawPath[index] = byte
    }
    withUnsafeMutableBytes(of: &addr.sun_path) { raw in
        raw.copyBytes(from: rawPath)
    }
    return true
}
