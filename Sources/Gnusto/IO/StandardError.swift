import Foundation

/// Writes one line to standard error, followed by a newline.
///
/// Everything the engine says *about* a game rather than *as* one goes here —
/// bootstrap warnings, a rejected `GNUSTO_SEED`, a stack report, a fatal
/// definition error. Standard error keeps all of it out of the play transcript,
/// which is what a tester attaches to a bug report.
///
/// `FileHandle.standardError`, not the libc `stderr` global, which Swift 6 rejects
/// as concurrency-unsafe on Linux — it is a `var` there.
///
/// - Parameter line: the line to write, without its newline.
func writeToStandardError(_ line: String) {
    FileHandle.standardError.write(Data("\(line)\n".utf8))
}
