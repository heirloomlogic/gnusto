import Foundation

/// Writes and copies fixture files that a test is about to execute.
///
/// Swift Testing runs suites in parallel, so another test may launch a child
/// process while this one has a fixture open for writing. A child that inherits
/// the writable descriptor keeps it after we close ours, and while it does,
/// Linux refuses to exec the file with ETXTBSY ("Text file busy"). Without
/// `O_CLOEXEC` the child holds it for its whole life; with it, only between its
/// fork and its exec. That narrows the race to a moment rather than closing it.
/// `String.write(to:atomically:)` and `FileManager.copyItem` give no such
/// control, so fixture scripts and the tooling they run go through here.
enum FixtureFile {
    /// Write `text` to `url`, creating its directory, with mode 0755 when
    /// `executable` and 0600 otherwise.
    static func write(_ text: String, to url: URL, executable: Bool = false) throws {
        try write(Data(text.utf8), to: url, permissions: executable ? 0o755 : 0o600)
    }

    /// Copy the file or directory tree at `source` to `destination`, creating
    /// its directory and keeping each file's permissions.
    static func copy(_ source: URL, to destination: URL) throws {
        let manager = FileManager.default
        let attributes = try manager.attributesOfItem(atPath: source.path)
        if attributes[.type] as? FileAttributeType == .typeDirectory {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            for name in try manager.contentsOfDirectory(atPath: source.path) {
                try copy(source.appendingPathComponent(name), to: destination.appendingPathComponent(name))
            }
        } else {
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
            try write(Data(contentsOf: source), to: destination, permissions: permissions)
        }
    }

    private static func write(_ data: Data, to url: URL, permissions: Int) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, mode_t(0o600))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        // fchmod, not the open mode, so the umask cannot strip the bits.
        guard fchmod(descriptor, mode_t(permissions)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try file.write(contentsOf: data)
    }
}
