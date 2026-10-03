import Foundation

/// What `GNUSTO_TRANSCRIPT` asked for, resolved by actually opening the file —
/// so a bad path is caught once, at launch, rather than losing the whole
/// session's transcript in silence.
///
/// Modelled on ``SeedRequest`` and ``StatusFooter``: a value type that reads
/// one variable and complains about what it could not honor instead of
/// quietly doing something else. Unlike those two, honoring this one touches
/// the filesystem, so `init` opens (and, on success, immediately closes) a
/// probe `TranscriptRecorder` at the resolved URL. A launcher reads
/// ``complaint`` before the IO handler is built, so an alternate screen cannot
/// hide the diagnostic, and hands ``url`` on to `REPL`, which reopens the file to
/// record for real once play begins.
///
/// The decision matches the in-game `script` command's, which is the more
/// direct precedent than `SeedRequest`/`StatusFooter`: a launch transcript
/// that cannot be opened is reported and the session plays on without one,
/// rather than refusing to start.
public enum TranscriptRequest: Sendable {
    /// `GNUSTO_TRANSCRIPT` was unset or empty: no transcript, as ever (the
    /// tester can still start one with `script`).
    case unset

    /// The file opened cleanly; recording starts at this URL.
    case recording(URL)

    /// The file could not be opened; kept with the reason so the complaint
    /// can name both.
    case failed(url: URL, reason: String)

    /// Reads `GNUSTO_TRANSCRIPT` and resolves it against the game's title the
    /// same way `TranscriptStore.url(forName:gameTitled:environment:)` does
    /// for the in-game `script` command, then opens the file to prove it is
    /// writable before deciding play can start recording it.
    ///
    /// - Parameters:
    ///   - title: the game title naming the default transcript file.
    ///   - environment: the environment to read `GNUSTO_TRANSCRIPT` from.
    public init(gameTitled title: String, environment: [String: String]) {
        guard let value = environment["GNUSTO_TRANSCRIPT"], !value.isEmpty else {
            self = .unset
            return
        }
        let name = StatusFooter.onWords.contains(value.lowercased()) ? nil : value
        let url = TranscriptStore.url(
            forName: name, gameTitled: title, environment: environment)
        do {
            let probe = try TranscriptRecorder(url: url)
            probe.close()
            self = .recording(url)
        } catch {
            self = .failed(url: url, reason: error.localizedDescription)
        }
    }

    /// The URL to hand the `REPL`, or `nil` when there is none to record to —
    /// unset, or a request that failed to open.
    public var url: URL? {
        guard case .recording(let url) = self else { return nil }
        return url
    }

    /// What to tell the operator on standard error, or `nil` when there is
    /// nothing to say.
    public var complaint: String? {
        guard case .failed(let url, let reason) = self else { return nil }
        return """
            Couldn't open GNUSTO_TRANSCRIPT at \(url.path): \(reason) Playing \
            without a transcript.
            """
    }
}
