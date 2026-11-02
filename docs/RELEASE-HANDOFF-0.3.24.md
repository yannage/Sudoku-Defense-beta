# Minimal release-candidate handoff

Candidate: local 0.3.24; exact commit and package SHA-256 values are in its
receipts. It fixes initial missing-Steam-identity local-play fallback and
retains the earlier save/achievement protections. Nothing is approved for
upload or activation. Do not activate the held 0.3.19 build.

## Remaining checks

| Gate | Smallest useful acceptance session | Access needed / current limit |
| --- | --- | --- |
| Ordinary Windows desktop | Start the candidate with disposable progress; continue/new-run, recover an old backup, enter/leave practice, open Help/workshop, disconnect/reconnect controller and switch mouse/controller. Run the four existing pointer/drag checks in native and Canvas paths. Capture startup log and readiness marker. | User-operated normal desktop or explicitly authorized execution surface. Native cursor APIs were denied on the sandbox desktop; they are not retried here. |
| Native Linux / Steam Deck | Start the Linux package; verify resources/audio, controller navigation, save/restart, suspend/resume and the actual lower-case `godot` save root. | Physical Deck or authorized native Linux host. WSL access was denied; no WSL retry is needed. Proton mapping is a separate gate only if that runtime will be supported. |
| Current Steamworks readback | Verify app 3721150, the six exact rules, Linux replacement path, 64 MiB/32-file quota, shared Cloud app ID, developer-only enabled and Dynamic Cloud Sync disabled. | Authorized read-only Steamworks access. Existing browser access is pending; historical local receipts do not prove current remote state. Read access is not activation approval. |
| Real Steam and two-device Cloud | Use an authorized fixed-candidate test build and disposable developer test progress. Earn one easy achievement, verify durable client acknowledgment/offline-relaunch behavior, then quit and wait for sync before continuing Windows-to-Deck-to-Windows. Compare seed/round/phase, inventory/modules and earned evidence. Exercise one divergent offline save and explicit recovery choice; retain originals. Check unavailable client and account change boundaries. | Authorized test build delivery plus explicit real-account/device testing scope. Local mocks cannot establish native client or service behavior. Use an existing authorized test entitlement; this handoff requests no keys, spending, credentials or agreements. |

The pointer jobs still withheld are `controller-cursor-render-tests`,
`canvas-controller-cursor-render-tests`, `loot-gear-render-tests` and
`canvas-loot-gear-render-tests`. Their source tests are
`godot/tests/test_controller_cursor.gd` and `godot/tests/test_loot_gear_flow.gd`.
They need a real window and normal desktop input access, not `--headless`.

## Important acceptance boundaries

- Use a separate disposable test profile/account arrangement, not real player
  saves. `--no-steam`, headless/editor runs and custom launch overrides disable
  integration by design; they cannot be used to claim real Steam acceptance.
- Initial unavailable Steam stays local for that session. Relaunch through
  Steam to establish a verified account; there is no hot profile rebinding.
  Later disconnection keeps the existing verified account's scoped files.
- StoreStats success means the client acknowledged the submitted batch. It is
  not proof of two-device Cloud synchronization. Confirm both separately.
- Dynamic Cloud Sync is off. Quit and wait for sync before changing devices;
  suspend alone is not evidence that another device has the latest save.
- The certificate-store message also occurred in prior empty-engine tests.
  Capture whether it persists on the ordinary device. Its cause/security
  implications remain unresolved; do not change certificate stores or security
  settings to silence it. No clean strict startup result is claimed locally.

Source/mocked checks have reached their useful boundary. Further repetitions
cannot replace these device, client, service and current-configuration checks.
Preserve the old release/rollback archives and the 0.3.19 safety hold throughout.
