# In-game checklist: the Luremaster spike

**Feature**: the game facts spec 028 (the Luremaster talent) is to be written on: how the talent's rank is read, what
a lure on the pole looks like, and how the talent's extra fish shows in the loot next to a camp bonus. Research and
the agreed decisions: [luremaster-research.md](../luremaster-research.md); this checklist runs its section 5.
**Closes**: section 5, steps 1 to 8 (no `VERIFY` ids yet: the spec, written after this spike, will cite these
results).
**Needs**: a character with Luremaster rank 1, Fishing 300, ordinary lures (Nightcrawlers or better), a Fishing Hut
(279966) and a campfire, one spot of open water whose fish fit your skill (no school), about 2.5 hours.

The loot is recorded by **OKFSpike**, a throwaway addon that only listens to the game's events (no cast, no item
use). It lives in `Interface\AddOns\OKFSpike\` only, not in this repository, and is deleted after the spike. Per cast
it keeps: the pole's temporary enchant, the Rack and Hut auras, the Luremaster rank, the skill and the place at the
cast's start; every loot slot (item, quantity, quality, source); and the lines, auras and spells seen near the loot.
`/reload` or a logout writes the log to `WTF\Account\<account>\SavedVariables\OKFSpike.lua`, which Claude reads.

Commands: `/okfspike start A` (B, C, D) labels the casts that follow; `/okfspike stop`; `/okfspike sum` prints a line
per session; `/okfspike probe` prints the rank and enchant calls; `/okfspike quiet` turns the loot lines off or on.
While fishing it prints one line per unusual loot: `QTY 2+` (a slot with two or more), `SAME ITEM TWICE`, `TWO
DIFFERENT ITEMS`. A red line means the cast is off the session's plan (a lure where none should be, no Hut aura);
such casts are counted apart.

## Setup

1. Restart the game completely (a new addon). On the character screen, under AddOns, enable **OKF Spike
   (Luremaster)** next to OneKeyFishing.
2. Take off the Wide-Brimmed Fishing Hat if you wear it: its use puts enchant 263 on the pole, a lure.
3. Choose the spot and keep it for all four sessions: ____ (zone, subzone, your Fishing skill).

## Part 1: the rank calls (steps 1 and 7)

The addon records the calls by itself at login, at each `/reload` and when the talents change, and notes how long
after the login the Legacy configuration became readable.

- [ ] Right after logging in: `/okfspike probe`. Expected: `activeRank 1`, `max 2`, `IsSpellKnown true`, and a
  value for `loadDeprecationFallbacks`. Paste the line: ____
- [ ] `/reload`, then `/okfspike probe` again. Expected: the same. ____
- [ ] Open the Legacy window and close it, then `/okfspike probe`. Expected: the same, with `Legacy UI loaded true`.
  ____

## Part 2: the lures on the pole (step 2)

- [ ] For each lure you have at hand, apply it and run `/okfspike probe` (wait for each to run out or use the next
  one on top). Expected enchant: Shiny Bauble 263; Nightcrawlers and Aquadynamic Fish Lens 264; Bright Baubles and
  Flesh Eating Worm 265; Aquadynamic Fish Attractor 266; Camper's Lure 8773. Both values on the `enchant:` line
  (`C_PaperDollInfo` and `GetWeaponEnchantInfo`) should agree. Lures tried and their IDs: ____

## Part 3: four sessions at the same spot (steps 3 to 6 and 8)

Fish each session about 30 minutes in fishing mode, at the same spot, without a school. Leave every loot window to
the auto loot as usual. Pause with `/okfspike stop` when you step away.

- [ ] **A: no lure, no camp** (step 4). Turn off "Apply lures automatically" in OneKeyFishing's settings and let any
  lure on the pole run out. `/okfspike start A`. Expected: **no** `QTY 2+` and no `SAME ITEM TWICE` line in the whole
  session (without a lure the talent should never proc). Note any that come: ____
- [ ] **B: an ordinary lure, no camp** (step 3). Turn "Apply lures automatically" back on (the key keeps the lure on),
  `/okfspike start B`. Expected: about one catch in four with `QTY 2+` (a fish) or `SAME ITEM TWICE` (a crate or
  another container). Note which form each kind of item takes, and any quest item that came doubled: ____
- [ ] **C: the Hut, no lure** (step 5). Place the Fishing Hut by a campfire at the same water (its aura lasts 60
  minutes, enough for C and D). Turn "Apply lures automatically" off and let the lure run out, `/okfspike start C`.
  Expected: some `TWO DIFFERENT ITEMS` (the Hut's extra: a Bloated fish, a herb, ore, a bar), **never** `QTY 2+` or
  `SAME ITEM TWICE`. ____
- [ ] **D: the Hut and Camper's Lure** (steps 5 and 8). Still under the Hut's aura, put a Camper's Lure on the pole
  (it lasts 5 minutes; the Hut gave five, so this session may last 25 minutes), `/okfspike start D`. Expected, if
  Luremaster works with Camper's Lure: `QTY 2+` or `SAME ITEM TWICE` about one catch in four, besides the Hut's `TWO
  DIFFERENT ITEMS`. Note any catch that shows both at once: ____
- [ ] **Traces** (step 6): did any chat line, message or effect on screen come with a doubled catch and not with an
  ordinary one? (The addon records the lines, auras and spells; this is what you saw.) ____

Round 1 (2026-11-27) ran B and D at Riverglades and C, D and a session E (the Hut with Bright Baubles) at Tanaris;
results in [luremaster-research.md](../luremaster-research.md) section 6: a proc is a second slot with an ordinary
fish of the water, and Riverglades showed neither the talent nor the camp. The loot lines now say `TWO SLOTS` for
a second slot; `/okfspike sum` prints a line per session and map, and session D expects any lure.

## Part 4: round 2 at Moonglade (map 1450)

The same spot of open water at Lake Elune'ara for all four, a fishing pole, Bright Baubles.

- [x] **A: no lure, no camp, 30 minutes.** "Apply lures automatically" off, no lure on the pole, no camp aura.
  `/okfspike start A`. Expected: no `TWO SLOTS` line at all. 63 catches, none with two slots or quantity 2.
- [x] **B: Bright Baubles, no camp, 1 hour.** "Apply lures automatically" on. `/okfspike start B`. Expected:
  `TWO SLOTS` with two ordinary fish of the lake about once in four catches, if the talent works without a camp. 99
  catches, 28 procs (19 second slots, 9 Raw Redgill x2).
- [x] **C: the Hut, no lure, 1 hour** (one Hut). "Apply lures automatically" off, wait for the lure to run out, place
  the Hut by a campfire, `/okfspike start C`. Expected: the Hut's own extras (a Bloated fish, a herb, ore, a bar) as
  `TWO SLOTS`, and no second ordinary fish. 137 catches, 17 Hut extras, none a fish of the lake.
- [x] **D: the Hut and Bright Baubles, 1 hour** (a second Hut). "Apply lures automatically" on, `/okfspike start D`.
  Expected: both kinds of second slot; note any catch with three slots. 161 catches, Luremaster 39, the Hut 25, both
  6, five with three slots.
- Rack: not checked (accepted: the Rack's extra is taken to behave like the Hut's).

## Finish

- [ ] `/okfspike sum` and paste its lines: ____
- [ ] `/reload` (it writes the log), then tell Claude: the log is read from `SavedVariables\OKFSpike.lua`.
- [ ] After Claude has read it: delete the folder `Interface\AddOns\OKFSpike\` (and, if you like, the log file).

## Results

- Date: 2026-11-27/28 (round 1 Riverglades and Tanaris, round 2 Moonglade)
- Client language: enUS
- Build: 1.60.1.71139, OneKeyFishing 1.7.2
- Problems found: the statistics count Luremaster procs under a camp as camp bonus catches (`Camp.IsBonusCatch`);
  neither the talent nor the camp acted in Riverglades (map 2548). Results in
  [luremaster-research.md](../luremaster-research.md) section 6.
