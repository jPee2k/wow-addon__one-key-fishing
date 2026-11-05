# Data Model: Launch Day Fixes

No saved data changes: no field in `OneKeyFishingDB` or `OneKeyFishingCharDB` is added, renamed or reshaped, so
`DB_SCHEMA` stays as it is. The fixes only read existing data and show it.

## What the fixes read

| Data | Where it lives | Read by | Rules |
|---|---|---|---|
| Extra gear list | `charDB.gear.items` (item IDs) | Fishing gear page | one row per ID, in list order, up to `MAX_GEAR_ROWS` (14); no row without an ID; a row's tooltip only for its ID |
| Chosen pole | `charDB.gear.pole` | gear page, debug report | nil means "best pole in the bags" |
| Keys of an action | the game's bindings `ONEKEYFISHING_ACTION`, `ONEKEYFISHING_TOGGLE` | `ns.KeyText` | 0, 1 or 2 keys in the game's order; a key that appears twice is shown once |
| Addon language | `ns.language` (resolved at `ADDON_LOADED`) | popups (through `ns.L`), minimap tooltip | `koKR`, `zhCN`, `zhTW` get the blank last tooltip line |
| Report values | Bags, Gear, Skill, CVars | `/okf debug` | a missing value prints as `nil`; no section stops |

## Texts added to every locale

| Key (English) | Used by |
|---|---|
| `Yes` | default accept button of `ns.ShowPopup` |
| `No` | default cancel button of `ns.ShowPopup` |
| `Cancel` | cancel button of the map pin replace popup |

Translations: [research.md](research.md) R3.

## States

- **Statistics buttons**: one row (everything fits: the left three at the left, Scan at the right edge) or two rows
  (Scan does not fit: the left three on the first row, Scan at the left of the second; the window is one row
  taller). Decided once, when the window is built in the current language.
- **Gear page rows**: hidden (no item) or shown (item ID, icon, name, slot, Remove); recomputed on build, on show
  and on every gear or item data change.
