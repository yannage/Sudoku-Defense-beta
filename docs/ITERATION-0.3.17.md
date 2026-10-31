# 0.3.17 controller upgrade candidate

This candidate starts from tested 0.3.16 commit `35d366e` in an isolated worktree.
The uploaded 0.3.16 Steam build `26334568` is separate. This pass does not upload,
activate, or publish a build, and does not change combat, prices, or save formats.

## Fast tower equipment

With controller navigation, select a planted tower and press A. The workshop
focuses its first empty (+) socket. Press A to see available modules, then A to
equip the highlighted module. The picker contains attachments only; boosts and
shop purchases are separate. Every existing attachment is compatible with every
tower, as before.

After fitting a module, the workshop closes and board selection moves to the
nearest other tower with an empty socket, provided a module remains in the bag.
Distance uses board squares, so tower height and camera rotation cannot change
the result. Equal distances use row order, then column order. If only the current
tower remains eligible, it stays selected. If the bag is empty or every tower is
full, selection stays useful without performing another action.

LB/RB cycle eligible towers in row order, left to right and top to bottom, with
wraparound. This applies in the controller workshop/picker and on a selected
tower during Prepare. Number selection and ordinary Gear, Chests and Camp tabs
keep their existing bumper behavior. B returns from the module picker to its
socket, then from the workshop to the board. Existing filled sockets and module
swaps remain accessible.

Pointer/touch takeover exits automatic controller advancement. Opening a tab,
changing phase, or starting another run clears stale targeting. Saving remains
the responsibility of the existing protected run-save path. A first touch or
mouse tap on the controller-only chooser returns to ordinary tower controls
without equipping; the next pointer action uses the existing fit/drag flow.
An equipment save failure keeps the immediate warning and persistent Save!
indicator, even when the next tower is selected.

## Physical Steam Deck acceptance

- Use only D-pad, A and B to equip several towers; check socket focus is visible
  immediately and each press acts once.
- Cycle both directions across the first/last eligible tower. Try a single
  tower, full towers and an empty bag, including a bag containing only boosts.
- Back out from the picker and workshop, then resume without losing the tower.
- Remove/replace equipment, change targeting and buy a normal tower/family
  upgrade to confirm those controls remain reachable.
- Switch between touch, right-stick cursor and D-pad during equipment selection.
- Suspend/resume with the picker open; verify no held A causes an extra equip.
- Confirm 1280x800 readability, performance and the normal number picker.

Automated input and rendered tests do not establish physical Deck behavior.
Exact final source, package hashes and validation results accompany delivery.
