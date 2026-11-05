# 0.3.25 wrong-guess timer penalty

Based on current 0.3.24 source commit
`7e24743f9cf392ccc6c96196cfa9eb10071cdc14`. The earlier 0.3.15-penalty.1
preview in PR #1 (head `36a84ac88533dead6ae9f85e468e657dc746901d`) is a
feature reference, not the release baseline. No older whole-file replacement
or rollback of save/account/achievement protections is part of this port.

Each wrong answer on an empty square during Solve deducts five seconds,
clamped to the time remaining. Expiry invokes the existing Prepare transition
immediately. Correct answers, hints, malformed selections, occupied squares
and Battle reserve/corruption rules retain their existing behavior. Existing
wrong-answer achievement counters are preserved.

A shared, noninteractive map overlay supports native 3D and Canvas boards.
The rejected square shows a red outline and X plus the actual time lost.
Rapid retries aggregate the loss with an explicit guess count; correct retries
clear that square. Controller retries keep number-tray focus until expiry.
New runs, next rounds, same-seed retries, successful recovery/load, and practice
entry/exit clear transient cues so they cannot refer to a different board.

Rejected guesses use Main's existing guarded save path immediately. The
current float timer, journaling, recovery/account guards, achievement evidence
and practice-save exclusion remain in force. There is no schema change.

Focused model and native/Canvas feedback tests are registered in the canonical
build helper, including rendered pixel checks at Deck and portrait sizes.
Exact execution results, source commit, hashes and local package paths are in
the accompanying candidate receipt; test registration alone is not a pass.

The four previously restricted native cursor/drag suites, physical Windows
and Deck input, Linux execution, actual Steam awards and two-device Cloud
acceptance remain separate gates. The known certificate-store diagnostic is
not suppressed or repaired. No browser, WSL, denied PowerShell script or
system/security workaround is part of this work.

This is a local candidate for coordination with the existing sole Steam
delivery owner. No upload, activation, merge, public push or Site publication
is performed here. Never activate held 0.3.19 or the old 0.3.15 preview.
