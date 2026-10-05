import Foundation

extension GameWorld {
    // MARK: - Save / restore / death-prompt flow

    /// The kind of input ``perform(_:)`` will consume next.
    ///
    /// Reading this value changes no world or session state and consumes no
    /// randomness, so an event-driven front end may query it whenever it
    /// updates completion, voice, or keyboard behavior.
    public var inputContext: InputContext {
        pendingPrompt?.inputContext
            ?? (pendingClarification == nil ? .command : .clarification)
    }

    /// Cancels an open save or restore prompt without parsing a line or
    /// running a turn.
    ///
    /// This returns `nil` when ordinary command input, a parser clarification,
    /// or the post-death choice is open. A restore selected from the death
    /// choice returns to that choice after cancellation. No cancellation reads
    /// or writes a file, advances a timer, changes the world, or ends the game.
    ///
    /// - Returns: a free cancellation result, or `nil` when no cancellable prompt is open.
    public func cancelPendingInput() -> TurnResult? {
        guard let prompt = pendingPrompt else { return nil }
        let kind: TurnReport.OperationEvent.Kind
        let result: TurnResult
        switch prompt {
        case .saveFilename, .confirmSaveOverwrite:
            kind = .save
            pendingPrompt = nil
            result = freeReply(definition.text.cancelled())
        case .restoreFilename(let returnToDeathPrompt):
            kind = .restore
            pendingPrompt = nil
            result = restoreFailed(definition.text.cancelled(), returnToDeathPrompt)
        case .deathChoice:
            return nil
        }
        var cancellation = result.reporting(.init(kind: kind, outcome: .cancelled))
        cancellation.report.input = .cancelled(prompt.inputContext)
        return cancellation
    }

    /// An open engine prompt. Unlike a clarification, the next input line
    /// *is* the answer — raw, untokenized (filenames carry dots and slashes
    /// the tokenizer would mangle) — and normal parsing doesn't happen.
    enum PendingPrompt {
        case saveFilename
        /// The yes/no question asked when the name given at the save prompt
        /// already names a file. `name` is the answer that named it, which a
        /// yes re-resolves rather than guessing back from what was shown;
        /// `displayed` is how the question named the file, so that the reply
        /// speaks of it in the same words.
        case confirmSaveOverwrite(name: String, displayed: String)
        /// `returnToDeathPrompt` re-arms the death prompt after a failed or
        /// cancelled restore that was chosen from it.
        case restoreFilename(returnToDeathPrompt: Bool)
        /// The post-death RESTART / RESTORE / UNDO / QUIT choice. While it
        /// is armed, every input line is an answer — normal commands are
        /// unreachable until the player picks an exit.
        case deathChoice

        /// The public meaning of the next line while this prompt is open.
        var inputContext: InputContext {
            switch self {
            case .saveFilename: return .saveFilename
            case .confirmSaveOverwrite: return .saveOverwriteConfirmation
            case .restoreFilename: return .restoreFilename
            case .deathChoice: return .endGameChoice
            }
        }

        /// The operation a confirmed front-end quit abandons, if any.
        var abandonedOperation: TurnReport.OperationEvent? {
            switch self {
            case .saveFilename, .confirmSaveOverwrite:
                return .init(kind: .save, outcome: .cancelled)
            case .restoreFilename:
                return .init(kind: .restore, outcome: .cancelled)
            case .deathChoice:
                return nil
            }
        }
    }

    /// The save prompt, with the names of the saves already on disk appended.
    /// The same listing the restore prompt carries, and for a second reason
    /// here: a name already in it is a name that will ask before it replaces
    /// anything.
    func savePromptText() -> String {
        listingExistingSaves(after: definition.text.savePrompt())
    }

    /// The restore prompt, with the names of the saves already on disk appended
    /// when there are any — so a player doesn't have to remember what they
    /// called them. Explicit-path saves elsewhere aren't listed, only the
    /// slots in the saves directory.
    func restorePromptText() -> String {
        listingExistingSaves(after: definition.text.restorePrompt())
    }

    /// Appends `(saved: …)` to a prompt when the saves directory holds
    /// anything, and hands the prompt back untouched when it doesn't.
    ///
    /// - Parameter prompt: the question the game asked.
    /// - Returns: the question, with the slot listing where there is one.
    private func listingExistingSaves(after prompt: String) -> String {
        let names = SaveStore.existingSaveNames(in: saveDirectory)
        guard !names.isEmpty else { return prompt }
        return "\(prompt) (saved: \(names.joined(separator: ", ")))"
    }

    /// Consumes the line that answers an open engine prompt.
    func answer(_ prompt: PendingPrompt, with line: String) -> TurnResult {
        switch prompt {
        case .saveFilename:
            guard !line.isEmpty else {
                return freeReply(definition.text.cancelled()).reporting(
                    .init(kind: .save, outcome: .cancelled))
            }
            if savePathsRestricted, SaveStore.isExplicitPath(line) {
                return freeReply(definition.text.savePathRefused()).reporting(
                    .init(kind: .save, outcome: .failed))
            }
            // `resolve`, which touches no disk, for the one refusal that is
            // about the name alone.
            guard SaveStore.resolve(line, in: saveDirectory) != nil else {
                return freeReply(definition.text.saveNameUnusable()).reporting(
                    .init(kind: .save, outcome: .failed))
            }
            // Asked before anything is written, because writing is the part
            // there is no undo for.
            guard let existing = SaveStore.existingSave(line, in: saveDirectory) else {
                return writeSave(named: line)
            }
            pendingPrompt = .confirmSaveOverwrite(name: line, displayed: existing.name)
            return freeReply(definition.text.saveOverwritePrompt(existing.name))

        case .confirmSaveOverwrite(let name, let displayed):
            // Only an explicit yes replaces a save. Everything else — "no", a
            // blank line, a word that answers nothing — leaves the file alone
            // and says so, and none of them re-arms the prompt: a prompt that
            // asked again would swallow a second line, and the lines a
            // scripted session sends after a save are commands.
            guard ["yes", "y"].contains(line.lowercased()) else {
                return freeReply(definition.text.saveNotReplaced(displayed)).reporting(
                    .init(kind: .save, outcome: .cancelled))
            }
            return writeSave(named: name)

        case .restoreFilename(let returnToDeathPrompt):
            guard !line.isEmpty else {
                return restoreFailed(definition.text.cancelled(), returnToDeathPrompt).reporting(
                    .init(kind: .restore, outcome: .cancelled))
            }
            if savePathsRestricted, SaveStore.isExplicitPath(line) {
                return
                    restoreFailed(
                        definition.text.savePathRefused(), returnToDeathPrompt
                    ).reporting(.init(kind: .restore, outcome: .failed))
            }
            do {
                // `locate`, not `resolve`: the restore prompt offers what the
                // directory holds, so it has to read the file the listing came
                // from rather than recompute a path from the name shown.
                guard let url = SaveStore.locate(line, in: saveDirectory) else {
                    return restoreFailed(
                        definition.text.saveNameUnusable(), returnToDeathPrompt
                    ).reporting(.init(kind: .restore, outcome: .failed))
                }
                let restored = try SaveFile.read(
                    from: url, matching: definition, pristineState: initialState)
                return performRestore(restored)
            } catch {
                switch error {
                case .unreadable, .inconsistent:
                    // An inconsistent save is deliberately indistinguishable
                    // from an unreadable one: the player just sees "Restore
                    // failed." A crafted file learns nothing about which check
                    // caught it.
                    return restoreFailed(definition.text.restoreFailed(), returnToDeathPrompt)
                        .reporting(.init(kind: .restore, outcome: .failed))
                case .unsupportedFormat:
                    // Told apart from the pair above on purpose; see
                    // `SaveFile.ReadError`.
                    return restoreFailed(
                        definition.text.saveVersionMismatch(), returnToDeathPrompt
                    ).reporting(.init(kind: .restore, outcome: .failed))
                case .wrongGame:
                    return restoreFailed(definition.text.wrongGameSave(), returnToDeathPrompt)
                        .reporting(.init(kind: .restore, outcome: .failed))
                }
            }

        case .deathChoice:
            switch line.lowercased() {
            case "restart":
                return performRestart()
            case "restore":
                pendingPrompt = .restoreFilename(returnToDeathPrompt: true)
                return freeReply(restorePromptText()).reporting(
                    .init(kind: .restore, outcome: .requested))
            case "undo":
                guard undoSnapshot != nil else {
                    pendingPrompt = .deathChoice
                    return freeReply(
                        "\(definition.text.cantUndo())\n\n\(definition.text.deathPrompt())")
                }
                // The snapshot predates the fatal turn — this revives.
                return performUndo()
            case "quit", "q":
                return quitAfterGameEnded()
            default:
                pendingPrompt = .deathChoice
                return freeReply(definition.text.deathChoiceUnrecognized())
            }
        }
    }

    /// Writes the world to the file `name` resolves to, reporting either
    /// outcome. The one write on the save path, reached by an answer with
    /// nothing in its way and by a yes to the overwrite question alike.
    ///
    /// - Parameter name: the answer the player gave at the save prompt.
    /// - Returns: the free reply to print.
    private func writeSave(named name: String) -> TurnResult {
        do {
            guard let url = try SaveStore.resolveForWrite(name, in: saveDirectory) else {
                return freeReply(definition.text.saveNameUnusable()).reporting(
                    .init(kind: .save, outcome: .failed))
            }
            try SaveFile.write(
                state, title: definition.title,
                declaredTimerNames: definition.timers.keys.sorted(),
                declaredLocations: definition.locations.keys.sorted(), to: url)
            return freeReply(definition.text.saved()).reporting(
                .init(kind: .save, outcome: .completed))
        } catch {
            return freeReply(definition.text.saveFailed()).reporting(
                .init(kind: .save, outcome: .failed))
        }
    }

    /// Swaps a validated save's state in and shows the player where they are.
    private func performRestore(_ restored: WorldState) -> TurnResult {
        // Already reconciled with what this build declares — see
        // `SaveFile.reconcile(_:with:pristineState:declaredTimerNames:declaredLocations:)`.
        state = restored
        undoSnapshot = nil
        pendingClarification = nil
        let frame = turnFrame(lookCommand)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.text.restored(), aside: true)
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame).reporting(.init(kind: .restore, outcome: .completed))
    }

    /// A failed or cancelled restore — re-arming the death prompt when the
    /// attempt was made from it (there is no world to go back to otherwise).
    private func restoreFailed(_ message: String, _ returnToDeathPrompt: Bool) -> TurnResult {
        guard returnToDeathPrompt else {
            return freeReply(message)
        }
        pendingPrompt = .deathChoice
        return freeReply("\(message)\n\n\(definition.text.deathPrompt())")
    }
}
