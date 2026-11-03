# In-game checklist: interface languages

**Feature**: the addon's interface in ten languages and the Language setting (`specs/001-interface-language`;
rules in `docs/languages.md`).
**Closes**: no `VERIFY` markers; the font results go into `specs/001-interface-language/research.md` R6 and
`docs/forever-api.md`.
**Needs**: one client (any language) on a character that has learned Fishing, has a fishing pole and has the
fishing keys bound.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`).
2. Restart the game completely: the translation files are new in the TOC, so `/reload` is not enough.
3. Log in on the character.

## 1. Fonts on this client

Type in the chat (one line):

```
/run for _,f in ipairs({"2002","ARKai_T","ARHei","blei00d","bKAI00M","FRIZQT___CYR"}) do print(f,UIParent:CreateFontString():SetFont("Fonts\\"..f..".ttf",12,"")) end
```

Each line should end with `true` (the client has that font). Write down every `false`.

- [ ] `2002` (Korean): ____
- [ ] `ARKai_T` (Simplified Chinese): ____
- [ ] `ARHei` (Simplified Chinese, bold): ____
- [ ] `blei00d` (Traditional Chinese): ____
- [ ] `bKAI00M` (Traditional Chinese): ____
- [ ] `FRIZQT___CYR` (Cyrillic): ____

Optional, how the chat draws the names:

```
/run print("한국어 繁體中文 简体中文 Українська")
```

## 2. Default: the client language

- [ ] Settings -> AddOns -> OneKeyFishing: the **Language** button in the top right shows "Game client language".
- [ ] On an English client the whole addon is in English, as before.
- [ ] Hovering the Language button shows the tooltip: Korean and Chinese may show as squares; pick English to get a
  readable interface back.

## 3. Switching to Ukrainian

- [ ] Clicking the Language button opens a menu: "Game client language", then English, Deutsch, Español (EU),
  Español (AL), Français, Українська, 한국어, Português, 繁體中文, 简体中文; the current one is marked.
- [ ] Picking Українська shows a popup with "Reload now" and "Later".
- [ ] "Later" closes the popup; the addon stays in English until the next reload.
- [ ] Picking again and choosing "Reload now" reloads the interface.

After the reload, everything below is in Ukrainian:

- [ ] Settings, main page (keys, features, camera, actions) and the Fishing gear page.
- [ ] Action indicator (Cast / Hook! / Apply lure / Open, "No bobber", the drag tooltip).
- [ ] Statistics window (`/okf stats`): titles, rows, row tooltips, buttons, reset popups.
- [ ] Catch notifications.
- [ ] Minimap button tooltip and right-click menu.
- [ ] Item tooltip line (fishing gear / Alt+Click hint).
- [ ] Chat messages (for example `/okf toggle` twice: fishing mode on / off).
- [ ] `/okf` help: the command names stay in English (not translated on purpose); their descriptions are in
  Ukrainian.
- [ ] Options -> Keybindings -> AddOns -> OneKeyFishing: both binding names.

## 4. The choice is kept

- [ ] `/reload`: still Ukrainian.
- [ ] Log out and in on another character of the same account: still Ukrainian.

## 5. Long texts and other scripts

Pick each language below, reload, and look at the settings pages and the statistics window.

- [ ] Deutsch: nothing is cut off or overlaps (buttons grow with their text, checkbox labels wrap, long statistics
  labels end before the first column and show in full in the tooltip).
- [ ] Español (EU), Español (AL), Français, Português: same.
- [ ] 한국어: readable, or squares (as the tooltip warns); the menu still shows "English" readably.
- [ ] 繁體中文: same.
- [ ] 简体中文: same.

## 6. Back to the client language

- [ ] Pick "Game client language", reload: English again.

## 7. The addon list and the language hint

On a client in German (or another language with a translation), on the character screen -> AddOns:

- [x] OneKeyFishing is under the category in the client's language ("Berufe" in German).
- [x] The tooltip of OneKeyFishing shows the description in the client's language, special letters intact
  (ä, ö, ü, ß in German).
- [ ] In game, no chat line "Your game client has no translation..." appears (the client has a translation). That the
  line shows once on a client without one (Russian) is covered by `tests/locale_hint_test.lua`.
- [ ] Statistics window, "Catches per hour": the decimal separator is the client's (a comma on a German client),
  whatever the interface language. Gold of 1000g or more shows the client's thousands separator instead (a point
  on a German client: "1.234g" next to "2,5" is correct).

## 8. Debug report

- [ ] `/okf debug`: the report is in English, with a line `Language: <setting> (in use: <language>)` under the line
  with the client locale.

## 9. Fishing works the same in another language

With the addon in Ukrainian (or any other non-English language):

- [ ] Toggle fishing mode on and off; settings and gear are restored.
- [ ] Cast, hook and loot with the fishing key.
- [ ] A lure is applied when the pole has none.
- [ ] A fished clam or container is opened.
- [ ] The statistics count casts, catches and value.

## Results

- Date, build, client language:
- Fonts missing:
- Problems found:
