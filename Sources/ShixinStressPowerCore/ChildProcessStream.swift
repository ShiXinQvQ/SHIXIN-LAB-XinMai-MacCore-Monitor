// Copyright (C) 2026 SHIXIN LAB / Shixin
// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

/// A child process whose standard output arrives through a pipe that this
/// object alone owns.
///
/// Foundation's Process, Pipe and FileHandle close descriptors on their own
/// schedule. The privileged Helper restarts its powermetrics stream many times
/// over a long uptime, and a descriptor closed twice can silently close an
/// unrelated, reused descriptor. Here every descriptor is opened, closed and
/// reaped exactly once, and the child inherits nothing but stdin, stdout and
/// stderr.
final class ChildProcessStream: @unchecked Sendable {
    let readDescriptor: Int32

    private let lock = NSLock()
    private let pid: pid_t
    private var reaped = false
    private var descriptorClosed = false

    init(executable: String, arguments: [String]) throws {
        var descriptors: [Int32] = [-1, -1]
        guard pipe(&descriptors) == 0 else {
            throw ChildProcessStreamError.pipeFailed(errno)
        }
        let readEnd = descriptors[0]
        let writeEnd = descriptors[1]
        _ = fcntl(readEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeEnd, F_SETFD, FD_CLOEXEC)

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_addopen(&fileActions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&fileActions, writeEnd, STDOUT_FILENO)
        posix_spawn_file_actions_addinherit_np(&fileActions, STDERR_FILENO)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // The Helper ignores SIGPIPE, SIGTERM and SIGINT; ignored dispositions
        // survive exec, so restore the defaults for the child.
        var defaultSignals = sigset_t()
        sigemptyset(&defaultSignals)
        for signal in [SIGPIPE, SIGTERM, SIGINT, SIGHUP] {
            sigaddset(&defaultSignals, signal)
        }
        posix_spawnattr_setsigdefault(&attributes, &defaultSignals)
        var emptyMask = sigset_t()
        sigemptyset(&emptyMask)
        posix_spawnattr_setsigmask(&attributes, &emptyMask)
        posix_spawnattr_setflags(
            &attributes,
            Int16(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK)
        )

        let argv: [UnsafeMutablePointer<CChar>?] = ([executable] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        let environment: [UnsafeMutablePointer<CChar>?] = [strdup("PATH=/usr/bin:/bin:/usr/sbin:/sbin"), nil]
        defer { environment.forEach { free($0) } }

        var childPID: pid_t = 0
        let result = posix_spawn(&childPID, executable, &fileActions, &attributes, argv, environment)
        // The parent never writes; the child holds its own copy of the write end.
        close(writeEnd)
        guard result == 0 else {
            close(readEnd)
            throw ChildProcessStreamError.spawnFailed(result)
        }
        pid = childPID
        readDescriptor = readEnd
    }

    /// True once the child has exited and been reaped.
    func hasExited() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return reapLocked(blocking: false)
    }

    /// Asks a running child to stop. Safe from any thread. The pid cannot be
    /// reused while the lock is held, because reaping also takes the lock.
    func requestTermination() {
        lock.lock()
        defer { lock.unlock() }
        if !reaped {
            kill(pid, SIGTERM)
        }
    }

    /// Stops the child if needed, reaps it and closes the read end. Repeated
    /// calls do nothing.
    func finish(grace: TimeInterval = 0.5) {
        requestTermination()
        let deadline = Date().addingTimeInterval(grace)
        while !hasExited(), Date() < deadline {
            usleep(20_000)
        }

        lock.lock()
        defer { lock.unlock() }
        if !reaped {
            kill(pid, SIGKILL)
            _ = reapLocked(blocking: true)
        }
        if !descriptorClosed {
            close(readDescriptor)
            descriptorClosed = true
        }
    }

    deinit {
        finish(grace: 0)
    }

    private func reapLocked(blocking: Bool) -> Bool {
        if reaped { return true }
        var status: Int32 = 0
        while true {
            let result = waitpid(pid, &status, blocking ? 0 : WNOHANG)
            if result == pid {
                reaped = true
                return true
            }
            if result == 0 {
                return false
            }
            if errno == EINTR {
                continue
            }
            // ECHILD: nothing left to reap.
            reaped = true
            return true
        }
    }
}

enum ChildProcessStreamError: LocalizedError {
    case pipeFailed(Int32)
    case spawnFailed(Int32)

    var code: Int32 {
        switch self {
        case .pipeFailed(let code), .spawnFailed(let code):
            return code
        }
    }

    var errorDescription: String? {
        switch self {
        case .pipeFailed(let code):
            return "创建采样管道失败：\(String(cString: strerror(code)))"
        case .spawnFailed(let code):
            return "启动采样进程失败：\(String(cString: strerror(code)))"
        }
    }
}
