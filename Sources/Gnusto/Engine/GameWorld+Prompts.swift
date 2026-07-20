import Foundation

extension GameWorld {
    // MARK: - Save / restore / death-prompt flow

    /// An open engine prompt. Unlike a clarification, the next input line
    /// *is* the answer — raw, untokenized (filenames carry dots and slashes
    /// the tokenizer would mangle) — and normal parsing doesn't happen.
    enum PendingPrompt {
        case saveFilename
        /// `returnToDeathPrompt` re-arms the death prompt after a failed or
        /// cancelled restore that was chosen from it.
        case restoreFilename(returnToDeathPrompt: Bool)
        /// The post-death RESTART / RESTORE / UNDO / QUIT choice. While it
        /// is armed, every input line is an answer — normal commands are
        /// unreachable until the player picks an exit.
        case deathChoice
    }

    /// The restore prompt, with the names of the saves already on disk appended
    /// when there are any — so a player doesn't have to remember what they
    /// called them. Explicit-path saves elsewhere aren't listed, only the
    /// slots in the saves directory.
    func restorePromptText() -> String {
        let names = SaveStore.existingSaveNames(in: saveDirectory)
        guard !names.isEmpty else { return definition.text.restorePrompt }
        return "\(definition.text.restorePrompt) (saved: \(names.joined(separator: ", ")))"
    }

    /// Consumes the line that answers an open engine prompt.
    func answer(_ prompt: PendingPrompt, with line: String) -> TurnResult {
        switch prompt {
        case .saveFilename:
            guard !line.isEmpty else {
                return freeReply(definition.text.cancelled)
            }
            do {
                let url = try SaveStore.resolveForWrite(line, in: saveDirectory)
                try SaveFile.write(state, title: definition.title, to: url)
                return freeReply(definition.text.saved)
            } catch {
                return freeReply(definition.text.saveFailed)
            }

        case .restoreFilename(let returnToDeathPrompt):
            guard !line.isEmpty else {
                return restoreFailed(definition.text.cancelled, returnToDeathPrompt)
            }
            do {
                let url = SaveStore.resolve(line, in: saveDirectory)
                let restored = try SaveFile.read(from: url, matching: definition)
                return performRestore(restored)
            } catch {
                switch error {
                case .unreadable, .inconsistent:
                    // An inconsistent save is deliberately indistinguishable
                    // from an unreadable one: the player just sees "Restore
                    // failed." A crafted file learns nothing about which check
                    // caught it.
                    return restoreFailed(definition.text.restoreFailed, returnToDeathPrompt)
                case .wrongGame:
                    return restoreFailed(definition.text.wrongGameSave, returnToDeathPrompt)
                }
            }

        case .deathChoice:
            switch line.lowercased() {
            case "restart":
                return performRestart()
            case "restore":
                pendingPrompt = .restoreFilename(returnToDeathPrompt: true)
                return freeReply(restorePromptText())
            case "undo":
                guard undoSnapshot != nil else {
                    pendingPrompt = .deathChoice
                    return freeReply(
                        "\(definition.text.cantUndo)\n\n\(definition.text.deathPrompt)")
                }
                // The snapshot predates the fatal turn — this revives.
                return performUndo()
            case "quit", "q":
                // The score already printed at death; just stop reading.
                state.status = .quit
                return freeReply("")
            default:
                pendingPrompt = .deathChoice
                return freeReply(definition.text.deathChoiceUnrecognized)
            }
        }
    }

    /// Swaps a validated save's state in and shows the player where they are.
    private func performRestore(_ restored: WorldState) -> TurnResult {
        var next = restored
        // Re-bind the saved timer schedule to the declared bodies by name;
        // names this build doesn't declare are dropped (see `SaveFile`).
        next.activeFuses = next.activeFuses.filter { definition.timers[$0.key] != nil }
        next.activeDaemons = next.activeDaemons.filter { definition.timers[$0] != nil }
        state = next
        undoSnapshot = nil
        pendingClarification = nil
        let frame = TurnFrame(definition: definition, state: state)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.text.restored)
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// A failed or cancelled restore — re-arming the death prompt when the
    /// attempt was made from it (there is no world to go back to otherwise).
    private func restoreFailed(_ message: String, _ returnToDeathPrompt: Bool) -> TurnResult {
        guard returnToDeathPrompt else {
            return freeReply(message)
        }
        pendingPrompt = .deathChoice
        return freeReply("\(message)\n\n\(definition.text.deathPrompt)")
    }
}
