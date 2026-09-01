import Foundation

/// This package's own directory, for the handful of suites that read the checkout
/// as files rather than as code — the committed routes, the prose conventions, the
/// tools the starter template ships.
///
/// Found relative to *this file* rather than to the working directory, which a test
/// process does not control: `swift test` runs from wherever it was invoked, and an
/// IDE runs it from somewhere else again. The three rungs below are a fact about
/// where this file sits, so they are written once here instead of once per suite,
/// where a fourth copy would be the only way to notice the layout had moved.
enum PackageDirectory {
    static let url =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // GnustoTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // the package

    /// A path within the package, as a URL.
    static func subdirectory(_ path: String) -> URL {
        url.appendingPathComponent(path, isDirectory: true)
    }
}
