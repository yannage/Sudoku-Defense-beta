# 0.3.24 local Steam identity fallback candidate

Base: 0.3.23 commit `865d677e9586c1e83f6914ca059e234ea8a6c06b`.
This work uses the separate `sudoku-steam-lifecycle` checkout and branch
`local/0.3.24-steam-identity`. Final source identity and artifact hashes are in
the candidate receipts. The candidate is local and unapproved; 0.3.19 remains
on activation safety hold. Last separately verified live is 0.3.18.

## Demonstrated startup defect

When Steam initialization returned success for the correct app but its account
ID was zero, `SteamPlatform.initialize()` assigned `"0"` to `_account_id` before
rejecting it. `shutdown()` correctly disabled native access but retained that
value. Main passed it to `Cloud.configure()`, which rejected the invalid scoped
identity. Both local Continue and New Run then failed their profile guards.
Existing saves remained intact; the defect prevented local play rather than
destroying progress. Ordinary initialization failure already returned an empty
identity and worked locally, so its existing tests did not cover this branch.

A compact baseline on unchanged 0.3.23 used explicit fake Steam calls, a
disposable profile and the actual Main profile/load/New Run methods. It ran
36 checks with 7 failures, reproducing the invalid identity, failed Continue,
failed New Run and absence of a newly saved run. No unexpected engine error
occurred. The already-verified-account disconnect scenario passed.

## Narrow fix

The adapter now reads the candidate identity into a local variable and publishes
it only after the existing validation succeeds. Failed initial validation leaves
the empty identity that selects the ordinary local profile. The status still
reports `steam_account_unavailable`, and initialized native resources still shut
down once. Validation criteria and gameplay are unchanged.

`shutdown()` and later disconnect behavior are deliberately unchanged. Once an
identity has been verified, offline progress continues in its existing scoped
files instead of switching to an unscoped or different-account profile. There
is no automatic mid-session attachment when Steam becomes available later;
relaunch through Steam is required. Existing scoped progress is not silently
replaced or merged with a separately advanced local-only run on relaunch.

## Verification and evidence

- The promoted `test_steam_identity_fallback.gd` covers local Continue, actual
  New Run/save/backup behavior, no native Cloud/award calls after rejection,
  and an already-verified account's path and durable offline queue after
  disconnect. Focused native and Canvas runs each passed 36/36 checks with
  unchanged source. It is registered for both headless execution paths.
- A separate 85-check lifecycle probe covers delayed initialization, callback-
  time shutdown/unload/account/app changes, queue preservation, late callbacks
  and teardown ordering. Evidence comes from an actual legal placement;
  all gateways are explicit fakes. All 85 checks passed again after the fix.
- Existing acknowledgment tests cover failed StoreStats callbacks, volatile
  client flags, exact submitted batches, acknowledgment journal failures and
  conflict/account isolation. They are rerun within the permitted aggregate.
- The completed aggregate ran 99 permitted suites: 70 headless and 29
  framebuffer, zero failed and zero unrun. Tested source hashes were unchanged.
  `qa/aggregate-verified/manifest.json` records the results. All 100 engine
  import/test processes emitted the known certificate-store diagnostic; the
  aggregate exits 2 with status `incomplete`, not an unqualified release pass.
- All 16 desktop-package unit tests passed.
- The four previously denied native cursor/drag suites remain excluded. The
  known certificate-store diagnostic remains qualified and unresolved. A
  passing local aggregate is not a clean strict release approval.

The first lifecycle probe retained fake callbacks that referenced their own
mock objects and reported a teardown resource cycle. The final harness clears
those fake callables; product code was not changed for that harness issue.
The first identity fixture used Main's special injected-path test branch and
also produced script errors. It is retained as preliminary evidence. The
compact verified baseline avoids that branch and is the product reproduction.

## Cloud configuration review

The 28-check static audit matched source paths and six committed-file patterns
against local historical configuration receipts. The publication receipt is
dated `2026-11-01T02:25:01.5217691Z`, for app 3721150, revisions stats1/ufs1,
developer-only Cloud enabled and Dynamic Cloud Sync disabled. This is not a
fresh remote check. Shared Cloud app ID 0 is specified locally but absent from
the captured configuration JSON, so its remote value remains unverified.

Windows uses `WinAppDataRoaming` plus
`Godot/app_userdata/Sudoku Defense/steam/{64BitSteamID}/cloud`.
The native Linux/SteamOS override uses `LinuxXdgDataHome` and replaces the path
with `godot/app_userdata/Sudoku Defense/steam/{64BitSteamID}/cloud`.
All six rules are nonrecursive and Cross-Platform:

| Exact file | Purpose |
| --- | --- |
| `run.json` | Committed run |
| `run.json.pending` | Published run journal |
| `run.json.bak` | Last-good run backup |
| `achievements.json` | Durable achievement evidence |
| `achievements.json.pending` | Published achievement journal |
| `achievements.json.bak` | Last-good achievement backup |

The 64 MiB/32-file quota covers six files capped at 8 MiB each. Settings,
migration claims, uncommitted temporary files, conflict archives, practice,
caches and logs stay outside these rules. No configuration was changed.

See [the minimal release handoff](RELEASE-HANDOFF-0.3.24.md). No real Steam
initialization, account award, player-save test, browser/Steamworks operation,
push/upload/activation, further cleanup, relocation or security change occurs
in this pass. Prior denied cursor, WSL and process-inspection operations are
not retried. Native packages, if produced after successful checks, are new
local test artifacts for this changed candidate and remain unapproved.
