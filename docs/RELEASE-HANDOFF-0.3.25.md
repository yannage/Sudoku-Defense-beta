# Local 0.3.25 candidate handoff

Port the requested five-second wrong-Solve-guess penalty onto current 0.3.24,
not the old 0.3.15 preview. Exact final commit, tests and package hashes are in
the accompanying receipts. Source history and prior 0.3.24 artifacts remain
intact. The held 0.3.19 build must never be activated.

The implementation shares one model rule and one map overlay across native
3D and Canvas. Time floors at zero and immediately enters Prepare; repeated
wrong guesses still cost time; correct retries clear the square's cue. Reduced
time follows the current save journal/account rules and practice exclusion.
An empty-tower practice timeout offers the normal wave path instead of asking
the player to equip a nonexistent tower.

## Acceptance and delivery boundaries

- Local synthetic/framebuffer checks do not establish physical controller,
  touchscreen, GPU performance or Steam Deck acceptance. On an ordinary
  Windows device and Deck, try a wrong guess, repeat it, correct it, and expire
  with less than five seconds left. Verify readable red X/actual loss, proper
  tray focus, immediate Prepare, save/restart, and practice return.
- The four restricted native cursor/drag suites remain unrun:
  controller-cursor-render-tests, canvas-controller-cursor-render-tests,
  loot-gear-render-tests, canvas-loot-gear-render-tests. No denied native
  cursor, WSL or script-policy operation is retried or bypassed.
- A Linux package cross-built on Windows still requires actual native Linux /
  Steam Deck startup. Windows startup logs are separately qualified if the
  existing certificate-store diagnostic persists. No certificate/security
  settings are changed to suppress that diagnostic.
- Real Steam initialization/awards, current remote configuration and
  Windows-to-Deck-to-Windows Cloud synchronization remain actual-service gates.
  Tests use disposable profiles and disable Steam; no real award is claimed.
  Keep developer-only Cloud and the existing six file rules unchanged.
- The prepared archive is for the sole existing Steam delivery owner
  `01a18e34-af70-774c-b1b3-8b6d58e0401e`, after the parent coordinates the current
  access gate. This local task performs no upload, activation, PR merge, public
  source push, Site publication, pricing change or paid release. Do not use
  the old preview or held 0.3.19 package.

The existing candidate receipts and restriction records remain historical
evidence, not a current Steamworks readback or automatic release approval.
