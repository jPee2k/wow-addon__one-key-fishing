# Research: Import and Export of Catch Records

Phase 0 of [plan.md](plan.md). The background (what limits the exchange, the export-string pattern) is in
[docs/import-export-research.md](../../docs/import-export-research.md).

## R1. The string's shape

- **Decision**: `OKF:<format>:<count>:<check>:<token>,<token>,...:END`.
  - `format` is `1`, `count` is the number of tokens, and `check` is 7 base32 characters.
  - Each token is one record as the exchange sends it (`Share.Encode(Store.ForSending(record))`: CBOR, then Deflate,
    then Base64).
  - Whitespace anywhere is removed before parsing, and text before `OKF:` and after `:END` is ignored.
  - Contract: [contracts/export-string.md](contracts/export-string.md).
- **Rationale**:
  - One token per record lets the import decode and check one record per frame step, exactly as the merge does.
  - The encoding needs no new code, and the exchange's checks apply unchanged.
  - `:` and `,` are not Base64 characters.
  - Removing whitespace survives a chat app or forum that wraps long lines.
- **Alternatives considered**:
  - One CBOR array for all records: it compresses better, but a single bad byte loses everything, and one decode of
    256 KB is one long frame.
  - JSON (`C_EncodingUtil.SerializeJSON`): larger, with no gain.

## R2. The checksum

- **Decision**: `Share.Hash` (the polynomial hash mod 4294967291 the bucket hashes use) over the tokens joined by
  `,`, written as `ns.Base32(hash, 7)`. The import computes it in slices of about 16 KB per frame step.
- **Rationale**:
  - Its job is damage (a cut paste, a changed character), not forgery: forgery is the records' own checks' job
    (decision I2).
  - The hash is plain arithmetic, the same in the game and in fengari, and already tested.
  - One pass over 256 KB is about 20-40 ms in all, so slices keep every step under the budget.
  - The quiz named SHA-256 for this checksum. Over 256 KB the addon's SHA-256 takes about a second (0.3 ms per
    64-byte block). It would need a streaming rewrite of `Digest` to run in slices, and it adds nothing against
    damage. The protection the author chose ("the existing checks plus a checksum") is unchanged.
- **Alternatives considered**:
  - SHA-256, for the reason above.
  - A checksum per token: a cut string would still pass up to the cut, and the count would have to catch it anyway.

## R3. What goes into an export

- **Decision**:
  1. `CatchDB.FlushSeq()`, so the own record carries a seq for all its cells.
  2. Every unit of the own ID (the live record and those a roll kept), as the exchange would send them: proof ready,
     cells of a game version, `CheckRecord` passes, at most `MAX_RECORD_BYTES` encoded.
  3. Others' records in `Store.Units` order by `seen`, newest first, each checked again by `CheckRecord` as the send
     path does. With sharing off, only the units in `shared.imported`.
  4. The export stops before the text would pass `EXPORT_LIMIT` (256 KB).
  - It runs in frame steps (records encoded within the step budget). `Share.TransferState()` reports `"exporting"`
    until the string is ready, and the page shows "Preparing..." meanwhile.
- **Rationale**: the same rules as the send path, so an import elsewhere takes everything the export holds.
- **Alternatives considered**: exporting the saved table as is. It would carry `seen`, and records a peer would refuse.

## R4. The import's steps and answers

- **Decision**: `Share.Import(text)` runs in four steps.
  1. **Parse** (one step): find the markers, check the format, and check that the count equals the tokens found.
  2. **Checksum**, in slices.
  3. **For each token**, one per frame step:
     - `Share.Decode`, then `CatchDB.CheckRecord`;
     - a newer version walks its chain with `CheckVersion(held, record, PROOF_CHUNK, state)` within `WithinBudget`
       (the merge's own code path, `ShareProtocol.lua` `MergeOne`);
     - then `Store.Accept(store, record, now, absorbed, true)` and `Store.Evict`.
  4. **The tally**:
     - `own`: the ID is the own one;
     - `known`: the answer was `same` or `older`, or the record is already in the bundled data;
     - `new`: `new` or `newer`, if the record is still stored after the eviction;
     - `refused`: everything else, an evicted record included.
  - A string that fails the parse or the checksum stores nothing (FR-006). A second `Import` while one runs is
    refused (`"busy"`). The answer reaches the page through `Share.TransferState()`, which the page polls on its
    `OnUpdate` while it is shown, with no message.
- **Rationale**: it reuses the merge's checks and budget, so an import is never weaker than a session. No new message:
  the store's `Changed` already fires `SHARED_DATA_CHANGED`.
- **Alternatives considered**: going through a protocol node. Its merge is bound to a session and a peer (`ourWants`,
  ignore rules), and with sharing off there is no game node at all.

## R5. The imported standing and counting with sharing off

- **Decision**:
  - `shared.imported[unit] = true` is set **before** `Store.Accept`, so the index update fired inside `Accept` sees
    the mark. It is taken back when the answer is `refused` and there was no mark before.
  - A `known` record is marked too, and its unit gets a `Changed` of its own, so a record the player already held
    from the exchange counts with sharing off once they import it.
  - `CatchDB/Index.lua` indexes every other record as today, and the entries of a marked unit carry
    `imported = true` in a second set of indexes.
  - `CountedOthers()` returns `Others()` with sharing on, and the imported-only indexes with sharing off.
  - The views that read others' cells today only with sharing on use `CountedOthers()` instead: `Sources`, the map
    list, `EachHeldCells` with `sharingOnly`, `ScanItems` and the catalog's reporter counts.
- **Rationale**: one place decides what counts, and the views change from a condition to one call.
- **Alternatives considered**: a second store for imported records. It would mean two code paths for everything the
  store does (eviction, cleanup, offers).

## R6. Where the marks end

- **Decision**: `Store.CleanUp` (at `ADDON_LOADED`) deletes the marks of units that are no longer
  stored (deleted as held whole by the seed, evicted, or damaged). A unit evicted and later received again counts with
  sharing off only if it is imported again.
- **Rationale**: the mark belongs to the stored record. A unit the seed absorbed counts through the seed anyway.

## R7. Session rules as an extension point

- **Decision**: `Share.SetSessionRules{ gap = s, strangerChance = p, offerOthers = bool }` sets the game node's rules.
  `ResetSessionRules()` puts back the defaults, and `SessionRules()` returns a copy.
  - The defaults: `gap` is `SESSION_GAP` (120), `strangerChance` is nil (today's `min(1, CHANNEL_TARGET / H)`), and
    `offerOthers` is true.
  - Clamps: `gap` at least 15 s (above the 2-20 s start delay, and one session at a time still holds); `strangerChance`
    between 0 and 1.
  - Unchanged and not settable: the 30 min pause per peer, the session size, the budget, the timeouts, the flood
    limits.
  - Inside the node, `ShareNode.lua` (`SESSION_GAP`, three uses) and `ShareProtocol.lua` (the chance, and the
    records answered to a `WANT`) read `self.rules`. Each node gets the defaults from `Share.NewNode`.
  - With `offerOthers` false, a `WANT` is answered with the own units only. The summary still lists every unit, so
    peers send nothing back that the client already holds.
  - The debug report shows the rules in force.
- **Rationale**: a node keeps its rules, so the simulation can drive one node with other rules (the spec's US2 test),
  and the defaults give the same numbers (SC-004).

## R8. The other extension points

- **Decision**:
  - `Share.AddStatusLine(fn)`: each `fn()` returns a line or nil, shown after the addon's own lines of
    `/okf share`.
  - `Debug.AddSection(title, fn)`: a section after the addon's own, run through `Section` (an error becomes a
    `!! failed` line).
  - `ns.MinimapMenu.AddEntries(fn)`: `fn(root)` adds buttons after "Debug report", in the minimap menu and the Addon
    Compartment, wrapped in `pcall`.
  - `SettingsUI.AddPage(frame, title)`: a page queued until the `PLAYER_LOGIN` registration, then registered as a
    subcategory after the addon's own pages; it returns a function that opens it.
  - Each is a list kept in its module's table, and none fires a message.
- **Rationale**: code that loads after the addon can add itself, and an addition that fails cannot break the addon's
  own items.

## R9. The page

- **Decision**: `UI/TransferPage.lua`, registered through `SettingsUI.AddPage(page, L["Import and export"])`.
  - Two radio buttons (`ns` widgets' radio menu), Import selected when the page opens.
  - A scroll frame with a multi-line `EditBox` (as `UI/CopyWindow.lua` has), and the hint below.
  - On Import, an **Import** button, disabled while `TransferState()` is busy.
  - Export: the box shows "Preparing..." until the string is ready. Then `SetText`, `HighlightText`, `SetFocus`, and
    typing restores the text (read-only, as the copy window does).
  - Import: an empty box with focus, and typing allowed. The hint switches between the instructions and the last
    result.
  - `SettingsUI.OpenTransfer(choice)` opens the page on a choice, for the commands.
  - The page works in a fight, except the settings panel itself, which the game does not open in combat (the
    existing "Settings cannot be opened in combat." line).
- **Rationale**: the decisions I4 and I5. The read-only box and the focus come from the copy window, which is
  proven in game.

## R10. The edit box's limit (VERIFY V78)

- **Decision**: `EXPORT_LIMIT = 256 * 1024` and `SetMaxLetters(0)` (no limit) on the box. A paste the game cuts short
  fails the count or the checksum, and nothing is stored.
- **In game**: export from a store large enough for a string near the limit, paste it back, and the import must say
  "already known" for everything. If the box cuts the text, lower `EXPORT_LIMIT` to what passes.

## R11. Release files

- **Decision**: a tool test asserts that the release package (`tools/addon.mjs`'s file list) is exactly the TOC, the
  files it lists, `Bindings.xml`, `README.md` and the `Media/` sounds, so a file outside the TOC never ships
  (FR-016). The release is built from `git` HEAD, so an untracked file cannot enter it.
