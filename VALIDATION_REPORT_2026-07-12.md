# Kapi Note - Validation Report

Date: 2026-07-12
Build tested: 5.0.77+91

## Release decision

Release candidate, but not approved for production submission yet. Static analysis, automated gameplay tests, release APK generation, four-device startup checks, matchmaking, and the first synchronized online move passed. A complete live online match to 100 points, rematch, room exit, and cross-platform match still need final verification without other applications interrupting the shared emulators.

## Errors recorded as regression references

These failures are now permanent validation cases in `lib/memoria_para_codex.md`:

1. Online clients must never render different room revisions.
2. Blank (`0`) is a valid endpoint and must accept matching tiles.
3. A tile can only enter through the two open ends, never through the middle.
4. Neighboring domino values must match after every move and turn.
5. Doubles must keep the correct orientation and must not start a visual turn.
6. A blocked round is won by the hand with fewer remaining pip points; a tie goes to the player who blocked the round.
7. Blocked-round points are the sum of every pip left in both players' hands.
8. The first round starts with the highest double. Later rounds are opened by the previous winner, who chooses the tile.
9. A player already inside a room must not be matched into another room.
10. Leaving a room must release the player and notify the opponent.
11. Online game end must show the result card, remaining hands, confetti, Play Again, and Return to Lobby.
12. Phone layouts must be checked on iPhone 17 Pro Max, iPhone 16e, and two Android sizes.

## Repairs completed

### Revisioned online room state

- Every online game state now includes a monotonically increasing `revision`.
- Plays, passes, next rounds, and rematches increment that revision.
- Clients ignore stale snapshots so an older network update cannot overwrite a newer board.
- The most recent stable game state is retained while a late snapshot arrives.

### Domino validation

- Added deterministic checks for a blank endpoint (`0-6` against open `0`).
- Added a 40-game rapid simulation that validates every placed connection.
- Every simulated round must finish and award the full sum of remaining pips.
- Existing blocked-round tie and combined-score checks remain active.

### Round starter rule

- The first CPU round still uses the highest double.
- After that, the previous winner starts.
- When the player won, the board stays empty until the player chooses an opening tile.
- When the CPU won, the CPU chooses its opening tile.

## Automated verification

- `flutter analyze`: passed with no issues.
- `flutter test`: 9 tests passed.
- Rapid deterministic online simulation: 40 complete games passed.
- Release APK: built successfully.
- APK: `build/app/outputs/flutter-apk/app-release.apk` (67 MB).

## Four-device visual verification

The same build `5.0.77+91` installed and opened successfully on:

- iPhone 17 Pro Max simulator.
- iPhone 16e simulator.
- Android emulator 5554.
- Android emulator 5556.

All four reached the opening flow without a red error screen, black screen, startup crash, or visible overflow.

Evidence:

- `/private/tmp/kapi_17_5077.png`
- `/private/tmp/kapi_16e_5077.png`
- `/private/tmp/kapi_android_5554_5077.png`
- `/private/tmp/kapi_android_5556_open_5077.png`

## Live online verification

Two independent Android profiles were matched into the same room:

- `AN.DE.LJU3TX`
- `ZZ.US.7WQXJC`

Verified live:

- Both devices entered the same room.
- Both displayed the same first tile, round, goal, and players.
- Only the correct device showed `Your turn`.
- The active player selected `3-6`, chose the right side, and completed the move.
- The other device received the same move and correctly became the active player.

The continuation was interrupted because other applications took control of both shared Android emulators. Android logs showed no Kapi Note crash, fatal exception, or process kill. This interruption is not counted as a passed complete match.

## Remaining release gates

1. Complete a live Android-to-Android match to 100 points.
2. Verify every move on both screens has the same revision, endpoints, turn, round, and score.
3. Verify online Play Again when both accept and when one declines or times out.
4. Verify Leave Room immediately releases both players and prevents stale matchmaking.
5. Complete an iPhone-to-iPhone match.
6. Complete an Android-to-iPhone match.
7. Recheck the end-of-game card, remaining hands, confetti, lobby return, and ranking update.

## Files changed in this repair pass

- `lib/screens/domino_online_game_screen.dart`
- `lib/screens/domino_cpu_game_screen.dart`
- `test/online_block_game_test.dart`
- `lib/memoria_para_codex.md`
- `pubspec.yaml`
- `VALIDATION_REPORT_2026-07-12.md`

