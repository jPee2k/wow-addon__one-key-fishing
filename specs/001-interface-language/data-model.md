# Data Model: Interface Language

## Language preference (saved, account-wide)

| Field | Where | Type | Default | Rules |
|---|---|---|---|---|
| `settings.language` | `OneKeyFishingDB` | string | `"auto"` | `"auto"` or a language code from the registry |

- New key only: `ApplyDefaults` fills it for existing players, so `DB_SCHEMA` stays 1 and no migration is
  needed (players upgrading get `"auto"`, as the spec requires).
- A stored code that is not registered (a language removed in a later version) is treated as `"auto"` when
  resolving; the stored value is left as it is, so a downgrade-upgrade round trip keeps the choice.

## Language (registry entry, runtime only)

| Field | Type | Example | Notes |
|---|---|---|---|
| `code` | string | `"ukUA"` | WoW locale code; `ukUA` is the addon's own code (no client reports it) |
| `name` | string | `"Українська"` | native name, shown in the language menu |
| `fill` | function(L) | | sets `L[english] = translation`; called only for the effective language |

- Registered by `ns.AddTranslation(code, name, fill)` from `Locales/<code>.lua`; English is registered by
  `Locales/enUS.lua` with an empty `fill`.
- Menu order is fixed (`LANGUAGE_ORDER` in `Localization.lua`): enUS, deDE, esES, esMX, frFR, ukUA, koKR, ptBR,
  zhTW, zhCN; only registered codes are listed.

## Effective language (runtime only)

- `ns.language`: the code in use for this UI session, set once in `ADDON_LOADED` by
  `ns.ResolveLanguage(settings.language, GetLocale())` (see `research.md` R3).
- Changes only through a UI reload; changing the preference does not change it.

## Translation lookup

```text
L[key] -> translations[ns.language][key] -> key (English)
```

- Before `ns.language` is set, a lookup returns the key and is recorded in `ns.earlyLookups` (test guard,
  `research.md` R1).

## State transitions

```text
preference "auto" --pick language X--> preference X (saved) --"Reload now"--> effective language = X
                                                      \--"Later"--> effective unchanged until next reload/login
preference X --pick "Game client language"--> preference "auto" (same reload prompt)
```
