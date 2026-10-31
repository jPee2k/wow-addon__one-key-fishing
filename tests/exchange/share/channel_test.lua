-- Share.lua: the protocol node in the hidden public channel (specs/004-public-channel-sync, research R5,
-- contracts/protocol.md "Announcements in the channel"): only HELLO from the channel, the chance to start, near peers
-- first, the part 2 timing kept, the busy retry, cooldowns and the peer bound. Test nodes on a fake network; the
-- addon's own game node does not start (the notice is never closed). The game node's channel rounds and
-- Share.HeardInChannel are in channel_game_test.lua.

load_addon()
math.randomseed(11)

local Share = ns.Share
local FISH = 6291

local net -- { nodes = name -> info, log = { { from, to, text, at } } }

local function NewNet()
    net = { nodes = {}, log = {} }
end

local function Deliver(from, to, via, text)
    table.insert(net.log, { from = from.name, to = to.name, text = text, at = GetTime() })
    if from.dead or to.dead then
        return
    end
    -- A slow link (info.delay) on either side makes a session last; under 7.5 s each way it never times out.
    local delay = math.max(from.delay or 0.1, to.delay or 0.1)
    C_Timer.After(delay, function() to.node:Receive("w:" .. from.name, via, text) end)
end

local function OwnRecord(id, catches)
    local cell = catch_cell(catches, 1, { [FISH] = { catches, catches } })
    return prove({ id = id, epoch = 0, seq = math.max(1, math.ceil(cell.t / ns.CatchDB.STEP_SECONDS)),
        builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })
end

-- opts: group (a group name), channel (true: in the channel), friends (addresses), random (the node's random).
local function NewNode(name, id, opts)
    opts = opts or {}
    local info = { name = name, group = opts.group, channel = opts.channel, friends = opts.friends or {} }
    local store = { myID = id, mine = {}, records = { [id] = OwnRecord(id, opts.catches or 10) } }
    info.store = store
    info.node = Share.NewNode(store, {
        now = GetTime,
        time = GetTime,
        after = function(delay, fn) C_Timer.After(delay, fn) end,
        send = function(address, text)
            local to = net.nodes[address:match("^w:(.+)$") or ""]
            if to then
                Deliver(info, to, "whisper", text)
            end
        end,
        broadcast = function(text)
            for _, other in pairs(net.nodes) do
                if info.group and other.group == info.group then
                    Deliver(info, other, "group", text)
                end
            end
        end,
        channelBroadcast = function(text)
            for _, other in pairs(net.nodes) do
                if info.channel and other.channel then
                    Deliver(info, other, "channel", text) -- the sender hears its own echo too
                end
            end
        end,
        forEachFriend = function(fn)
            for _, address in ipairs(info.friends) do
                fn(address)
            end
        end,
        canSend = function() return true end,
        absorbed = function() return {} end,
        seedEpoch = function() return 0 end,
        encode = Share.Encode,
        decode = Share.Decode,
        random = opts.random,
    })
    net.nodes[name] = info
    return info
end

-- A random whose value without arguments the test sets (the chance to start); with a range it is math.random's.
local function Dice()
    local dice = { value = 0 }
    dice.fn = function(a, b)
        if a then
            return b and math.random(a, b) or math.random(a)
        end
        return dice.value
    end
    return dice
end

local function Holds(info, id)
    return info.store.records[id .. "@0"] ~= nil
end

local function Sent(from, to, kind, since)
    local count = 0
    for _, entry in ipairs(net.log) do
        if entry.from == from and entry.to == to and entry.text:sub(1, 1) == kind and entry.at >= (since or 0) then
            count = count + 1
        end
    end
    return count
end

-- A HELLO as `info` would send it, with another hash when `other` (a stranger's database).
local function HelloText(info, other)
    local summary = info.node:Summary()
    return ("H %s 0 %d %s"):format(info.node.tag, summary.count, other and ("z"):rep(#info.node:HashText())
        or info.node:HashText())
end

local TAGS = 0
local function StrangerHello(hash)
    TAGS = TAGS + 1
    local tag = ("%04d"):format(TAGS):gsub("%d", function(d) return string.char(97 + tonumber(d)) end)
    return ("H %s 0 1 %s"):format(tag, hash)
end

---------------------------------------------------------------------------
-- Only HELLO from the channel
---------------------------------------------------------------------------
test("from the channel only a whole HELLO is handled: SUM, DIFF, WANT, RECORD and BYE are ignored", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { channel = true })
    local x = NewNode("X", "xaaaaaa2", { channel = true })
    local sum = "Sab " .. table.concat(x.node:Summary().hashTexts)
    for _, text in ipairs({ sum, "Dab xx", "Wab xx", "Rab xx", "Bab busy" }) do
        c.node:Receive("w:X", "channel", text)
    end
    advance(30)
    eq(#net.log, 0, "no answer")
    eq(c.node.session, nil, "no session")
end)

---------------------------------------------------------------------------
-- The chance to start: min(1, 2 / H)
---------------------------------------------------------------------------
test("a stranger's channel HELLO starts a session only with the chance min(1, 2 / H) (H = 1, 2, 10, 100)", function()
    for _, case in ipairs({ { 1, 0.99, true }, { 2, 0.99, true }, { 10, 0.19, true }, { 10, 0.21, false },
        { 100, 0.019, true }, { 100, 0.021, false } }) do
        local heard, value, starts = case[1], case[2], case[3]
        NewNet()
        local dice = Dice()
        local c = NewNode("C", "caaaaaa2", { channel = true, random = dice.fn })
        local same = c.node:HashText()
        for i = 1, heard - 1 do
            c.node:Receive("w:Same" .. i, "channel", StrangerHello(same)) -- the same database: counted, no session
        end
        dice.value = value
        c.node:Receive("w:Stranger", "channel", StrangerHello(("z"):rep(#same)))
        local peer = c.node.peers["w:Stranger"]
        eq(peer.starting == true, starts, ("H = %d, random %.3f"):format(heard, value))
    end
end)

---------------------------------------------------------------------------
-- Near peers first
---------------------------------------------------------------------------
test("no channel session while a near peer could start one now; one in its cooldown does not block", function()
    NewNet()
    local dice = Dice()
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = dice.fn })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 20 })
    g.node:Hello() -- C hears it and starts a session with G
    advance(0.5)
    local stranger = StrangerHello(("z"):rep(#c.node:HashText()))
    c.node:Receive("w:Stranger", "channel", stranger)
    eq(c.node.peers["w:Stranger"].starting, nil, "the group peer comes first")
    advance(60)
    eq(Holds(c, "gaaaaaa2"), true, "the group session ran")
    advance(130) -- past the gap between session starts; G is in its 10 min cooldown now
    c.node:Receive("w:Stranger2", "channel", StrangerHello(("y"):rep(#c.node:HashText())))
    eq(c.node.peers["w:Stranger2"].starting, true, "a near peer in its cooldown does not block")
end)

test("a near peer nothing will start a session with (no start armed, none waited for) does not block", function()
    NewNet()
    local dice = Dice()
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = dice.fn })
    local g = c.node:Peer("w:G", "group") -- as after its second BYE busy: free to start, but nothing will
    g.heard, g.hash = GetTime(), ("x"):rep(#c.node:HashText())
    c.node:Receive("w:Stranger", "channel", StrangerHello(("z"):rep(#c.node:HashText())))
    eq(c.node.peers["w:Stranger"].starting, true, "the channel session is not held back")
end)

---------------------------------------------------------------------------
-- The part 2 timing kept (FR-007, SC-009)
---------------------------------------------------------------------------
-- C and the slow channel peer X (6 s each way), and the group peer G. C starts a session with X first.
local function ChannelSessionRunning()
    NewNet()
    local dice = Dice()
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = dice.fn })
    local x = NewNode("X", "xaaaaaa2", { channel = true, catches = 30 })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 20 })
    x.delay = 6
    c.node:Receive("w:X", "channel", HelloText(x))
    local heard = GetTime()
    while not c.node.session and GetTime() - heard < 60 do
        advance(1)
    end
    assert(c.node.session, "C started no session with X")
    return c, x, g
end

test("a group peer refused busy during a channel session comes back by the busy retry within 5 minutes", function()
    local c, x, g = ChannelSessionRunning()
    local hello = GetTime()
    c.node:Hello() -- G hears C in the group and starts a session while C is busy with X
    local busyAt
    while GetTime() - hello < 300 and not (Holds(g, "caaaaaa2") and Holds(c, "gaaaaaa2")) do
        advance(1)
        busyAt = busyAt or (Sent("C", "G", "B") > 0 and GetTime())
    end
    eq(busyAt ~= nil, true, "C answered BYE busy")
    eq(Holds(c, "xaaaaaa2"), true, "the channel session finished")
    eq(Holds(g, "caaaaaa2") and Holds(c, "gaaaaaa2"), true, "the group session finished within 5 minutes")
    eq(Sent("G", "C", "S"), 2, "the SUM and one retry")
end)

test("a group HELLO heard during a channel session starts the group session once it is over, within 5 min", function()
    local c, x, g = ChannelSessionRunning()
    local hello = GetTime()
    g.node:Hello() -- C hears G while busy with X
    while GetTime() - hello < 300 and not (Holds(g, "caaaaaa2") and Holds(c, "gaaaaaa2")) do
        advance(1)
    end
    eq(Holds(c, "xaaaaaa2"), true, "the channel session finished")
    eq(Holds(g, "caaaaaa2") and Holds(c, "gaaaaaa2"), true, "the group session finished within 5 minutes")
    eq(Sent("C", "G", "S") >= 1, true, "C started it")
end)

test("a near peer whose start meets a session begun in its start delay waits for that session's end again",
    function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { group = "g" })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 30 })
    c.node:Receive("w:G", "group", HelloText(g)) -- the start is armed, 2-20 s
    c.node.session = { peer = "w:X", role = "responder", ourWants = {}, received = {} } -- a channel stranger's SUM
    advance(25)
    eq(c.node.skippedNear["w:G"], true, "waiting for the session's end")
    c.node:DropSession()
    advance(25)
    eq(Sent("C", "G", "S"), 1, "started once it was over")
end)

test("a channel stranger's start gives way to a near peer heard in its start delay", function()
    NewNet()
    local delays = { 3, 15 } -- the start delays drawn: the stranger's, then the group peer's
    local function random(a, b)
        if b then
            return table.remove(delays, 1) or a
        end
        return a and math.random(a) or 0
    end
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = random })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 30 })
    local x = NewNode("X", "xaaaaaa2", { channel = true, catches = 20 })
    c.node:Receive("w:X", "channel", HelloText(x)) -- no near peer waits yet: the start is armed, 3 s
    advance(1)
    c.node:Receive("w:G", "group", HelloText(g)) -- armed, 15 s
    advance(30)
    eq(Sent("C", "X", "S"), 0, "the stranger's start gave way")
    eq(Sent("C", "G", "S"), 1, "the group peer's session started on time")
end)

test("a near peer whose start meets a start with somebody else waits for the 2 min gap, then starts", function()
    NewNet()
    local delays = { 15 }
    local function random(a, b)
        if b then
            return table.remove(delays, 1) or a
        end
        return a and math.random(a) or 0
    end
    local c = NewNode("C", "caaaaaa2", { group = "g", random = random })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 30 })
    c.node:Receive("w:G", "group", HelloText(g)) -- armed, 15 s
    advance(5)
    c.node.lastStart = GetTime() -- a session with somebody else started and is already over
    advance(15)
    eq(c.node.skippedNear["w:G"], true, "waiting for the gap")
    eq(Sent("C", "G", "S"), 0, "not yet")
    advance(130)
    eq(Sent("C", "G", "S"), 1, "started after the gap")
end)

test("near peers waiting for a session's end are kept through a pause and considered when it ends", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { group = "g" })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 30 })
    c.node.session = { peer = "w:X", role = "responder", ourWants = {}, received = {} }
    c.node:Receive("w:G", "group", HelloText(g))
    eq(c.node.skippedNear["w:G"], true, "skipped: a session runs")
    c.node:Pause("combat")
    eq(c.node.skippedNear["w:G"], true, "kept through the pause")
    advance(25)
    eq(Sent("C", "G", "S"), 0, "nothing while paused")
    c.node:Resume()
    advance(25)
    eq(Sent("C", "G", "S"), 1, "started after the pause")
end)

---------------------------------------------------------------------------
-- The busy retry
---------------------------------------------------------------------------
local BUSY = { peer = "w:Nobody", role = "responder", ourWants = {}, received = {} }

test("a near peer that answers busy is tried once more 120-180 s later, and only once", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { group = "g" })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 20 })
    g.node.session = BUSY -- busy with somebody else for the whole test
    g.node:Hello()
    advance(25)
    eq(Sent("C", "G", "S"), 1, "a SUM to G")
    advance(115)
    eq(Sent("C", "G", "S"), 1, "no retry before 120 s")
    advance(90)
    eq(Sent("C", "G", "S"), 2, "one retry by 180 s (plus the start delay)")
    advance(600)
    eq(Sent("C", "G", "S"), 2, "only once")
end)

test("a near peer whose busy retry is due keeps a channel stranger's session waiting", function()
    NewNet()
    local delays = { 2, 180 } -- C's start delay, then its busy retry
    local function random(a, b)
        if b then
            return table.remove(delays, 1) or a
        end
        return a and math.random(a) or 0
    end
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = random })
    local g = NewNode("G", "gaaaaaa2", { group = "g", catches = 20 })
    g.node.session = BUSY
    g.node:Hello()
    advance(5)
    eq(c.node.peers["w:G"].retrying, true, "G answered busy: its retry is due")
    advance(125) -- past the 2 min gap since C's start, before the retry at 180 s
    c.node:Receive("w:Stranger", "channel", StrangerHello(("z"):rep(#c.node:HashText())))
    eq(c.node.peers["w:Stranger"].starting, nil, "the group peer's retry comes first")
    g.node.session = nil
end)

test("a channel peer that answers busy is not tried again before its next HELLO", function()
    NewNet()
    local dice = Dice()
    local c = NewNode("C", "caaaaaa2", { channel = true, random = dice.fn })
    local x = NewNode("X", "xaaaaaa2", { channel = true, catches = 30 })
    x.node.session = BUSY
    c.node:Receive("w:X", "channel", HelloText(x))
    advance(25)
    eq(Sent("C", "X", "S"), 1, "a SUM")
    eq(Sent("X", "C", "B"), 1, "BYE busy")
    advance(600)
    eq(Sent("C", "X", "S"), 1, "no retry")
end)

---------------------------------------------------------------------------
-- Cooldowns and paths
---------------------------------------------------------------------------
test("a channel peer keeps the 30 min cooldown; a guild or group HELLO from it upgrades its path", function()
    NewNet()
    local dice = Dice()
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g", random = dice.fn })
    local x = NewNode("X", "xaaaaaa2", { channel = true, group = "g", catches = 30 })
    c.node:Receive("w:X", "channel", HelloText(x))
    eq(c.node.peers["w:X"].via, "channel", "first heard in the channel")
    advance(60)
    eq(Holds(c, "xaaaaaa2"), true, "exchanged")
    x.store.records["xaaaaaa2"] = OwnRecord("xaaaaaa2", 40) -- X fished more
    x.node.cache = {}
    advance(20 * 60)
    c.node:Receive("w:X", "channel", HelloText(x))
    eq(c.node.peers["w:X"].starting, nil, "20 min later: still in the cooldown")
    advance(11 * 60)
    c.node:Receive("w:X", "channel", HelloText(x))
    eq(c.node.peers["w:X"].starting, true, "31 min later: a new session")
    advance(120)
    x.node:Hello() -- the group
    advance(1)
    eq(c.node.peers["w:X"].via, "group", "upgraded by the group HELLO")
end)

test("a stranger who whispered first becomes a channel peer when heard in the channel", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { channel = true })
    local x = NewNode("X", "xaaaaaa2", { channel = true, catches = 30 })
    c.node:Peer("w:X", "whisper") -- as after a SUM it sent
    c.node:Receive("w:X", "channel", HelloText(x))
    eq(c.node.peers["w:X"].via, "channel", "a channel peer")
end)

test("a flood of other messages from the channel gets its sender ignored, also by whisper (FR-010)", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { channel = true })
    local sum = "Sxx " .. ("a"):rep(7 * #ns.BASE32)
    for _ = 1, 5000 do
        c.node:Receive("w:J", "channel", sum)
        if c.node.peers["w:J"].ignored then
            break
        end
    end
    eq(c.node.peers["w:J"].ignored, true, "ignored")
    c.node:Receive("w:J", "whisper", "Syy " .. ("a"):rep(7 * #ns.BASE32))
    eq(c.node.session, nil, "its whispered SUM starts no session")
end)

---------------------------------------------------------------------------
-- The peer bound
---------------------------------------------------------------------------
test("above 300 channel peers the one heard longest ago is forgotten with its tag; never a near or session peer",
    function()
        NewNet()
        local c = NewNode("C", "caaaaaa2", { channel = true, group = "g" })
        local same = c.node:HashText()
        c.node:Receive("w:G", "group", StrangerHello(same))
        c.node:Receive("w:F", "whisper", StrangerHello(same))
        c.node:Receive("w:Busy", "channel", StrangerHello(same))
        c.node.session = { peer = "w:Busy", role = "responder", ourWants = {}, received = {} }
        local firstTag
        for i = 1, 301 do
            advance(1)
            local text = StrangerHello(same)
            firstTag = firstTag or text:match("^H (%w+)")
            c.node:Receive("w:P" .. i, "channel", text)
        end
        eq(c.node.channelCount, 300, "300 channel peers")
        eq(c.node.peers["w:Busy"] ~= nil, true, "the session's peer stays")
        -- 302 channel peers with the session's: the two heard longest ago, after it, go.
        eq(c.node.peers["w:P1"] == nil and c.node.peers["w:P2"] == nil, true, "the oldest others are forgotten")
        eq(c.node.byTag[firstTag], nil, "with their tags")
        eq(c.node.peers["w:P3"] ~= nil, true, "the next one stays")
        eq(c.node.peers["w:G"] ~= nil and c.node.peers["w:F"] ~= nil, true, "the group peer and the friend stay")
        eq(c.node:Activity().heard.channel, 300, "heard in the channel this hour")
        eq(c.node.announcers["w:P1"] ~= nil, true, "a forgotten peer is still known to have announced (locks)")
        c.node.session = nil
    end)

test("a channel HELLO marks its sender heard in the channel even when it goes no further", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { channel = true, group = "g" })
    local same = c.node:HashText()
    local text = StrangerHello(same)
    c.node:Receive("w:G", "group", text)
    advance(10)
    c.node:Receive("w:G", "channel", text)
    eq(c.node.announcers["w:G"] ~= nil, true, "within 60 s of its group HELLO")
    text = StrangerHello(same)
    c.node:Receive("b:7", "bnet", text)
    c.node:Receive("w:F", "channel", text)
    eq(c.node.announcers["w:F"] ~= nil, true, "the same client heard by Battle.net first")
end)

test("an ignored channel peer forgotten by the bound is still ignored when it comes back", function()
    NewNet()
    local c = NewNode("C", "caaaaaa2", { channel = true })
    local same = c.node:HashText()
    c.node:Receive("w:Bad", "channel", StrangerHello(same))
    c.node:Ignore("w:Bad", c.node.peers["w:Bad"])
    for i = 1, 300 do
        advance(1)
        c.node:Receive("w:Q" .. i, "channel", StrangerHello(same))
    end
    eq(c.node.peers["w:Bad"], nil, "forgotten: heard longest ago")
    c.node:Receive("w:Bad", "channel", StrangerHello(("z"):rep(#same)))
    eq(c.node.peers["w:Bad"].ignored, true, "still ignored")
    eq(c.node.peers["w:Bad"].hash, nil, "its HELLO was dropped")
    eq(c.node.rejected, 1, "counted once")
end)

---------------------------------------------------------------------------
-- Parts after a session
---------------------------------------------------------------------------
test("parts are taken from the session's peer, and from the one that just ended while a new session runs",
    function()
    NewNet()
    local c = NewNode("C", "caaaaaa2")
    c.node:Finish(c.node:NewSession("ab", "w:A", "starter"))
    c.node:NewSession("cd", "w:B", "responder")
    eq(c.node:ExpectsParts("w:B"), true, "the running session's peer")
    eq(c.node:ExpectsParts("w:A"), true, "the one that just ended: its last records are still taken")
    eq(c.node:ExpectsParts("w:Other"), false, "nobody else")
    advance(20)
    eq(c.node:ExpectsParts("w:A"), false, "after the session timeout")
    c.node:DropSession()
end)
