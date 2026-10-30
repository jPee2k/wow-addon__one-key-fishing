-- Share.lua: the exchange protocol between several nodes (Share.NewNode) over a fake network in this file, with
-- guild, group, whisper and Battle.net paths (contracts/sync-protocol.md). The addon is loaded for ns (CatchDB,
-- the store); its own game node does not start (the notice is never closed), so only the test nodes talk.

load_addon()
math.randomseed(7)

local Share = ns.Share
local Store = Share.Store
local FISH = 6291

local net -- { nodes = name -> info, cut = { ["A>B"] = true }, delay, log = { { from, to, text } } }

local function NewNet()
    net = { nodes = {}, cut = {}, delay = 0.1, log = {} }
end

local function Find(address)
    local kind, target = address:match("^([wb]):(.+)$")
    for _, info in pairs(net.nodes) do
        if (kind == "w" and info.name == target) or (kind == "b" and tostring(info.bnet) == target) then
            return info, kind
        end
    end
end

local function Deliver(from, to, fromAddress, via, text)
    table.insert(net.log, { from = from.name, to = to.name, text = text })
    if net.cut[from.name .. ">" .. to.name] or from.down or to.down then
        return
    end
    C_Timer.After(net.delay, function() to.node:Receive(fromAddress, via, text) end)
end

-- An own record of `catches` catches and a miss at `key`, at the seq its casting needs (CatchDB.STEP_SECONDS).
local function OwnRecord(id, key, catches)
    local cell = catch_cell(catches, 1, { [FISH] = { catches, catches } })
    return prove({ id = id, epoch = 0, seq = math.max(1, math.ceil(cell.t / ns.CatchDB.STEP_SECONDS)),
        builds = { ["1.60.1"] = { [key] = cell } } })
end

-- A node named `name` with its own record of `catches` at place `key`. opts: guild, group (names of the shared
-- guild / group), bnet (its game account ID), friends (addresses it greets), random (the node's math.random).
-- A test sets info.overBudget (canSend false) or info.room (the largest message canSend lets out).
local function NewNode(name, id, opts)
    opts = opts or {}
    local info = { name = name, bnet = opts.bnet, guild = opts.guild, group = opts.group,
        friends = opts.friends or {} }
    local own = OwnRecord(id, opts.key or "1415:3:47", opts.catches or 10)
    local store = { myID = id, mine = {}, records = { [id] = own } }
    info.store = store
    info.node = Share.NewNode(store, {
        now = GetTime,
        time = GetTime,
        after = function(delay, fn) C_Timer.After(delay, fn) end,
        send = function(address, text)
            local to, kind = Find(address)
            if to then
                Deliver(info, to, kind == "w" and ("w:" .. name) or ("b:" .. tostring(info.bnet)),
                    kind == "w" and "whisper" or "bnet", text)
            end
        end,
        broadcast = function(text)
            for _, other in pairs(net.nodes) do
                if info.guild and other.guild == info.guild then
                    Deliver(info, other, "w:" .. name, "guild", text) -- the sender hears its own echo too
                end
                if info.group and other.group == info.group then
                    Deliver(info, other, "w:" .. name, "group", text)
                end
            end
        end,
        forEachFriend = function(fn)
            for _, address in ipairs(info.friends) do
                fn(address)
            end
        end,
        canSend = function(bytes) return not info.overBudget and (bytes or 0) <= (info.room or math.huge) end,
        absorbed = function() return info.absorbed or {} end,
        seedEpoch = function() return 0 end,
        encode = Share.Encode,
        decode = Share.Decode,
        random = opts.random,
    })
    net.nodes[name] = info
    return info
end

-- Every node greets, then the clock runs `minutes` in steps of a round (10 minutes).
local function Rounds(count)
    for _ = 1, count do
        for _, info in pairs(net.nodes) do
            info.node:Hello()
        end
        advance(600)
    end
end

local function UnitsText(info)
    local units, lines = Store.Units(info.store, {}), {}
    for unit, seq in pairs(units) do
        table.insert(lines, unit .. "=" .. seq)
    end
    table.sort(lines)
    return table.concat(lines, " ")
end

local function Catches(info)
    local total = 0
    for unit in pairs(Store.Units(info.store, {})) do
        for _, cells in pairs(Store.Get(info.store, unit).builds) do
            for _, cell in pairs(cells) do
                total = total + cell.c
            end
        end
    end
    return total
end

local function Count(prefix, from, to)
    local count = 0
    for _, entry in ipairs(net.log) do
        if entry.text:sub(1, #prefix) == prefix and (not from or entry.from == from) and (not to or entry.to == to) then
            count = count + 1
        end
    end
    return count
end

local A_ID, B_ID, C_ID = "aaaaaaaa", "bbbbbbbb", "cccccccc"

test("three nodes joined by guild, group and Battle.net end with the same records and counts", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g", bnet = 1, friends = { "b:3" }, catches = 10 })
    local b = NewNode("B", B_ID, { guild = "g", group = "p", catches = 20, key = "1415:3:48" })
    local c = NewNode("C", C_ID, { group = "p", bnet = 3, friends = { "b:1" }, catches = 30, key = "1416:3:x" })
    Rounds(12)
    local expected = UnitsText(a)
    eq(UnitsText(b), expected, "B holds what A holds")
    eq(UnitsText(c), expected, "C holds what A holds")
    for _, info in ipairs({ a, b, c }) do
        eq(Catches(info), 60, info.name .. " counts every catch once")
    end
end)

test("data spreads further than the people one meets: C's record reaches B through A, stored once", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g", group = "p" })
    local b = NewNode("B", B_ID, { guild = "g" })
    NewNode("C", C_ID, { group = "p" })
    Rounds(12)
    assert(b.store.records[C_ID .. "@0"], "B has C's record")
    local count = 0
    for key in pairs(b.store.records) do
        if key:find(C_ID, 1, true) then
            count = count + 1
        end
    end
    eq(count, 1, "once")
    eq(Catches(b), Catches(a), "the same counts")
end)

test("equal databases start no session; one differing bucket sends only its units", function()
    -- Continues the network of the last test, which converged.
    local sums = Count("S")
    Rounds(1)
    eq(Count("S"), sums, "no SUM after equal HELLOs")
    local a = net.nodes.A
    local own = a.store.records[A_ID]
    own.builds["1.60.1"]["1415:3:47"].c = 11
    own.builds["1.60.1"]["1415:3:47"].t = 120
    own.seq = 2
    prove(own)
    local diffs = #net.log
    Rounds(4)
    local found = false
    for i = diffs + 1, #net.log do
        local bucket = net.log[i].text:match("^D%w%w (%S+)")
        if bucket then
            found = true
            eq(bucket, "a", "only bucket a differs")
        end
    end
    assert(found, "a DIFF was sent")
    eq(net.nodes.B.store.records[A_ID .. "@0"].seq, 2, "B got the new version")
end)

test("a second hearer gets BYE busy while the node is in a session", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g" })
    NewNode("C", C_ID, { guild = "g" })
    a.node:Receive("w:X", "guild", sum_text("xx"))
    eq(a.node.session.peer, "w:X", "in a session with X")
    a.node:Receive("w:C", "guild", sum_text("yy"))
    advance(1)
    local last = net.log[#net.log]
    eq(last.to, "C", "answered C")
    eq(last.text, "Byy busy", "busy")
    eq(a.node.session.peer, "w:X", "still with X")
end)

test("cooldowns: 2 min between session starts, 10 min with a group peer, 30 min otherwise", function()
    NewNet()
    local a = NewNode("A", A_ID)
    local node = a.node
    local groupPeer = node:Peer("w:G", "group")
    local guildPeer = node:Peer("w:H", "guild")
    local t = GetTime()
    eq(node:CanStart(groupPeer, t), true, "free")
    node.lastStart = t
    eq(node:CanStart(guildPeer, t + 119), false, "within 2 min of the last start")
    eq(node:CanStart(guildPeer, t + 121), true, "after 2 min")
    groupPeer.lastSession, guildPeer.lastSession = t, t
    eq(node:CanStart(groupPeer, t + 599), false, "group peer within 10 min")
    eq(node:CanStart(groupPeer, t + 601), true, "group peer after 10 min")
    eq(node:CanStart(guildPeer, t + 1799), false, "guild peer within 30 min")
    eq(node:CanStart(guildPeer, t + 1801), true, "guild peer after 30 min")
end)

-- A record of `places` cells, about 85 encoded bytes per cell.
local function BigRecord(id, places)
    local cells = {}
    for i = 1, places do
        cells[(4000 + i) .. ":2:x"] = catch_cell(3, 1, { [FISH] = { 3, 3 } })
    end
    return prove({ id = id, epoch = 0, seq = math.ceil(places * cells["4001:2:x"].t / ns.CatchDB.STEP_SECONDS),
        builds = { ["1.60.1"] = cells } }, nil, 4096)
end

test("more than 8 KB of wanted records is split over two sessions; one record over 8 KB still goes", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    for _, id in ipairs({ "dddddddd", "eeeeeeee", "ffffffff", "gggggggg" }) do
        eq(Store.Accept(a.store, BigRecord(id, 40), GetTime(), {}), "new", id)
    end
    local size = #Share.Encode(Store.ForSending(a.store.records["dddddddd@0"]))
    assert(size > 2800 and size < 4000, "a record encodes to about 3 KB: " .. size)
    Rounds(1)
    local held = 0
    for key in pairs(b.store.records) do
        held = held + (key:find("@", 1, true) and 1 or 0)
    end
    assert(held >= 2 and held < 5, "the first session within 8 KB: " .. held)
    Rounds(2)
    eq(UnitsText(b), UnitsText(a), "the rest in a later session")
    NewNet()
    local c = NewNode("C", C_ID, { group = "q" })
    local d = NewNode("D", "dddddddd", { group = "q" })
    eq(Store.Accept(c.store, BigRecord("hhhhhhhh", 120), GetTime(), {}), "new", "big record")
    assert(#Share.Encode(Store.ForSending(c.store.records["hhhhhhhh@0"])) > 8 * 1024, "over 8 KB")
    Rounds(3) -- the first session carries C's own record, the big one comes alone in the next
    assert(d.store.records["hhhhhhhh@0"], "sent anyway")
end)

test("no reply for 15 s drops the session and pauses the peer for 30 min", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g" })
    local b = NewNode("B", B_ID, { guild = "g" })
    net.cut["B>A"] = true
    a.node:Hello()
    advance(25)
    eq(b.node.session and b.node.session.role, "initiator", "B started")
    advance(16)
    eq(b.node.session, nil, "dropped")
    local peer = b.node.peers["w:A"]
    assert(peer.pausedUntil and peer.pausedUntil >= GetTime() + 1700, "paused for 30 min")
    eq(b.node:CanStart(peer, GetTime()), false, "no new session with A")
end)

local function SessionWith(a, from)
    a.node:Receive(from, "group", sum_text("xx"))
    return a.node.session
end

test("a REC that was not wanted, or that fails the check, makes the sender ignored", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local data = Share.Encode(Store.ForSending(OwnRecord("kkkkkkkk", "1415:3:47", 5)))
    eq(SessionWith(a, "w:X").peer, "w:X", "responder")
    a.node:Receive("w:X", "group", "Rxx " .. data)
    advance(1)
    eq(a.node.peers["w:X"].ignored, true, "unwanted record")
    eq(a.node.session, nil, "session ended")
    eq(a.store.records["kkkkkkkk@0"], nil, "not stored")
    a.node:Receive("w:X", "group", "H qqqq 0 1 aaaaaaa")
    eq(a.node.peers["w:X"].heard, nil, "ignored until logout")

    local bad = OwnRecord("mmmmmmmm", "1415:3:47", 5)
    bad.builds["1.60.1"]["1415:3:47"].c = 999
    SessionWith(a, "w:Y")
    a.node:Receive("w:Y", "group", "Dxx m mmmmmmmm.0.1")
    a.node:Receive("w:Y", "group", "Wxx")
    eq(a.node.session.ourWants["mmmmmmmm@0"], 1, "A wants it")
    a.node:Receive("w:Y", "group", "Rxx " .. Share.Encode(Store.ForSending(bad)))
    advance(1)
    eq(a.node.peers["w:Y"].ignored, true, "a record that fails the check")
    eq(a.store.records["mmmmmmmm@0"], nil, "not stored")
end)

test("flood limits: 1 HELLO per 60 s, the hourly messages and records, no more records than wanted",
    function()
    NewNet()
    local a = NewNode("A", A_ID)
    a.node:Receive("w:P", "guild", "H pppp 0 1 aaaaaaa")
    local heard = a.node.peers["w:P"].heard
    advance(30)
    a.node:Receive("w:P", "guild", "H pppp 0 2 aaaaaab")
    eq(a.node.peers["w:P"].heard, heard, "a second HELLO within 60 s is ignored")
    eq(a.node.peers["w:P"].ignored, nil, "but the sender is not ignored for it")
    for _ = 1, Share.MESSAGE_LIMIT do
        a.node:Receive("w:Q", "guild", "Bzz done")
    end
    eq(a.node.peers["w:Q"].ignored, nil, "up to the limit")
    a.node:Receive("w:Q", "guild", "Bzz done")
    eq(a.node.peers["w:Q"].ignored, true, "one message over the limit in an hour")
    for i = 1, 51 do
        a.node:Receive("w:R", "guild", "Rzz " .. ("A"):rep(4) .. i)
    end
    eq(a.node.peers["w:R"].ignored, nil, "records outside a session are dropped before counting")
    a = NewNode("A2", B_ID) -- A is busy with P by now
    SessionWith(a, "w:S")
    a.node:Receive("w:S", "group", "Dxx k kkkkkkkk.0.1")
    a.node:Receive("w:S", "group", "Wxx")
    eq(a.node.session.wantCount, 1, "one record wanted")
    a.node:Receive("w:S", "group", "Rxx AAAA")
    eq(a.node.peers["w:S"].ignored, nil, "the wanted one is taken")
    a.node:Receive("w:S", "group", "Rxx AAAA")
    eq(a.node.peers["w:S"].ignored, true, "a second record in a session that wanted one")
    a = NewNode("A3", C_ID)
    SessionWith(a, "w:T")
    a.node.session.wantCount = 1000
    for _ = 1, Share.RECORD_LIMIT + 1 do
        a.node:Receive("w:T", "group", "Rxx AAAA")
    end
    eq(a.node.peers["w:T"].ignored, true, "one record over the limit in an hour")
end)

test("the hourly limits are above what one honest client can send to one peer", function()
    eq(Share.RECORD_LIMIT, 175, "25 records in each of 7 sessions (one per 10 minutes, plus the edges of the hour)")
    eq(Share.MESSAGE_LIMIT, 1160, "twice the budget's 214 units plus 366 messages")
    assert(Share.MESSAGE_LIMIT < 20 * 60, "one message per second is still caught within 20 minutes")
    NewNet()
    local a = NewNode("A", A_ID)
    -- The worst honest hour: the whole 50 KB budget in records of about 2 KB (9 units each) and every other
    -- message at its most: 126 HELLOs, 35 session messages, 30 BYE busy and the rest of the 175 records.
    for _ = 1, 25 do
        a.node:Receive("w:P", "group", "Rzz " .. ("A"):rep(2000))
    end
    for _ = 1, 126 + 35 + 30 + 150 do
        a.node:Receive("w:P", "group", "Bzz done")
    end
    eq(a.node.peers["w:P"].ignored, nil, "not ignored")
end)

test("a peer that sends SUMs faster than the cooldowns gets one DIFF, then BYE busy", function()
    NewNet()
    local a = NewNode("A", A_ID)
    NewNode("X", "xxxxxxxx")
    local function Sent(prefix)
        local count = 0
        for _, entry in ipairs(net.log) do
            if entry.from == "A" and entry.to == "X" and entry.text:sub(1, #prefix) == prefix then
                count = count + 1
            end
        end
        return count
    end
    for i = 1, 12 do
        a.node:Receive("w:X", "group", sum_text(ns.Base32(i, 2)))
        advance(5)
        a.node:DropSession() -- whatever the last one left, the next SUM is a new session
    end
    eq(Sent("D"), 1, "one DIFF")
    eq(Sent("B"), 11, "the rest BYE busy")
    advance(8 * 60)
    a.node:Receive("w:X", "group", sum_text("zz"))
    eq(Sent("D"), 2, "answered again 8 minutes after the last DIFF")
end)

test("a sender sends at most 25 records per session, so an honest peer stays within the receiver's limits",
    function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    for i = 1, 40 do
        local id = ns.Base32(20000 + i, 8)
        eq(Store.Accept(a.store, OwnRecord(id, "1415:3:47", 1), GetTime(), {}), "new", id)
    end
    Rounds(1)
    local held = 0
    for key in pairs(b.store.records) do
        held = held + (key:find("@", 1, true) and 1 or 0)
    end
    eq(held, 25, "the first session carries 25")
    eq(a.node.peers["w:B"].ignored, nil, "B is not ignored")
    eq(b.node.peers["w:A"].ignored, nil, "A is not ignored")
    Rounds(2)
    eq(UnitsText(b), UnitsText(a), "the rest in the next session")
end)

test("the own record goes without builds a peer would refuse, and not at all when it would be refused", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    a.store.records[A_ID].builds.unknown = { ["1416:3:x"] = catch_cell(2, 0) }
    Rounds(2)
    local got = b.store.records[A_ID .. "@0"]
    assert(got, "A's record reached B")
    eq(got.builds.unknown, nil, "without the build the game gave no version for")
    eq(b.node.peers["w:A"].ignored, nil, "A is not ignored")

    NewNet()
    local c = NewNode("C", C_ID, { group = "q" })
    local d = NewNode("D", "dddddddd", { group = "q" })
    eq(Store.Accept(c.store, OwnRecord("eeeeeeee", "1415:3:47", 3), GetTime(), {}), "new", "a relayed record")
    local cells = c.store.records[C_ID].builds["1.60.1"]
    for i = 1, 1001 do
        cells[(8000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    Rounds(2)
    eq(d.store.records[C_ID .. "@0"], nil, "a record over 1000 places is not sent")
    assert(d.store.records["eeeeeeee@0"], "the rest still goes")
    eq(d.node.peers["w:C"].ignored, nil, "C is not ignored")
end)

test("a DIFF with nothing but spaces is ignored without an error", function()
    NewNet()
    local a = NewNode("A", A_ID)
    SessionWith(a, "w:X")
    a.node:Receive("w:X", "group", "Dxx  ")
    a.node:Receive("w:X", "group", "Dxx")
    eq(a.node.session.gotDiff, nil, "not taken as a DIFF")
end)

test("a pause drops the records that wait for their merge", function()
    NewNet()
    local a = NewNode("A", A_ID)
    SessionWith(a, "w:X")
    a.node:Receive("w:X", "group", "Dxx k kkkkkkkk.0.1")
    a.node:Receive("w:X", "group", "Wxx")
    a.node:Receive("w:X", "group", "Rxx " .. Share.Encode(Store.ForSending(OwnRecord("kkkkkkkk", "1415:3:47", 5))))
    eq(#a.node.merges, 1, "queued")
    a.node:Pause("off")
    advance(1)
    eq(a.store.records["kkkkkkkk@0"], nil, "not stored")
    a.node:Resume()
end)

test("a node ignores its own HELLO echo, and HELLO never carries the anonymous ID", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g" })
    a.node:Hello()
    advance(1)
    eq(net.log[1].to, "A", "the echo came back")
    eq(a.node.peers["w:A"] and a.node.peers["w:A"].heard, nil, "not a peer")
    assert(not net.log[1].text:find(A_ID, 1, true), "no ID in HELLO: " .. net.log[1].text)
end)

test("received records are merged one per frame step", function()
    NewNet()
    local a = NewNode("A", A_ID)
    SessionWith(a, "w:X")
    local ids = { "kkkkkkkk", "llllllll", "nnnnnnnn" }
    local entries = {}
    for _, id in ipairs(ids) do
        table.insert(entries, id .. ".0.1")
    end
    a.node:Receive("w:X", "group", "Dxx kln " .. table.concat(entries, " "))
    a.node:Receive("w:X", "group", "Wxx")
    for _, id in ipairs(ids) do
        a.node:Receive("w:X", "group", "Rxx " .. Share.Encode(Store.ForSending(OwnRecord(id, "1415:3:47", 5))))
    end
    eq(#a.node.merges, 3, "queued")
    -- Run only the timer that is due now: one frame step.
    for i, timer in ipairs(timers) do
        if timer.at <= GetTime() then
            table.remove(timers, i).fn()
            break
        end
    end
    eq(#a.node.merges, 2, "one merged")
    advance(0)
    eq(#a.node.merges, 0, "the rest on the next steps")
    for _, id in ipairs(ids) do
        assert(a.store.records[id .. "@0"], id)
    end
end)

test("a pause mid-session sends nothing more; the peer times out", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    net.delay = 5
    a.node:Hello()
    advance(25)
    assert(b.node.session, "B started")
    a.node:Pause("combat")
    local sent = #net.log
    advance(30)
    for i = sent + 1, #net.log do
        assert(net.log[i].from ~= "A", "A sent " .. net.log[i].text)
    end
    eq(b.node.session, nil, "B timed out")
    a.node:Resume()
end)

test("crossing SUMs: the smaller node tag leads; equal tags both give way and converge later", function()
    -- Both start 2 s after the other's HELLO, so their SUMs cross.
    local function random(...)
        local low, high = ...
        if low == 2 and high == 20 then
            return 2
        end
        return math.random(...)
    end
    NewNet()
    local a = NewNode("A", A_ID, { group = "p", random = random })
    local b = NewNode("B", B_ID, { group = "p", random = random })
    a.node.tag, b.node.tag = "aaaa", "bbbb"
    net.delay = 6 -- both start 2 s after hearing the other, before its SUM arrives (a round trip < 15 s)
    a.node:Hello()
    b.node:Hello()
    advance(10)
    eq(a.node.session and a.node.session.role, "initiator", "A initiator")
    eq(b.node.session and b.node.session.role, "initiator", "B initiator")
    advance(6)
    eq(a.node.session and a.node.session.role, "initiator", "A (smaller tag) still leads")
    eq(b.node.session and b.node.session.role, "responder", "B answers")
    advance(600)
    eq(UnitsText(a), UnitsText(b), "converged")

    NewNet()
    a = NewNode("A", A_ID, { group = "p", random = random })
    b = NewNode("B", B_ID, { group = "p", random = random })
    a.node.tag, b.node.tag = "aaaa", "bbbb"
    net.delay = 6
    a.node:Hello()
    b.node:Hello()
    advance(10)
    a.node.tag, b.node.tag = "cccc", "cccc"
    b.node.peers["w:A"].node, a.node.peers["w:B"].node = "cccc", "cccc"
    advance(6)
    eq(a.node.session, nil, "A gave way")
    eq(b.node.session, nil, "B gave way")
    a.node.tag, b.node.tag = "aaaa", "bbbb"
    net.delay = 0.1
    advance(1200)
    Rounds(2)
    eq(UnitsText(a), UnitsText(b), "converged after the next HELLO")
end)

test("friend rotation: known peers first, then 18 others per round from a cursor", function()
    NewNet()
    local a = NewNode("A", A_ID)
    for i = 1, 50 do
        table.insert(a.friends, "w:F" .. i)
    end
    a.node:Receive("w:F7", "whisper", "H ffff 0 1 aaaaaaa")
    a.node:Receive("w:F9", "whisper", "H gggg 0 1 aaaaaaa")
    local greeted = {}
    local send = a.node.env.send
    a.node.env.send = function(address, text)
        if text:sub(1, 1) == "H" then
            greeted[address] = (greeted[address] or 0) + 1
            table.insert(greeted, address)
        end
        send(address, text)
    end
    a.node:Hello()
    eq(#greeted, 20, "20 per round")
    eq(greeted[1], "w:F7", "known peers first")
    eq(greeted[2], "w:F9", "known peers first")
    a.node:Hello()
    a.node:Hello()
    for i = 1, 50 do
        assert(greeted["w:F" .. i], "F" .. i .. " greeted within 3 rounds")
    end
    a.node.env.send = send
end)

test("records evicted for the size limit are not wanted back, unless a newer version comes", function()
    NewNet()
    local a = NewNode("A", A_ID)
    eq(Store.Accept(a.store, OwnRecord("kkkkkkkk", "1415:3:47", 2), 1, {}), "new", "stored")
    local cells = a.store.records["kkkkkkkk@0"].builds["1.60.1"]
    for i = 1, 20001 do
        cells[(30000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    eq(Store.Evict(a.store), 1, "evicted")
    eq(a.node:Wanted("kkkkkkkk@0", 1), false, "the evicted version is not wanted back")
    eq(a.node:Wanted("kkkkkkkk@0", 2), true, "a newer one is")
end)

test("an own record with cells only under a build without a game version is not offered", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    local own = a.store.records[A_ID]
    own.builds = { unknown = own.builds["1.60.1"] }
    eq(Store.Units(a.store, {})[A_ID .. "@0"], nil, "not among the units")
    eq(a.node:Summary().units[A_ID .. "@0"], nil, "not in the summary")
    local data, problem = a.node:OwnData(own)
    eq(data, false, "nothing to send")
    eq(problem, "no cells to send", "the reason")
    Rounds(2)
    eq(b.store.records[A_ID .. "@0"], nil, "B got no empty record")
end)

test("an own record a peer would refuse is not offered, so the hashes can still match", function()
    NewNet()
    local a = NewNode("A", A_ID)
    local cells = a.store.records[A_ID].builds["1.60.1"]
    for i = 1, 1001 do
        cells[(8000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    eq(a.node:Summary().units[A_ID .. "@0"], nil, "not offered")
end)

test("a guild member who is also in the group gets the group's cooldown", function()
    NewNet()
    local a = NewNode("A", A_ID)
    a.node:Receive("w:G", "guild", "H gggg 0 1 aaaaaaa")
    a.node:Receive("w:G", "group", "H gggg 0 1 aaaaaaa")
    eq(a.node.peers["w:G"].via, "group", "group")
end)

test("a record whose merge raises an error ignores its sender and the next merges still run", function()
    NewNet()
    local a = NewNode("A", A_ID)
    SessionWith(a, "w:X")
    a.node:Receive("w:X", "group", "Dxx kl kkkkkkkk.0.1 llllllll.0.1")
    a.node:Receive("w:X", "group", "Wxx")
    local decode = a.node.env.decode
    a.node.env.decode = function(text)
        if text == "AAAA" then
            error("broken data")
        end
        return decode(text)
    end
    a.node:Receive("w:X", "group", "Rxx AAAA")
    advance(1)
    eq(a.node.peers["w:X"].ignored, true, "ignored")
    a.node.env.decode = decode
    local b = NewNode("B", B_ID)
    SessionWith(b, "w:Y")
    b.node:Receive("w:Y", "group", "Dxx l llllllll.0.1")
    b.node:Receive("w:Y", "group", "Wxx")
    b.node:Receive("w:Y", "group", "Rxx " .. Share.Encode(Store.ForSending(OwnRecord("llllllll", "1415:3:47", 5))))
    advance(1)
    assert(b.store.records["llllllll@0"], "merges go on")
end)

test("an own record over 32 KB encoded is not offered either", function()
    NewNet()
    local a = NewNode("A", A_ID)
    local encode = a.node.env.encode
    a.node.env.encode = function(record)
        local text = encode(record)
        return record.id == A_ID and text .. ("A"):rep(33 * 1024) or text
    end
    eq(a.node:Summary().units[A_ID .. "@0"], nil, "not offered")
end)

test("a session that moved nothing is not repeated while both hashes stay the same", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    b.absorbed = { [A_ID] = { [0] = 1 } } -- B's seed already holds A's record: A offers it, B never wants it
    Rounds(3)
    local sums = Count("S")
    Rounds(6)
    eq(Count("S"), sums, "no more sessions that move nothing")
    a.store.records[A_ID].seq = 9
    prove(a.store.records[A_ID])
    Rounds(3)
    assert(Count("S") > sums, "a change starts sessions again")
end)

test("a record with an item this client does not know is kept and passed on, its sender not blamed (FR-017a)",
    function()
    NewNet()
    local a = NewNode("A", A_ID)
    SessionWith(a, "w:X")
    a.node:Receive("w:X", "group", "Dxx k kkkkkkkk.0.1")
    a.node:Receive("w:X", "group", "Wxx")
    unknown_items[FISH] = true
    a.node:Receive("w:X", "group", "Rxx " .. Share.Encode(Store.ForSending(OwnRecord("kkkkkkkk", "1415:3:47", 5))))
    advance(1)
    unknown_items[FISH] = nil
    eq(a.store.records["kkkkkkkk@0"].seq, 1, "stored")
    eq(a.node.peers["w:X"].ignored, nil, "not ignored")
    eq(a.node.unknownItems, nil, "no unknown-item rule any more")
end)

test("a peer that timed out is free again once it greets", function()
    NewNet()
    local a = NewNode("A", A_ID)
    local peer = a.node:Peer("w:P", "guild")
    peer.pausedUntil = GetTime() + 1800
    a.node:Receive("w:P", "guild", "H pppp 0 1 aaaaaaa")
    eq(peer.pausedUntil, nil, "back")
end)

test("a DIFF that would not fit the budget whole ends the session with BYE limit", function()
    NewNet()
    local a = NewNode("A", A_ID)
    NewNode("X", "xxxxxxxx")
    a.node.env.canSend = function(bytes) return (bytes or 0) < 40 end -- the DIFF is 49 bytes
    SessionWith(a, "w:X")
    eq(a.node.session, nil, "ended")
    advance(1)
    eq(net.log[#net.log].text, "Bxx limit", "told the peer")
end)

test("a record of the own ID frozen by a roll goes to peers like the live one, and not when they would refuse it",
    function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    local live = a.store.records[A_ID]
    a.store.records[A_ID .. "@0"] = live -- what CatchDB's roll leaves: the old record under <id>@<epoch>
    live.seen = 1
    a.store.records[A_ID] = OwnRecord(A_ID, "1416:3:x", 4)
    a.store.records[A_ID].epoch = 1
    Rounds(3)
    eq(b.store.records[A_ID .. "@0"].seq, 1, "the frozen record reached B")
    eq(b.store.records[A_ID .. "@1"].seq, 1, "the live one too")
    eq(b.node.peers["w:A"].ignored, nil, "A is not ignored")
    eq(UnitsText(a), UnitsText(b), "converged")

    NewNet()
    local c = NewNode("C", C_ID, { group = "q" })
    local d = NewNode("D", "dddddddd", { group = "q" })
    local big = OwnRecord(C_ID, "1415:3:47", 2)
    for i = 1, 1001 do
        big.builds["1.60.1"][(8000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    big.epoch, big.seen = 5, 1
    c.store.records[C_ID .. "@5"] = big
    eq(c.node:Summary().units[C_ID .. "@5"], nil, "over 1000 places: not offered")
    Rounds(3)
    eq(d.store.records[C_ID .. "@5"], nil, "not sent")
    eq(d.node.peers["w:C"].ignored, nil, "C is not ignored")
    eq(c.node:HashText(), d.node:HashText(), "the hashes still match")
end)

-- The BYEs and records A sent to B, in order: "limit", "sent", "done" and "R" for a record.
local function SentByA()
    local out = {}
    for _, entry in ipairs(net.log) do
        if entry.from == "A" and entry.to == "B" then
            local reason = entry.text:match("^B%w%w (%a+)$")
            if reason or entry.text:find("^R") then
                table.insert(out, reason or "R")
            end
        end
    end
    return table.concat(out, " ")
end

test("a record the budget cannot let out whole ends the records quietly, and nothing goes after the BYE", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    eq(Store.Accept(a.store, OwnRecord("eeeeeeee", "1415:3:47", 1), GetTime(), {}), "new", "a smaller relayed record")
    a.room = #a.node:OwnData(a.store.records[A_ID]) -- the own record's data fits, the message around it does not
    Rounds(1)
    assert(not SentByA():find("limit"), "no BYE limit, the records just end: " .. SentByA())
    assert(not SentByA():find("%a+ R"), "no record after a BYE: " .. SentByA())
    assert(a.store.records[B_ID .. "@0"], "B's record reached A")
    eq(b.store.records[A_ID .. "@0"], nil, "A's own record waits for budget")
    eq(b.store.records["eeeeeeee@0"], nil, "and so does the one behind it")
    eq(b.node.peers["w:A"].ignored, nil, "A is not ignored")
end)

test("a SUM the budget cannot send starts no session and burns no cooldown", function()
    local function random(...)
        local low, high = ...
        if low == 2 and high == 20 then
            return 2
        end
        return math.random(...)
    end
    NewNet()
    local a = NewNode("A", A_ID, { group = "p", random = random })
    local b = NewNode("B", B_ID, { group = "p" })
    a.room = 100 -- a HELLO fits, the 228-byte SUM does not
    a.node:Hello()
    advance(0.2)
    b.node:Hello()
    advance(5) -- A heard B at 0.3 and tried at 2.3; B heard A at 0.1 and waits 2-20 s
    eq(a.node.session, nil, "no session")
    eq(a.node.lastStart, nil, "no session start counted")
    eq(a.node.peers["w:B"].lastSession, nil, "no cooldown with B")
    assert(not SentByA():find("limit"), "no BYE limit for a session B never heard of: " .. SentByA())
    a.room = nil
    advance(600)
    eq(UnitsText(a), UnitsText(b), "converged once the budget is back")
end)

test("a relayed record damaged in the saved file is dropped, not sent: the peer does not ignore this client",
    function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p" })
    local b = NewNode("B", B_ID, { group = "p" })
    eq(Store.Accept(a.store, OwnRecord("ffffffff", "1415:3:47", 2), GetTime(), {}), "new", "stored")
    a.store.records["ffffffff@0"].builds["1.60.1"]["1415:3:47"].t = nil -- damaged since
    Rounds(2)
    eq(a.store.records["ffffffff@0"], nil, "dropped")
    eq(b.store.records["ffffffff@0"], nil, "not sent")
    eq(b.node.peers["w:A"].ignored, nil, "A is not ignored")
    eq(UnitsText(a), UnitsText(b), "the rest converged")
end)

-- A node's math.random that starts every session 2 s after the HELLO (the 2-20 s wait), random otherwise.
local function StartAt2(...)
    local low, high = ...
    if low == 2 and high == 20 then
        return 2
    end
    return math.random(...)
end

test("crossing SUMs between one client reached by two paths: the tag tells, one session, no busy", function()
    NewNet()
    local a = NewNode("A", A_ID, { guild = "g", bnet = 1, random = StartAt2 })
    local b = NewNode("B", B_ID, { guild = "g", bnet = 2, random = StartAt2 })
    a.node.tag, b.node.tag = "aaaa", "bbbb"
    net.delay = 6 -- both start 2 s after the HELLOs, before the other's SUM arrives
    local function hello(info)
        return ("H %s 0 1 %s"):format(info.node.tag, info.node:HashText())
    end
    -- A hears B by the guild first, B hears A by Battle.net first; the second path is the same client again.
    a.node:Receive("w:B", "guild", hello(b))
    a.node:Receive("b:2", "bnet", hello(b))
    b.node:Receive("b:1", "bnet", hello(a))
    b.node:Receive("w:A", "guild", hello(a))
    advance(5)
    eq(a.node.session and a.node.session.peer, "w:B", "A leads towards B's guild address")
    eq(b.node.session and b.node.session.peer, "b:1", "B leads towards A's Battle.net address")
    advance(5)
    eq(a.node.session and a.node.session.role, "initiator", "A (smaller tag) still leads")
    eq(b.node.session and b.node.session.role, "responder", "B answers, though it knows A by another address")
    advance(600)
    eq(UnitsText(a), UnitsText(b), "converged")
    local busy = 0
    for _, entry in ipairs(net.log) do
        if entry.text:find("^B%w%w busy$") then
            busy = busy + 1
        end
    end
    eq(busy, 0, "no BYE busy")
    assert(b.node.peers["b:1"].lastSession, "B keeps the cooldown on A's first address too")
    assert(b.node.peers["w:A"].lastSession, "and on the address the session ran on")
end)

test("a stranger who claims a known tag from the same kind of address cannot take over the session", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p", random = StartAt2 })
    a.node.tag = "zzzz" -- larger than X's: A would give way to X's own crossing SUM
    a.node:Receive("w:X", "group", "H xxxx 0 1 aaaaaaa")
    advance(10) -- A's SUM to X went out at 2 s
    eq(a.node.session and a.node.session.peer, "w:X", "a session with X")
    a.node:Receive("w:Z", "group", "H xxxx 0 1 aaaaaaa") -- Z claims X's tag from another whisper address
    a.node:Receive("w:Z", "whisper", "Szz " .. ("a"):rep(7 * #ns.BASE32))
    eq(a.node.session and a.node.session.peer, "w:X", "the session with X stays")
    eq(a.node.session and a.node.session.role, "initiator", "A still leads")
    eq(a.node.peers["w:Z"].node, nil, "one client has one whisper address: Z is not X")
end)

test("a session kept alive by parts alone is dropped after 5 min, and the peer is paused", function()
    NewNet()
    local a = NewNode("A", A_ID, { group = "p", random = StartAt2 })
    a.node:Receive("w:Ghost", "group", "H gggg 0 1 zzzzzzz") -- nobody answers, but parts keep coming
    advance(10) -- the SUM went out at 2 s
    assert(a.node.session, "a session with the ghost")
    a.node:Heard("w:Ghost")
    for i = 1, 36 do
        advance(10)
        a.node:Heard("w:Ghost") -- every 10 s a part: never 15 s of quiet
        if i == 24 then
            assert(a.node.session, "still running after 4 min of parts")
        end
    end
    eq(a.node.session, nil, "dropped after 5 min, however busy the peer keeps it")
    assert(a.node.peers["w:Ghost"].pausedUntil, "the ghost is paused")
end)
