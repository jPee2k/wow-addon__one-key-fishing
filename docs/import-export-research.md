# Import and export of catch records: research

Pre-spec research for spec 027 (2026-11-25). Catch data travels between players only through the in-game exchange,
which needs both sides online at the same time, on the same faction's channel or as guildmates, group members or
Battle.net friends. A string that a player copies out of the game and another pastes in carries the same records with
no such condition.

Sources are marked: **[Wiki]** warcraft.wiki.gg, **[Addon]** this repository, **[Data]** the author's saved files on
2026-11-25.

## 1. What limits the exchange today

- **[Addon]** A session moves at most 25 records or 8 KB in each direction, one session at a time, 2 min between
  starts, and 30 min between two sessions with the same channel or friend peer. The send budget is 50 KB an hour,
  about 130 records ([exchange.md](architecture/exchange.md)).
- **[Addon]** A cold network of N clients needs about N² records sent, so a full spread takes far longer than a play
  session (research R5 of `specs/004-public-channel-sync/`). The seed of each release fills the gap.
- **[Addon]** The public channel is one per faction, and an addon whisper does not cross the factions. Battle.net game
  data does ([forever-api.md](forever-api.md), "The other faction", 2026-11-24).
- **[Data]** Two of the author's accounts held 74 and 166 records of other players beyond the seed, whose 942
  contributions (epoch 11) the store no longer keeps.
- **[Wiki]** Saved variables are written only at a logout, a disconnect, the exit or a `/reload`. Records gathered in
  a session reach the harvest only after one of those.
  <https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions>

## 2. How other addons move data by hand

- **[Wiki]** An addon cannot send anything outside the game, and has no clipboard API. Export strings are a widely used
  pattern: WeakAuras and its site Wago use them, for example. The addon fills an edit box with selected text; the
  player copies it with the copy key, and pastes a string into an edit box with the paste key.
- Desktop programs that read saved variables after the game closes (Wowhead Client, the TSM app) need a separate
  program and a server. They are out of scope.

## 3. What a string can hold

- **[Addon]** The exchange already encodes records as CBOR, then Deflate, then Base64 (`C_EncodingUtil`). Every record
  carries the proof chain only its owner can extend, and every received record passes the checks of `CatchDB` and
  `Share.Store`: proof, chain, impossible numbers, the seed's `blocked`, and the weights against many fake IDs.
- **[Addon]** A record of 500 busy places is under 32 KB. The store keeps at most 20,000 places (about 2 MB), more than
  a game edit box should take.
- A checksum can tell a damaged or cut string. A secret key cannot protect a string between any two players: every
  player would have to sign, so the key would ship in the addon's open code. The records' own checks are the
  protection against forgery, as in the exchange.

## 4. Decisions (interview with the author, 2026-11-25)

- I1. Between any players, both ways.
- I2. Protection: the checks every received record passes, plus a SHA-256 checksum of the whole string against
  damage. No secret key.
- I3. Content: the player's own record first, then the freshest records of others, up to about 256 KB of text. The
  real limit of the game's edit box is a VERIFY.
- I4. A settings page of its own, "Import and export", with a selector (Import, Export; Import by default).
  `/okf share import` and `/okf share export` open the page on that choice.
  - Export fills the text area at once, selected and focused, with a hint below.
  - Import starts with an empty, focused area, a hint below and an **Import** button.
- I5. After an import the hint shows the result: new records, records already held, the player's own, and records
  refused. The own record and versions already held are not imported again.
- I6. Imported records are ordinary received records: the same checks, passed on through the exchange, shown in the
  catch lists. Import works whatever the sharing switch says, and imported records count at once, also with sharing
  off.
- I7. A player's record once imported keeps that standing (by `<id>@<epoch>`), so its newer versions from the exchange
  count with sharing off too. It is a new saved field.
- I8. With sharing off, export holds what counts: the own record and the imported ones. With sharing on, it holds
  everything.
- I9. Not built: a harvest that reads pasted strings outside the game (an import in game, then the usual harvest, is
  enough).
- I10. The player manual gets a paragraph on Battle.net friends: a friend of the other faction carries that faction's
  records across, with no change to the addon.
