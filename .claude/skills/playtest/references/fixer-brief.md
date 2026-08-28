# The fixer's brief

You are fixing one confirmed defect in a demo game. The finding has already been
reproduced and then adversarially verified by an agent trying to refute it, so treat
it as real — but read the reproducer yourself before you change anything.

Read the transcript at the finding's `transcriptPath`, and replay under the label you
were given rather than one you invent. That path is a probe directory, written once
and never rewritten; a label on its own holds every probe a tester ran and tells you
nothing about which one the finding is about.

**If the reproducer begins `restore`, it needs the slot it restores** — without it the
game answers *"Restore failed."*, every turn after that line is the wrong game, and you
will "fix" prose you never actually saw. Pass `--saves-from`, which takes either the
label the finding's `savesFrom` names, or a **path**:

```sh
bin/playtest-replay <Game> --commands repro.txt --seed <n> --label fix-<n> \
  --saves-from .context/playtest/<label>/probe-004/saves-in
```

Prefer the path. You are picking this up after the round that filed it, and a round's
labels are cleaned between rounds — but every staged probe keeps a copy of the bytes it
ran on in `saves-in/`, beside the transcript you were told to read. That directory is
usually the only thing left. If the finding names no source at all and no `saves-in/`
survives, say so in your report rather than fixing on a transcript you could not
reproduce.

## Test first, always

Write the failing transcript test **before** the fix. The reproducer is already the
command list, so this is mechanical:

```swift
@Test func mrsVaneIsNotInHerChairWhileSheIsInTheYard() async throws {
    let transcript = try await play(
        Fulminate(), ["south", "west", "z", "z", "z", "z", "z", "z", "z", "look"], seed: 0)
    let yard = turnOutput(of: "look", in: transcript)
    #expect(yard.contains("Mrs. Vane"))
    #expect(!yard.contains("in her chair"))
}
```

Run it. **See it fail.** A test that passes before your fix is testing something
else, and you have learned nothing from writing it. Then fix, and see it pass.

Note the shape: assert the *replacement* is present as well as the falsehood being
absent. A negative assertion alone passes when the line disappears entirely, which
is a different bug.

`turnOutput(of:in:)` matches the **first** occurrence of a command, so vary your
commands rather than repeating one when you need to assert about a later turn.

## The rules you are bound by

These are the repo's, not mine. Nothing checks them for you now — the round
that filed the finding does not fix, so you are the last check.

**Copy lives in the design doc.** `docs/games/<game>.md` is the story-and-copy
source of truth. A prose change lands in the doc **in the same commit** as the code.
If the game has no design doc, you are not fixing prose in it — file the finding
instead. That is not a technicality: a prose fix with no doc to update silently
breaks the rule it is supposed to follow.

**The mechanics contract is not negotiable.** Where a design doc has one, its
right-hand column states invariants in hard numbers — "three load-bearing alarms",
"five scheduled actors, with stops on both sides of the blast". Prose may change;
those counts and structures may not. If the only fix you can see would change one,
**stop and say so** rather than changing it. Escalating is the correct outcome here,
not a failure.

**Grep the fragment before you rewrite a line.** The test suites are densely coupled
to the prose — a sentence you rewrite may be asserted in three files. Search for the
fragment first, and update every assertion you break *to the new truth*.

**A test may not be weakened to make a fix pass.** Deleting an assertion, loosening
a needle, or narrowing a `#expect` until it stops complaining is not a fix. If an
existing test now contradicts the corrected behaviour, that is a finding about the
test, and it needs the same defect-frame-cause reasoning as any other change — say
so in your report rather than quietly editing it away.

## Fixing the two commonest shapes

**A location-blind or state-blind listing line.** Per K1, an actor's `firstSight`
prints on every look forever, so it cannot know where the actor is. You cannot have
both `firstSight` and `presence` on one entity — that is a fatal bootstrap error, not
a precedence question. So: delete the
`firstSight(…)` trait and add a `presence { }` rule that branches on the actor's own
location and on the state that matters. Branch on **both** — a rule keyed on the
event alone is how the original defect got reintroduced by its own fix.

**An aftermath line that is only half true.** Per K10, judge each clause on two
axes: where the player is now, and where they were when the event fired. Split the
sentence and give each half its own condition. Reading the world's own record of
where someone was beats hand-writing a past tense, every time.

## Before you hand back

- The new test fails without your fix and passes with it. You watched both.
- `swift build` and the full suite are green — not just your filter.
- Any prose you changed is changed in `docs/games/<game>.md` too.
- No assertion was removed or loosened.
- You touched only the files you were assigned. Another fixer is in the next file.
