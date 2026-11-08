# Verification debt: Architecture Alignment

Claude cannot run the game, so the lure requirement is built on the assumptions below. The IDs continue the V
series of specs 002 to 006 (V1 to V42), because the markers share the code. Code that depends on an item carries a
`-- VERIFY(Vn): ...` comment. `npm run check` lists the open markers, and `npm run build` refuses to package while
any is left.

To close an item:
1. Run its step in game (`docs/checklists/fishing-mode.md` "Lure too high").
2. Record the answer in `docs/forever-api.md`.
3. Adjust the code and the values in `OneKeyFishing/GameData/Lures.lua` if the game differs.
4. Remove the markers, and tick the item here.

| ID | Assumption we build on | Evidence before the change | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V43 | Forever keeps the original game's Fishing requirements of the six lures: Shiny Bauble none, Nightcrawlers 50, Aquadynamic Fish Lens 50, Bright Baubles 100, Flesh Eating Worm 100, Aquadynamic Fish Attractor 100 | Wowhead Classic tooltips (`nether.wowhead.com/classic/tooltip/item/<id>`) and a Classic fishing guide agree; 1.1.0 in game: a lure above the skill fails with "Cannot apply ..." | Correct the value in `GameData/Lures.lua`; a value too low only brings back today's failed attempt, a value too high holds a usable lure back until the skill reaches it | `fishing-mode.md` "Lure too high": with skill below 50, Nightcrawlers in the bags is not offered; at 50 it is | Built, waiting for the game |
| V44 | The game compares the requirement with the base Fishing skill (`GetProfessionInfo`'s rank), not with the skill raised by the pole or an applied lure | The Classic rule: requirements read the skill rank; bonuses show apart ("+25") in the skill line | Compare with the skill plus the current bonus (`ns.GetFishingBonus` and the lure's buff) | Same step with a +bonus pole at a base skill just below 50 | Built, waiting for the game <br>**Spec 011:** `Gear.FindBestPole` applies the same rule to the poles' requirement (`GameData/FishingPoles.lua`) and carries the marker too. |
