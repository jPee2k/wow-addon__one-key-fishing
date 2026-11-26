# Quickstart: Import and Export of Catch Records

What the tests prove, and how to see it in game.

## Without the game

```sh
npm run check
npm test
npm test -- share/transfer  # export and import (tests/exchange/share/transfer_test.lua)
npm test -- imported_counts # counting with sharing off (tests/catchdb/imported_counts_test.lua)
npm test -- share/protocol  # the session rules and their defaults (end of tests/exchange/share/protocol_test.lua)
npm test -- extension       # status lines, report sections, menu entries, pages (tests/ui/extension_points_test.lua)
npm test -- channel/sim     # the simulation's numbers with the default rules are unchanged (SC-004)
```

The tests show:

- **Round trip**: an export of store A, imported into an empty store B, gives B the same records, the own record
  first, under the size limit ([contracts/export-string.md](contracts/export-string.md), "Guarantees").
- **Refusals**: a string cut anywhere, one changed character, an unknown format or no markers stores nothing. A
  forged record (a broken chain, impossible numbers, a blocked ID) is counted as refused and the rest is imported.
- **The tally**: new, known, own and refused, for every store answer.
- **Sharing off**: imported records count in the views (here, the catalog, best places), records from the exchange do
  not, and a newer version of an imported unit counts as well. The marks of units gone are dropped at load.
- **Frame steps**: an import of a string at the limit runs over many steps, none longer than the budget (fake clock).
- **Session rules**:
  - the defaults give today's behaviour;
  - a node with `gap = 30`, `strangerChance = 1` and `offerOthers = false` starts more sessions and answers a `WANT`
    with its own record only;
  - the clamps hold.
- **Extension points**: nothing is added when none is registered; added lines, sections, entries and pages show after
  the addon's own, and one that fails leaves the rest.
- **Release files**: the release package lists only TOC files, `Bindings.xml`, `README.md` and `Media/` sounds.

## In game

1. **Export**: open Options → AddOns → OneKeyFishing → Import and export, then choose Export. The text appears
   selected. Press Ctrl+C and paste it into a text editor: it starts with `OKF:1:` and ends with `:END`.
2. **Import on another account**: open the page there (Import is chosen), press Ctrl+V and then **Import**. The hint
   shows the counts, and the catch lists show the new data.
3. **Again**: import the same string a second time. The hint says 0 new.
4. **Sharing off**: turn the shared database off, then import. The data counts; the exchange's data does not.
5. **A large string (V78)**: see [verification.md](verification.md).
6. **Commands**: `/okf share export` and `/okf share import` open the page on that choice.

The in-game steps are in [docs/checklists/import-export.md](../../docs/checklists/import-export.md).
