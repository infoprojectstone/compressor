import Foundation

@main enum PauseSelfTest {
    static func main() throws {
        let control = CompressionControl()
        let process = Process()
        process.executableURL = URL(fileURLWithPath:"/usr/bin/yes")
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        control.register(process)
        Thread.sleep(forTimeInterval:0.25)
        control.setPaused(true)
        Thread.sleep(forTimeInterval:0.5)
        guard process.isRunning else { fatalError("El proceso terminó durante la pausa") }
        control.setPaused(false)
        Thread.sleep(forTimeInterval:0.25)
        guard process.isRunning else { fatalError("El proceso no se reanudó") }
        process.terminate()
        process.waitUntilExit()
        control.unregister(process)
        print("OK: pausa y reanudación reales")
    }
}
