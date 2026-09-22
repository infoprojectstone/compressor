import Darwin
import Foundation

final class CompressionControl: @unchecked Sendable {
    private let condition = NSCondition()
    private var paused = false
    private var process: Process?

    func setPaused(_ value: Bool) {
        condition.lock()
        paused = value
        let pid = process?.processIdentifier
        if !value { condition.broadcast() }
        condition.unlock()
        if let pid, pid > 0 { Darwin.kill(pid, value ? SIGSTOP : SIGCONT) }
    }

    func waitIfPaused() {
        condition.lock()
        while paused { condition.wait() }
        condition.unlock()
    }

    func register(_ process: Process) {
        condition.lock()
        self.process = process
        let shouldPause = paused
        condition.unlock()
        if shouldPause { Darwin.kill(process.processIdentifier, SIGSTOP) }
    }

    func unregister(_ process: Process) {
        condition.lock()
        if self.process === process { self.process = nil }
        condition.unlock()
    }
}
