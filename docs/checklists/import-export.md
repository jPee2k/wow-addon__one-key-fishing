# Checklist: import and export of catch records

**Feature**: the "Import and export" settings page, `/okf share import` and `/okf share export`
([specs/027-import-export](../../specs/027-import-export/spec.md)).

**Closes**: V78 (the edit box takes a string near 256 KB), V79 (the dropdown names the chosen choice), V80 (a long paste is taken whole without a freeze), and the user story's acceptance scenarios in game.

**Needs**: two accounts (any factions; one may be the other faction), each with the addon. Account A has catches and
other players' data; account B can have little or none.

## Setup

- [ ] `npm run install-addon` (or `npm run link` once). **Restart the game**: two new files are in the TOC.
- [ ] Log in on account A.

## Steps

1. **The page**
   - [ ] Options → AddOns → OneKeyFishing → **Import and export** opens. The list at the top shows **Import a string**, the text
     area (a dark field with a border) is empty, the cursor is in it, the hint says to paste with Ctrl+V, and an **Import** button is shown.
   - [ ] Press Escape (the cursor leaves the area), then click anywhere in the empty area: the cursor is back and
     Ctrl+V pastes. Paste something, open another settings page and come back: the pasted text is still there.
2. **Export**
   - [ ] Open the list and choose **Export my data** (a dropdown, not a button; its text differs from the **Import**
     button). The list's button reads **Export my data**, and **Import a string** again after picking it (V79). The hint says "Preparing..." for a moment, then the text area holds a string
     starting with `OKF:1:` and ending with `:END`, all selected.
   - [ ] The hint gives the number of records and the size in KB, and says no names are in it. Size: ____ KB,
     records: ____.
   - [ ] Typing in the area does not change the string.
   - [ ] Ctrl+C, then paste into a text editor outside the game: the whole string is there.
3. **Import on another account**
   - [ ] Log in on account B, open the page (Import), Ctrl+V the string and press **Import**. The hint shows the
     counts: ____ new, ____ known, ____ own, ____ refused.
   - [ ] "What can be caught here" or the catalog now shows the new data (a place account A fished).
   - [ ] Press **Import** again with the same string: 0 new.
4. **Sharing off**
   - [ ] On account B, turn **Use the shared catch database** off. The imported data still counts in "What can be
     caught here".
   - [ ] Export on account B: the hint's record count is B's own plus the imported ones.
   - [ ] Turn sharing back on.
5. **A large string (V78)**
   - [ ] On the account with the most data, export. If the hint says less than about 200 KB, note the size here:
     ____ KB.
   - [ ] Paste that string on the other account: no freeze worth noting, the box shows only the start of the string,
     and the hint says "Pasted N KB" with the size the export named (V80).
   - [ ] Press Import: the counts add up to the records the hint named (nothing refused as cut).
6. **Damage**
   - [ ] Delete a few characters from the middle of a pasted string and press **Import**: the hint says the text is
     damaged, nothing new counts.
   - [ ] Paste only the first half: the hint says the text is incomplete.
7. **Commands**
   - [ ] `/okf share export` opens the page on Export, `/okf share import` on Import; `/okf share` alone still prints
     the state.
   - [ ] `/okf debug`: the "Shared database" section has a `transfer:` line with the last export and import, and a
     `session rules: gap 120 s, stranger chance default, offer others true` line.

## Results

- 2026-11-26, client 1.60.1, English and Ukrainian interface, a Horde character (level 41) and an Alliance
  character (level 1), a development build:
  - Steps 1 and 2 passed. The export string was 110 KB with 252 records, and 138 KB with 320 records.
    V79 confirmed.
  - Step 3 passed across the factions: 103 new, 217 known, 0 own, 0 refused, then 0 new. V80 confirmed: the paste
    takes about half a second.
- Problems found and fixed in the same session:
  - The selector was a button with the same word as the Import button. It is now the game's dropdown.
  - The text area had no frame. It now has a dark field with a border.
  - A 110 KB paste froze the game for 4 to 6 seconds. It is now collected by OnChar.
- Known: typing in the Export area shows the letter for one frame before the string comes back. A game edit box
  cannot be read-only and still be copied from.
  - Step 4 passed. With sharing off the imported data showed in the catalog, and the export held only the imported
    records: 336 of 345, 144 KB, since the level 1 character has no catch of its own.
  - Steps 5 and 6 (the shorter parts) passed: a string with characters deleted answered "damaged", and half a
    string answered "incomplete".
  - Step 7 passed: the commands opened the page on the right choice, and the report had the `transfer:` and the
    `session rules:` lines. No error in the log.
- V78 accepted by the author without a check near 256 KB: the largest export so far is 149 KB, the largest paste
  138 KB.
