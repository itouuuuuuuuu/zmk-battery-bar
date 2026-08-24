# Review, cross-check, and release loop

## Cross-checking a review with a second agent

Non-trivial code-review findings get a second agent's opinion before any fix is
implemented. Report the verdict per finding (VALID / PARTIALLY VALID / REFUTED)
with its reasoning rather than silently folding it in.

Findings from any reviewer — including yourself — are candidates, not facts.
Several plausible-looking `BLEManager` findings have been refuted with concrete
callback-ordering traces (CoreBluetooth callback FIFO ordering, the
`centralManagerDidUpdateState(.poweredOn)` re-entry path, `didConnect`
self-healing). Construct the trace before accepting or rejecting one.

## Handling a review

1. Classify findings: **must-fix before merge** vs. maintainability vs. design
   decisions that need a product call.
2. Say explicitly which ones you are *not* fixing and why. Open-ended
   retry/give-up behaviour (e.g. "retry a forgotten keyboard forever", "give up
   after N empty discoveries and surface an error") is a product decision —
   propose it as a separate PR instead of inventing a policy.
3. Implement the must-fixes; extract any new logic into a pure helper and add
   tests for it (see AGENTS.md → Testing). Run `swift test`, commit, push to the
   same PR.
4. Send the fixes back for re-review and iterate until no findings remain.
   State the round count and the final verdict.

## Release

1. Merging is a human decision. Once the PR is merged, update main and delete
   the merged branch.
2. Choose the version: fixes only → patch.
3. `release/vX.Y.Z` branch → bump both `CFBundleVersion` and
   `CFBundleShortVersionString` in `Resources/Info.plist` → commit
   `Bump version to X.Y.Z` → PR → wait for it to be merged.
4. After that merge, push tag `vX.Y.Z`. Then verify and report:
   - the release workflow run concluded `success`,
   - the GitHub Release exists with the signed/notarized
     `ZMKBatteryBar-X.Y.Z.zip` asset,
   - the Homebrew cask the workflow updates shows the new version (upstream:
     `Casks/zmk-battery-bar.rb` in `itouuuuuuuuu/homebrew-tap`; a fork needs its
     own tap and signing/notarization credentials).
5. Finally update main locally and delete the release branch.
