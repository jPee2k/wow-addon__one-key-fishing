# Release plan

What the next releases wait for and in which order things happen. The generic release steps (version, changelog,
pull request, tag) are in [publishing.md](publishing.md); this page is about the checks left after 1.1.0 and
about 1.2.0, which is built but not verified in game yet. It is deleted once 1.2.0 is out.

## 1.1.x: in-game checks left after 1.1.0

1.1.0 went out with the steps below still open in the checklists; a finding goes into a 1.1.x patch.

- [checklists/fishing-mode.md](checklists/fishing-mode.md): leaving the mode when attacked, the best of two
  poles, a lure on cooldown, clams and locked containers, the rank notices from character level 10.
- [checklists/interface-language.md](checklists/interface-language.md) section 10: the Journeyman notice and the
  map pin (level 10), Old Man Heming and the book (level 20), Nat Pagle and the quest ID (level 35, quest 6607
  has no title on Forever yet); their results go into `specs/001-interface-language/research.md` R11 / R12 and
  remove the remaining `VERIFY` marks.
- Korean and Chinese on a client in another language: deferred until a player reports it
  (`specs/007-launch-day-fixes/research.md` R9).

## 1.2.0: the shared catch database

Built on `002-shared-db` (`specs/002-local-catch-db` to `specs/005-catch-catalog`), waiting for the game and for
a second player. Its steps are written on that branch once this page is merged there.

Technical debt to settle when `001-interface-language` is merged into `002-shared-db` (spec 001 research R15):

- Move the older game data into `GameData/` (data only, like `GameData/FishingRanks.lua`): the lures and the
  fished containers (`Fishing/Bags.lua`), the pole bonuses (`Fishing/Gear.lua`), the Fishing spell IDs and the
  bobber ID (`Core/Data.lua`).
- Switch the catch catalog's pin (`Catalog.PinTarget`, `CatalogTab.Pin`) to `ns.MapPin` (`UI/MapPin.lua`), which
  took that code over with the same saved field (`charDB.pin`) and texts; `ns.Toast` already has the `always`
  argument on both branches.
