-- Skill.lua: the next Fishing rank (spec 001, User Story 3). Thresholds and the level wait, the notices, the names
-- from the client with their fallbacks, one sentence per learning source and the map link.
-- The tests are the steps of one character's way from Apprentice to Artisan and run in order.

fishing_skill = { 49, 75 }
player_level = 12
unknown_items[16083] = true -- the client has not loaded the book yet: no name for it
load_addon()
advance(2) -- the check a moment after logging in

local Skill = ns.Skill

local function count(text)
    local n = 0
    for _, line in ipairs(chat) do
        if line:find(text, 1, true) then
            n = n + 1
        end
    end
    return n
end

test("before skill 50 there is advice but no notice", function()
    local advice = Skill.GetNextRank()
    eq(advice.state, "later", "state")
    eq(advice.rank, "Journeyman", "next rank (no spell subtext: the addon's own name)")
    eq(count("Journeyman Fishing"), 0, "no notice yet")
    player_level = 5
    eq(Skill.DescribeNextRank(Skill.GetNextRank()):sub(1, 64),
        "Next rank: Journeyman Fishing, from skill 50 and character level", "the line names a missing level too")
    player_level = 12
end)

test("the client is asked for the book and the quest at login", function()
    assert(requested_items[16083], "book 16083 requested")
    assert(requested_quests[6607], "quest 6607 requested")
    assert(requested_spells[7732] and requested_spells[18248], "rank spells requested (their subtext is the name)")
end)

test("with the reminder off, skill 50 brings no notice but keeps the advice", function()
    ns.db.settings.skillCapWarning = false
    fishing_skill = { 50, 75 }
    fire("SKILL_LINES_CHANGED")
    eq(Skill.GetNextRank().state, "now", "state")
    eq(count("You can learn"), 0, "no notice")
    ns.db.settings.skillCapWarning = true
end)

test("at skill 50 a quiet notice names the trainer", function()
    ns.db.settings.toasts = false -- catch notifications off: the rank notice still shows
    fire("CHAT_MSG_SKILL")
    assert(find_frame("You can learn Journeyman Fishing now."), "toast shown")
    ns.db.settings.toasts = true
    eq(count("You can learn Journeyman Fishing now."), 1, "notice")
    assert(chat_contains("Any fishing trainer teaches it"), "where: the trainer sentence")
    eq(#raid_warnings, 0, "no raid warning for a quiet notice")
    assert(not chat_contains("|Hworldmap:"), "no map link for a trainer")
end)

test("the quiet notice comes once per session", function()
    fishing_skill = { 51, 75 }
    fire("SKILL_LINES_CHANGED")
    ns.Fire("MODE_CHANGED", true)
    eq(count("You can learn Journeyman Fishing now."), 1, "still one")
end)

test("at the cap: the raid warning once, then a chat line on entering fishing mode", function()
    fishing_skill = { 75, 75 }
    fire("SKILL_LINES_CHANGED")
    eq(Skill.GetNextRank().state, "cap", "state")
    eq(count("Fishing skill capped (75/75): learn Journeyman Fishing to go on."), 1, "cap notice")
    eq(#raid_warnings, 1, "raid warning")
    fire("SKILL_LINES_CHANGED")
    eq(count("Fishing skill capped (75/75)"), 1, "not repeated by skill events")
    ns.Fire("MODE_CHANGED", true)
    eq(count("Fishing skill capped (75/75)"), 2, "repeated as a chat line on entering fishing mode")
    eq(#raid_warnings, 1, "no second raid warning")
    ns.Fire("MODE_CHANGED", false)
    eq(count("Fishing skill capped (75/75)"), 2, "not on leaving fishing mode")
end)

test("Expert waits for character level 20", function()
    player_level = 15
    fishing_skill = { 125, 150 }
    fire("SKILL_LINES_CHANGED")
    local advice = Skill.GetNextRank()
    eq(advice.state, "level", "state")
    eq(advice.level, 20, "level needed")
    eq(count("You can learn Expert Fishing now."), 0, "no notice before the level")
    player_level = 19
    fire("PLAYER_LEVEL_UP", 20) -- UnitLevel still says 19 while the event runs, as in the game
    player_level = 20
    advance(1)
    eq(count("You can learn Expert Fishing now."), 1, "notice after the level-up")
end)

test("the book advice uses English names until the client has its own", function()
    local advice = Skill.GetNextRank()
    eq(advice.where, 'Buy the book "Expert Fishing - The Bass and You" from Old Man Heming in Booty Bay, '
        .. "Stranglethorn Vale.", "where")
    eq(advice.sources.item, "english", "book name source")
    eq(advice.sources.area, "english", "area name source")
    eq(advice.pin, nil, "no pin: the client knows none of the candidate maps")
    assert(not chat_contains("|Hworldmap:"), "no map link without a pin target")
end)

test("NPC names without a tooltip: the client language in the table, then English", function()
    local saved = ns.NpcNames[2626].deDE
    ns.NpcNames[2626].deDE = "Heming (table)"
    CLIENT_LOCALE = "deDE"
    eq(Skill.GetNextRank().sources.npc, "table", "from the table")
    assert(Skill.GetNextRank().where:find("from Heming (table) in", 1, true), "table name in the sentence")
    CLIENT_LOCALE = "xxXX"
    eq(Skill.GetNextRank().sources.npc, "english", "English for a client language the table lacks")
    assert(Skill.GetNextRank().where:find("from Old Man Heming in", 1, true), "English name in the sentence")
    CLIENT_LOCALE = "enUS"
    ns.NpcNames[2626].deDE = saved
end)

test("names come from the client when it has them", function()
    unknown_items[16083] = nil
    item_names[16083] = "Angeln fuer Experten"
    area_names[35], area_names[33] = "Beutebucht", "Schlingendorntal"
    tooltip_names[2626] = "Heming (tooltip)"
    local advice = Skill.GetNextRank()
    eq(advice.where, 'Buy the book "Angeln fuer Experten" from Heming (tooltip) in Beutebucht, Schlingendorntal.',
        "where")
    eq(advice.sources.item, "game", "book")
    eq(advice.sources.npc, "game", "seller from the tooltip")
    eq(advice.sources.area, "game", "sub-zone")
    eq(advice.sources.zone, "game", "zone")
    tooltip_names[2626] = nil
    eq(Skill.GetNextRank().sources.npc, "game", "the tooltip name is kept once the client gave it")
end)

test("the rank name comes from the spell subtext when the client has it", function()
    spell_subtexts[7732] = "Experte"
    eq(Skill.GetNextRank().rank, "Experte", "next rank")
    spell_subtexts[7731] = "Geselle"
    eq(Skill.GetRankName(150), "Geselle", "rank name of a cap")
    spell_subtexts[7731], spell_subtexts[7732] = nil, nil
    eq(Skill.GetRankName(75), "Apprentice", "fallback")
end)

test("Artisan at 225: only the cap notice, with the level and a map link", function()
    waypoint_maps[1445] = true
    player_level = 30
    fishing_skill = { 225, 225 }
    fire("SKILL_LINES_CHANGED")
    local advice = Skill.GetNextRank()
    eq(advice.state, "cap", "state")
    eq(advice.where, 'Do the quest "Nat Pagle, Angler Extreme" from Nat Pagle at Tidefury Cove, Dustwallow Marsh.',
        "where")
    eq(count("You can learn Artisan Fishing now."), 0, "no can-learn notice at the same time")
    eq(count("Fishing skill capped (225/225): learn Artisan Fishing to go on."), 1, "cap notice")
    assert(chat_contains("Artisan Fishing needs character level 35."), "the level needed")
    assert(chat_contains("|Hworldmap:1445:5860:6020|h"), "map link to Nat Pagle")
    eq(#raid_warnings, 2, "the second cap's raid warning")
    assert(raid_warnings[2]:find("needs character level 35", 1, true), "the raid warning names the level")
    eq(advice.pin.mapID, 1445, "pin map")
end)

test("at the cap, reaching the level still brings the can-learn notice", function()
    player_level = 34
    fire("PLAYER_LEVEL_UP", 35) -- UnitLevel lags behind the event
    player_level = 35
    advance(1)
    eq(count("You can learn Artisan Fishing now."), 1, "notice once the level is reached")
    eq(#raid_warnings, 2, "no new raid warning")
    fire("SKILL_LINES_CHANGED")
    eq(count("You can learn Artisan Fishing now."), 1, "only once")
end)

test("the quest title comes from the client when it has it", function()
    quest_titles[6607] = "Nat Pagle, Extremangler"
    local advice = Skill.GetNextRank()
    assert(advice.where:find('"Nat Pagle, Extremangler"', 1, true), advice.where)
    eq(advice.sources.quest, "game", "quest source")
end)

test("at 300 and without Fishing there is no next rank", function()
    fishing_skill = { 300, 300 }
    eq(Skill.GetNextRank(), nil, "300")
    fishing_skill = nil
    eq(Skill.GetNextRank(), nil, "not learned")
end)
