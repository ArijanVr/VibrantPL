// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation
import VibrantPlusKit

/// The Unix socket between the hook process and the app.
/// One JSON line in each direction. Only processes of the same user may talk to it.
nonisolated enum UnixSocket {
    static func address(_ path: String) -> sockaddr_un? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return addr
    }

    /// Client side (the hook). Returns -1 when nobody listens.
    static func connect(_ path: String, timeout: TimeInterval) -> Int32 {
        guard var addr = address(path) else { return -1 }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return -1 }
        var nosig: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
        setTimeout(fd, timeout)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if ok != 0 { close(fd); return -1 }
        return fd
    }

    static func setTimeout(_ fd: Int32, _ seconds: TimeInterval) {
        var tv = timeval(tv_sec: Int(seconds), tv_usec: Int32((seconds - floor(seconds)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    static func writeLine(_ fd: Int32, _ data: Data) -> Bool {
        var payload = data
        payload.append(0x0A)
        return payload.withUnsafeBytes { raw -> Bool in
            var sent = 0
            while sent < raw.count {
                let n = write(fd, raw.baseAddress!.advanced(by: sent), raw.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }

    /// Reads until a newline, EOF, timeout, or `limit` bytes.
    static func readLine(_ fd: Int32, limit: Int = 4 << 20) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while data.count < limit {
            let n = read(fd, &buffer, buffer.count)
            if n <= 0 { break }
            if let nl = buffer[0..<n].firstIndex(of: 0x0A) {
                data.append(contentsOf: buffer[0..<nl])
                return data
            }
            data.append(contentsOf: buffer[0..<n])
        }
        return data.isEmpty ? nil : data
    }
}

/// The hook: `VibrantPlus --hook`. Claude Code runs it for each event.
/// It never blocks Claude Code: if the app is not running it exits at once,
/// and without an answer in time it prints nothing, so the terminal asks as usual.
nonisolated enum HookCLI {
    static func run() -> Int32 {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let event = try? JSONDecoder().decode(HookEvent.self, from: input) else { return 0 }
        let wait = event.needsAnswer || event.eventName == "UserPromptSubmit"
        let timeout: TimeInterval = event.isQuestion ? 110 : (event.eventName == "PermissionRequest" ? 55 : 2)
        let fd = UnixSocket.connect(Paths.agentSocket.path, timeout: timeout)
        guard fd >= 0 else { return 0 }
        defer { close(fd) }
        let request = HookRequest(wait: wait, event: event)
        guard let body = try? JSONEncoder().encode(request), UnixSocket.writeLine(fd, body) else { return 0 }
        guard wait, let line = UnixSocket.readLine(fd),
              let reply = try? JSONDecoder().decode(HookReply.self, from: line),
              let json = HookOutput.json(for: event, reply: reply) else { return 0 }
        FileHandle.standardOutput.write(Data((json + "\n").utf8))
        return 0
    }
}

/// The app side: accepts hook connections on a background thread and hands
/// each request to the main actor. Replies go back on the same connection.
nonisolated final class AgentServer: @unchecked Sendable {
    typealias Handler = @MainActor (HookRequest, @escaping @Sendable (HookReply) -> Void) -> Void

    private let path: String
    private let handler: Handler
    private var listenFD: Int32 = -1
    /// The socket file this server created. On stop only that file is removed, never a socket
    /// another copy of Vibrant+ bound at the same path in the meantime.
    private var boundInode: ino_t = 0
    private let lock = NSLock()

    init(path: String, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    func start() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard listenFD < 0, var addr = UnixSocket.address(path) else { return listenFD >= 0 }
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { close(fd); return false }
        chmod(path, 0o600)
        var info = stat()
        boundInode = stat(path, &info) == 0 ? info.st_ino : 0
        listenFD = fd
        let thread = Thread { [weak self] in self?.acceptLoop(fd) }
        thread.name = "Vibrant+ agent socket"
        thread.start()
        return true
    }

    fileprivate func reserveWaiting() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard waiting < Self.maxWaiting else { return false }
        waiting += 1
        return true
    }

    fileprivate func releaseWaiting() {
        lock.lock(); defer { lock.unlock() }
        waiting = max(0, waiting - 1)
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        guard listenFD >= 0 else { return }
        close(listenFD)
        listenFD = -1
        var info = stat()
        if stat(path, &info) == 0, info.st_ino == boundInode { unlink(path) }
    }

    /// Requests that wait for an answer hold a connection open (and a card in the island).
    /// Beyond this many at once, new ones get «no answer» right away and the terminal asks.
    static let maxWaiting = 32
    private var waiting = 0

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                return // closed by stop()
            }
            // Only the same user may talk to Vibrant+.
            var uid: uid_t = 0, gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else { close(client); continue }
            var nosig: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
            DispatchQueue.global(qos: .userInitiated).async { [handler, self] in
                UnixSocket.setTimeout(client, 5)
                guard let line = UnixSocket.readLine(client),
                      let request = try? JSONDecoder().decode(HookRequest.self, from: line) else { close(client); return }
                if !request.wait {
                    close(client)
                    Task { @MainActor in handler(request) { _ in } }
                    return
                }
                UnixSocket.setTimeout(client, 120)
                guard self.reserveWaiting() else {
                    ReplyOnce(fd: client).send(.none)
                    return
                }
                let once = ReplyOnce(fd: client) { [weak self] in self?.releaseWaiting() }
                Task { @MainActor in handler(request) { once.send($0) } }
            }
        }
    }
}

/// Sends exactly one reply, then closes the connection and calls `finished` once.
nonisolated final class ReplyOnce: @unchecked Sendable {
    private let fd: Int32
    private var done = false
    private let lock = NSLock()
    private let finished: (@Sendable () -> Void)?

    init(fd: Int32, finished: (@Sendable () -> Void)? = nil) {
        self.fd = fd
        self.finished = finished
    }

    func send(_ reply: HookReply) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        if let data = try? JSONEncoder().encode(reply) { _ = UnixSocket.writeLine(fd, data) }
        close(fd)
        lock.unlock()
        finished?()
    }

    deinit {
        if !done {
            close(fd)
            finished?()
        }
    }
}
