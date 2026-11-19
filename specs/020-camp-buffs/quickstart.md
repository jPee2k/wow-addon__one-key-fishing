# Quickstart: Fishing Camp Buffs

**Feature**: [spec.md](spec.md) | **Contract**: [contracts/module-api.md](contracts/module-api.md)

## Automated

```
npm run check
npm test
```

What the tests prove (each fails without its change):

| Test | Proves |
|---|---|
| `tests/fishing/camp_state_test.lua` | a bonus is active, not active or unknown from the aura stub; no read while restricted, the kept state stands; a buff ends by the clock in a fight; the mask of two bonuses (FR-001 to FR-003, FR-006) |
| `tests/fishing/camp_cast_test.lua` | `CastMask`: the same mask at start and settle counts; a buff that began or ended in the cast, or an unknown state, gives 0; a miss settled after the next cast started keeps its mask (FR-004) |
| `tests/fishing/camp_notice_test.lua` | one notice at five minutes left and one at the end; none outside fishing mode or with the setting off; only the end notice when less than five minutes were left; a renewed buff warns again; no notice from the clock in a fight, the end found after it or not at all when the buff was renewed or the mode left (FR-031 to FR-033) |
| `tests/fishing/lures_test.lua` (extended) | Camper's Lure is offered before the +50 lures and after the +75 ones, and passed over below Fishing 50 (FR-036) |
| `tests/gamedata/camp_bonuses_test.lua` | the list's shape: distinct keys and bits, the twelve Bloated fish under the Rack |
| `tests/catchdb/bonus_recording_test.lua` | a cast with a mask adds to the totals and to its part, a miss too; mask 0 writes no part; mask 3 writes one part (FR-005, FR-006, FR-009) |
| `tests/catchdb/bonus_check_test.lua` | a record with valid parts passes; a part above the totals, a key that is not a mask's text, too many parts, an item outside the cell are refused; unknown bits pass (FR-009, FR-012) |
| `tests/catchdb/bonus_views_test.lua` | the filter values (a key, "none", "all") over own, seed and others' cells; the miss rate under a bonus; mask 3 counts for both bonuses and once for "none"; cells without parts count for "all" and "none" (FR-013, FR-025, FR-026) |
| `tests/catchdb/bonus_tag_test.lua` | a known item is tagged with and without bonus data; an item caught only under a bonus is tagged from the data when the seed or three players hold it so, one caught also outside is not; the numbers come from the view's own scope, no view asks another; the Hut over the Rack; the chance and the little-data flag come from the bonus's catches; untagged items keep 1.4.0's numbers (FR-016 to FR-022, SC-003, SC-008) |
| `tests/exchange/share/bonus_clean_test.lua` | a received record keeps its parts through the store and a relay (FR-010) |
| `tests/exchange/share/bonus_old_client_test.lua` | a cell cleaned by the 1.4.0 field list keeps its totals, loses `q` and still passes the check (FR-011) |
| `tests/tools/harvest_test.mjs` (extended) | the harvest keeps, checks, sums and writes the parts; a scaled cell still passes its check and keeps "all catches in parts"; a cell with a bad part is skipped (FR-014) |
| `tests/catalog/bonus_test.lua` | a zone place, a spot and a row take the bonus's chance, catches and players; a missing chance is "Little data"; the order by chance uses it; `ChanceText` with the bonus; the icon; the tooltip lines and their bonus key (FR-019, FR-020) |
| `tests/catch/stats_bonus_test.lua` | bonus casts and bonus catches in the three buckets; a saved bucket without the fields reads 0 (FR-034) |
| `tests/core/percent_test.lua` | `37%`, `3.4%`, `0.47%`, `<0.01%`, the rounding edges, `0%` for 0 (FR-029, FR-030) |
| `tests/ui/here_bonus_test.lua`, `tests/ui/catalog_bonus_test.lua` | the button hidden without data, its values, the Hut only with Hut data, the fallback to "All catches", Water hidden while the bonus button shows; the tag's icon on a row and its words in the row's tooltip (FR-019, FR-023, FR-024, FR-027, FR-028) |
| `tests/ui/tooltips_test.lua`, `stats_window_test.lua` (extended) | the tag's line in an item tooltip; the two rows and their hiding (FR-019, FR-035) |
| `tests/ui/toast_bonus_test.lua` | the notice's text is shown with catch notifications off (FR-032) |
| `tests/fishing/camp_state_test.lua` (extended) | the source of `Fishing/Camp.lua` holds no cast, item-use, secure or frame call (FR-008) |
| `tests/core/report_sections_test.lua`, `migrations_test.lua` (extended) | the "Camp bonus" section; the default of `campBonusWarning` (FR-038) |

## In game

The checklist `docs/checklists/camp-buffs.md` (made with the tasks), in short:

1. Place a Fishing Rack: `/okf debug` shows "rack: active" with the time left; fish, and the current place's part
   of mask 1 grows with every cast.
2. Catch a Bloated fish: its row in "What can be caught here" and in the catalog carries the Fishing Rack's icon
   (V66); the row's tooltip says "Fishing Rack bonus", the explanation and the chance with the bonus.
3. The "Camp bonus" button: there once a cast under the buff is recorded; its three values; the texts fit the
   button in French and German. `/okf debug`: the encoded size of the own record with parts (V67).
4. A rare item reads with a fraction, never "0%".
5. With six minutes of the buff left, in fishing mode: the five-minute notice and the end notice (V64, V65); die with
  the buff out of a fight: the end notice; with "Leave fishing mode when attacked" off, die in a fight: the end notice
  after it.
6. The statistics window: "Casts with a camp bonus" and "Bonus catches".
7. Camper's Lure from the Rack: the fishing key offers it.
8. A second player on the new version receives the record and sees the tag and the filter; one on 1.4.0 sees the
   totals and no error.
9. Later, with Fishing 300: the Fishing Hut (V60), both buffs at once (V62).
