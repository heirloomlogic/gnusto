import Foundation

/// Runs a tooling fixture. Nonzero exits are results for tests to inspect.
enum ToolProcess {
    static func run(
        _ executable: URL,
        _ arguments: [String],
        from directory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: stdout, as: UTF8.self),
            String(decoding: stderr, as: UTF8.self)
        )
    }
}
