import Darwin
import Foundation

let socketPath = NSHomeDirectory() + "/Library/Application Support/BOTTT/bottt.sock"

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fputs("usage: bottt say \"text\"\n       bottt smile\n", stderr)
    exit(2)
}

let payload: String
switch command {
case "say":
    guard arguments.count >= 2 else {
        fputs("usage: bottt say \"text\"\n", stderr)
        exit(2)
    }
    let text = arguments.dropFirst().joined(separator: " ")
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        fputs("usage: bottt say \"text\"\n", stderr)
        exit(2)
    }
    payload = text
case "smile":
    // 控制帧：App 收到后触发开心表情，不朗读。
    payload = "__bottt__:smile"
default:
    fputs("usage: bottt say \"text\"\n       bottt smile\n", stderr)
    exit(2)
}

signal(SIGPIPE, SIG_IGN)

let fd = socket(AF_UNIX, SOCK_STREAM, 0)
if fd < 0 {
    fputs("BOTTT is not running\n", stderr)
    exit(1)
}

var addr = sockaddr_un()
memset(&addr, 0, MemoryLayout<sockaddr_un>.size)
addr.sun_family = sa_family_t(AF_UNIX)
addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

let pathBytes = Array(socketPath.utf8)
guard pathBytes.count < 104 else {
    fputs("BOTTT is not running\n", stderr)
    exit(1)
}
var rawPath = [UInt8](repeating: 0, count: 104)
for (index, byte) in pathBytes.enumerated() {
    rawPath[index] = byte
}
withUnsafeMutableBytes(of: &addr.sun_path) { raw in
    raw.copyBytes(from: rawPath)
}

let connected = withUnsafePointer(to: &addr) { ptr -> Int32 in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}
if connected != 0 {
    fputs("BOTTT is not running\n", stderr)
    exit(1)
}

var bytes = Array(payload.utf8)
let written = bytes.withUnsafeMutableBytes { buffer -> Int in
    guard let base = buffer.baseAddress else { return -1 }
    var sent = 0
    while sent < buffer.count {
        let count = write(fd, base.advanced(by: sent), buffer.count - sent)
        if count <= 0 { return -1 }
        sent += count
    }
    return sent
}
close(fd)
if written < 0 {
    fputs("BOTTT is not running\n", stderr)
    exit(1)
}
exit(0)
