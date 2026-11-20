# Architecture: fishing mode

The fishing key, entering and leaving the mode, gear, camera, lures and containers, and the skill. Principle III
of the constitution says what must be restored when.

## Fishing/Action.lua

The single fishing key.

- Keys bound to `ONEKEYFISHING_ACTION` (Bindings.xml) are overridden only while the mode is on.
- When the player is not channeling, the key clicks `OneKeyFishingButton` (SecureActionButtonTemplate). Its
  `PreClick` resolves the action by priority: apply lure, then open a fished container, then cast Fishing.
- While channeling Fishing, the key is bound to `INTERACTTARGET` (soft-target interact hooks the bobber).
- The overrides are owned by a `SecureHandlerStateTemplate` frame whose `[combat]` state driver clears them inside
  combat. The driver passes the state as a number, so the handler compares `tonumber(newstate) == 1` (spec 009,
  research R1; V45). The hook (`INTERACTTARGET`) goes too, so a bobber still out cannot be hooked in a fight.
  `Action.IsPaused()` is true from `PLAYER_REGEN_DISABLED` to `PLAYER_REGEN_ENABLED` while the key is enabled, and
  the start fires `ACTION_STATE("paused")` for the indicator.
- `Action.Enable` picks up a Fishing channel that is already running (`UnitChannelInfo`), because no
  `CHANNEL_START` comes for a cast begun before a `/reload` or before the mode was switched on.
- The keys are re-read on `UPDATE_BINDINGS` and after combat; our own overrides fire that event too, so it rebinds
  only when the keys changed.

## Fishing/Mode.lua

Enter and exit fishing mode.

- Every changed CVar, the gear swap and the camera zoom are stored in the character DB *before* changing anything.
  As a result, exit, logout, `/reload` (which also fires `PLAYER_LOGOUT`) and crashes restore the CVars
  (`PLAYER_LOGIN` restores any left over) and the gear. WoW writes saved variables only at a logout, a
  `/reload` or the exit, never at a crash (general WoW behaviour, not checked on Forever: `docs/forever-api.md`), and the logout restores the CVars before that write: a crash leaves no
  record on disk, so the login restore covers what an earlier session left (spec 015 review 4).
- The saved zoom (Camera.lua) survives a `/reload` but is dropped on a real login (`isInitialLogin`), so after a
  logout, crash or disconnect in fishing mode the previous zoom is not restored.
- `PLAYER_LOGOUT` with the mode on restores the CVars, sets `resumeMode`, and keeps the live rows the player owns
  (below; the "Sound effects" rows, which their switch takes back; the others are set again by the resume) in
  `charDB.resumeOwned`; `PLAYER_ENTERING_WORLD` takes and clears both and resumes only
  when `isReloadingUi` is true too, starting with those rows as the player's (a real login or a resume that does not
  happen drops them), after a 1 second delay, because bindings and the spellbook are not ready then.
  If it cannot resume (combat), the camera comes back at once and the gear after combat.
- Leaving in combat only sets a pending exit and says "Leaving fishing mode after combat." once; nothing is equipped
  in the lockdown, and the whole exit (gear, camera, CVars) runs on `PLAYER_REGEN_ENABLED`.
- An attack with "Leave fishing mode when attacked" on (`PLAYER_REGEN_DISABLED`, before the lockdown) swaps the
  weapons back, sets the pending exit and prints the same line once; the key hint waits 5 s before repeating it.
- While the mode is on, the plain binding body of the action key only runs when combat dropped the overrides, so
  `OneKeyFishing_ActionKeyIdle` says why the key does nothing.
- The CVars are rows of `CVARS` (`name`, `value` or `value(old)`, `setting`, `live`, `combat`); `Mode.CVAR_NAMES`
  lists them for the debug report. `SyncCVars()` brings every row to what it wants now (the mode on, its setting
  on, not lifted by a fight): a wanted row not yet saved is recorded in `charDB.savedCVars` (`name -> old value`)
  and then set (recorded also when it already holds the value, so a later hand change is seen); a saved row no
  longer wanted is restored. The login line "Restored game settings..." shows only when a value came back. Enter
  (after `active`)
  syncs every row, `PLAYER_REGEN_DISABLED` / `ENABLED` only the `combat = "lift"` rows, `SETTINGS_CHANGED` only the
  `live` rows of that setting, so the other rows keep their "next time" behaviour; exit, logout and `PLAYER_LOGIN`
  restore every saved row. `Mode.InFight()` tells the fight (from `PLAYER_REGEN_DISABLED` to `ENABLED`, at load from
  the lockdown, for a `/reload` in a fight); Fishing/Sound.lua reads it.
- A restore puts the old value back only while the CVar still holds the row's applied value (numbers compared as
  numbers); a value the player changed while fishing stays and only its record is dropped (constitution Principle
  III, spec 013). Such a row is not set again in the same session (a fight's end does not silence the music the
  player turned up), also across a `/reload` that resumes the mode (spec 015), until its setting is switched on
  again or the next entry. A lifted row the player changes during
  the fight is marked the same way: its value right after the lift is kept and compared at the fight's end. A saved name without a row (an older
  build's) is set back as it was.
- The rows of the "Sound effects" page (spec 013): `Sound_EnableSoundWhenGameIsInBG` (`backgroundSound`, live, kept
  in a fight) and the splash focus (`splashFocus`, live, `combat = "lift"`): `Sound_MusicVolume`,
  `Sound_AmbienceVolume`, `Sound_DialogVolume` to 0, `Sound_EnableSFX` to 1, `Sound_SFXVolume` to `max(old, 0.9)`.
  A fight restores the focus rows at its start (before the lockdown) and sets them again at its end while the mode
  stays on. The other rows keep their "next time you enter fishing mode" behaviour.

## Fishing/Sound.lua

The fishing sounds of the "Sound effects" page (spec 013), `ns.Sound`, loaded after `Catch/Catch.lua`.

- Plays the author's files from `Media/Sounds/` through `PlaySoundFile(path, "Master")` in `pcall`, one handle per
  event, the event's previous sound stopped first: `bell` on `FISHING_CAST_START` (once per cast), `hook` on the
  result of the hook press (`FISH_CAUGHT` or `FISH_ESCAPED` of the cast, Catch.lua, once per cast), `rare` 0.4 s
  after the hook sound when an item of the loot has `quality >= Enum.ItemQuality.Uncommon`. The fishing key runs the game's
  interact action while the line is out, so no addon code sees the press; its result is what the addon hears.
- Only while `settings.fishingSounds` is on, fishing mode is on and no fight is running (`Mode.InFight()`);
  `MODE_CHANGED(false)`, `Sound.SetEnabled(false)` and `PLAYER_REGEN_DISABLED` stop every sound (a delayed rare sound
  checks a token).
- The volume (`settings.soundVolume`, 0-100 in steps of 10, `Sound.Volume()` clamps a saved value) picks the file:
  100 % the master `Media/Sounds/<name>.ogg`, a step its copy in `Media/Sounds/Volume<step>/` (rendered by
  `npm run sounds`: `PlaySoundFile` has no volume argument), 0 % nothing (`Sound.Path`).
- `Sound.SetEnabled` is the only writer of `settings.fishingSounds` (fires `SETTINGS_CHANGED`); `Sound.Preview()`
  plays the hook sound at the current volume for the settings slider, also outside fishing mode, not in a fight.
- The game audio settings of the same page are rows of Mode.lua (above), not of this module.

## Fishing/Gear.lua

- Equips the chosen pole (or the best pole by fishing bonus) plus user-picked extra items. The best pole passes
  over a pole whose `GameData.FishingPoles[id].skill` is above the Fishing skill (an unknown skill, or a pole not
  listed, holds nothing back; the pole already in the main hand is usable, so it is never passed over); a pole
  chosen by hand is kept.
- It records only the slots it changed (`charDB.gearSwap`). On exit a slot is restored only if it still holds
  what the addon put there.
- The fishing bonus is parsed from tooltip lines that contain the client's localized Fishing spell name minus its
  first UTF-8 character (tooltips may lowercase it, and `string.lower` only handles ASCII).
- Weapons return only before the combat lockdown (`PLAYER_REGEN_DISABLED`); a restore asked for in the lockdown
  waits for `PLAYER_REGEN_ENABLED` (Gear's `restoreAfterCombat`: only a restore the lockdown refused, done there when fishing mode is off; Mode's exit
  does it otherwise). An attack during a cast defers the swap past that moment, so the weapons come back after the
  fight: the game's limit, not covered by constitution III's "weapons at once".
- `C_Item.EquipItemByName` fails silently while casting or channeling ([forever-api.md](../forever-api.md)).

## Fishing/Camera.lua

- Zooms to `settings.cameraDistance` on entering fishing mode and back on exit.
- The previous zoom is kept in `charDB.savedCameraZoom`, so it survives a `/reload`; `Camera.Forget` drops it on
  a real login (Mode.lua).
- A zoom is animated, so for 1.5 s after one the target, not `GetCameraZoom()`, is the starting point.

## Fishing/Bags.lua

Lures and fished containers.

- `FindLure` takes the best lure in the bags (`GameData.Lures` by `order`, best first) that is usable, not on its
  own cooldown (`C_Container.GetItemCooldown`, the global cooldown does not count) and not above the Fishing skill.
  It fires `LURE_READY` for lures passed over because of a cooldown, when the soonest one is ready.
- The skill rule: a lure whose `skill` is above `Skill.Get()` (the base rank, without bonuses: `VERIFY(V44)`) is
  never offered. Once the skill reaches it, the next `FindLure` offers it, in the same session. While the skill is
  unknown, nothing is held back. The values come from the original game and match the items'
  tooltips in game (V43, `specs/008-architecture-alignment/verification.md`). A lure not in `GameData.Lures` is never offered.
- An attempt counts as failed only when, 8 s later, the pole has no lure and the lure is not on cooldown; a failed
  lure is skipped until fishing mode is entered again. `skippedLures` keeps the skill of the refusal (0 when not
  known): a skill event clears a lure whose requirement that skill did not meet and the skill meets now (offered
  while the skill was unknown; spec 012). A lure refused with its requirement met stays skipped: it was refused for
  another reason, and a retry on every skill point would only repeat the failure.
- `Bags.DescribeLures` feeds the debug report.
- A container's loot window is matched to the open attempt by the item GUID (`GetLootSourceInfo`); nothing is
  opened over an open loot window; a container whose loot did not fit waits for free bag space, a locked one is
  skipped for the session.
- Everything looted from fishing goes into `fishedItems`, by the ID of its loot link (also an item the client does
  not know yet), so new Forever containers are opened without a list update. Bags reads the loot on its own
  `LOOT_READY`, where it also tracks the open loot window, not from `FISH_CAUGHT`, which comes only for the first
  loot of a counted cast.
- The bag iterator `ns.ForEachBagItem` is in Data.lua ([core.md](core.md)).

## Game data

The game data fishing mode reads is the model `ns.GameData` ([game-data.md](game-data.md)): the Fishing spells and
the rank steps with the NPC names (`Skill.lua`), the lures and fished containers (`Bags.lua`), the poles, the pole's
item class and the equipment slots (`Gear.lua`, `Action.lua`), the bobber (`Core/Data.lua`).

## Fishing/Skill.lua

- The Fishing skill (`Skill.Get`), rank names (`Skill.GetRankName`: the rank spell's subtext in the client's
  language, else `L`), and the next-rank advice `Skill.GetNextRank()` (state `later` / `now` / `level` / `cap`,
  the where sentence, the pin target, where each name came from). It stores the session's starting rank.
- Every game name is read by ID in the client's language (`C_Map.GetAreaInfo`, `C_Item.GetItemNameByID`,
  `C_QuestLog.GetTitleForQuestID`; the book and quest are requested at login), NPC names from a creature tooltip
  (kept once the client gave it), then `ns.GameData.NpcNames`, then English.
- Notices: "can learn" once per session per rank (chat and toast, waits for the character level), the cap with a
  raid warning the first time per session and a chat line on later fishing mode entries; the chat line carries a
  `worldmap:` link when a pin is possible (`Core/MapPin.lua`). Chat and the raid warning are here; the toast goes
  through `SKILL_WARNING`, shown by `UI/Toast.lua`. It checks on skill events, a level-up, after login, on
  entering fishing mode and at the end of a fight (`PLAYER_REGEN_ENABLED`). In a fight (`InCombatLockdown()`) the
  check does nothing: weapon skill-ups fire the skill events there, and a notice owed then comes after the fight.
- A name the game gives as a secret value (a creature tooltip line in an instance fight, seen 2026-11-08) counts
  as missing: the fallback name is used and nothing is cached.
- `Skill.DescribeNextRank` is the line of the statistics window and the minimap tooltip.

## Fishing/Camp.lua

The camp bonuses (spec 020), `ns.Camp`: the fishing buffs of a Fishing Rack or a Fishing Hut placed by a campfire,
listed in `GameData.CampBonuses` ([game-data.md](game-data.md)). It only reads: nothing is cast, used or placed,
and it creates no frame (FR-008).

- The state per bonus, `state[key] = { known, expires, first }`: `known` once read this session, `expires` the
  `GetTime()` at which the buff ends (nil when not active; an aura without an end reads as `math.huge`), `first` the
  seconds left when this `expires` was first seen. Unknown (a login or `/reload` inside a fight), active, or not
  active; a read sets it, the clock ends an active bonus, nothing else changes it. `Camp.IsActive(key)` answers
  `true`, `false` or nil (unknown), `Camp.TimeLeft(key)` the seconds left.
- `Camp.Read()` reads each aura by its spell ID (`C_UnitAuras.GetPlayerAuraBySpellID`), never by name, and never
  while auras are restricted (`InCombatLockdown()` or `C_Secrets.ShouldAurasBeSecret()`): in a fight the call returns
  nothing for an aura that is up. A table with a plain `expirationTime` is an active buff, nothing is no buff,
  anything else (a secret value) changes nothing. It reads on `PLAYER_ENTERING_WORLD`, `UNIT_AURA` for `"player"`
  only (the event comes for every unit; its payload, secret tables in a fight, is never read), `PLAYER_REGEN_ENABLED`,
  `FISHING_CAST_START` and when a notice timer comes due. In a fight the state kept from before stands, and a buff
  ends there by the clock.
- `Camp.Mask()` is nil when any bonus is unknown, else the sum of the bits of the active bonuses (0: none).
  `FISHING_CAST_START` (Catch.lua, earlier in the TOC, has numbered the cast) reads and keeps the start mask under
  the cast's ID (`false` when unknown). `Camp.CastMask(castID)` answers the start mask when it is a number equal to
  `Mask()` now, else 0: a buff that began or ended during the cast, or a state not known, counts for no bonus. It
  drops the masks of earlier casts and keeps this one, because Catch.lua settles a miss a second after the cast
  stopped, maybe after the next cast started, and two modules (CatchDB and Stats) ask for the same cast; masks more
  than 8 casts old are dropped at a cast's start. The mask is never sent in a message: `FISH_CAUGHT` and
  `FISH_MISSED` keep their arguments.
- `Camp.HasBit(mask, key)`, `Camp.KnownBonus(itemID)` (the bonus whose known list names the item) and
  `Camp.IsBonusCatch(mask, items)` (a catch under the mask holds a known item of one of the mask's bonuses: the
  statistics' bonus catches).
- The notices (research R10): a check runs after every allowed read and when a timer comes due; the clock alone
  never shows one. Each active buff arms two `C_Timer.After` timers, a second past the five-minute threshold and a
  second past the end, so the timer's own check finds the crossing; while auras are restricted a timer does nothing
  and the read at the fight's end checks. A crossing ("ends in 5 minutes": the last check saw more than 300 s left,
  now 300 s or less; "has ended": the last check saw it active, now it is gone) is marked as passed the moment it is
  found, whatever the mode and the setting; it fires `CAMP_BONUS_WARNING(text)` only when fishing mode and
  `settings.campBonusWarning` are on then, the five-minute one only within 30 s of the crossing. A crossing passed
  silently is not shown later. A renewed buff (a later expiration on a read) starts a new pair and cancels the old
  one's end. With "Leave fishing mode when attacked" on, Mode.lua (registered earlier) leaves the mode at the fight's
  end before Camp reads, so a buff lost in a fight ends silently; with it off the end notice comes after the fight.
  The texts are read when a notice fires, not at load.
- `Camp.Describe()` gives the debug report's "Camp bonus" lines (English): each bonus's state, whether aura reads
  are restricted, the last mask `CastMask` answered, the setting.
- Its assumptions: `VERIFY(V62)` to `VERIFY(V65)` ([verification.md](../../specs/020-camp-buffs/verification.md)).
