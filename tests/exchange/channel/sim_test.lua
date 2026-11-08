-- The hidden public channel at scale (specs/004-public-channel-sync, SC-001, SC-002, SC-003, SC-011): SIM_NODES (or
-- 60, which keeps npm test under 30 s) protocol nodes (Share.NewNode) connected only through one fake channel, with
-- whispers for the sessions. Every node really receives every channel HELLO, so the chance to start is the real
-- code. The run uses its own clock and event queue (the shared advance() scans its timers and is too slow for
-- thousands of events), and encodes each record version once: Share.Encode / Decode take about 2 ms each in fengari
-- (the format has its own tests).
-- Full sizes run by hand: OKF_SIM_NODES=500 npm test -- channel_sim (docs/development.md).
--
-- Two starts (research R5):
-- - cold: nobody holds anybody's record, so every hash differs and the channel is as busy as it gets. One hour of it
--   measures the requests per announcement (SC-002) and the hourly bytes (SC-003). Spreading every record to every
--   client takes far longer than 3 hours at 500 clients: it needs about N^2 records sent, and the budget lets each
--   client send about 130 an hour.
-- - warm: every client holds every other one's record (a network some time after a release, whose bundled data
--   absorbed the rest), and one contribution changes at minute 30; it must reach 90% within 3 hours (SC-001). Then a
--   lock moves everybody to the first fallback (SC-011).
--
-- What the game node and Channel.lua do around the protocol node is modelled with their constants (research R4, R5):
-- a join 30-60 s after the login, the first channel HELLO 30-90 s after the join, then one every 30-50 min, and after
-- a lock a move 10-20 s later with a HELLO 5-30 s after it. Comm's budget rule is modelled too: a message other than
-- BYE does not go out when the last hour's bytes and 255 more would pass the budget.

channel_on = true

load_addon()
math.randomseed(2026)

local N = rawget(_G, "SIM_NODES") or 60
local Share = ns.Share
local BUDGET = ns.Comm.BUDGET
local MAX_MESSAGE = 255
local FISH = 6291
local HOUR, MINUTE = 3600, 60
local started = os.clock()

---------------------------------------------------------------------------
-- The clock and the event queue (a binary heap on time, then order of scheduling)
---------------------------------------------------------------------------
local clock, order, heap = 0, 0, {}

local function Before(a, b)
    return a.at < b.at or (a.at == b.at and a.order < b.order)
end

local function Schedule(at, fn)
    order = order + 1
    local event = { at = at, order = order, fn = fn }
    table.insert(heap, event)
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if not Before(heap[i], heap[parent]) then
            break
        end
        heap[i], heap[parent] = heap[parent], heap[i]
        i = parent
    end
end

local function Pop()
    local top, last = heap[1], table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local left, right, smallest = 2 * i, 2 * i + 1, i
            if heap[left] and Before(heap[left], heap[smallest]) then
                smallest = left
            end
            if heap[right] and Before(heap[right], heap[smallest]) then
                smallest = right
            end
            if smallest == i then
                break
            end
            heap[i], heap[smallest] = heap[smallest], heap[i]
            i = smallest
        end
    end
    return top
end

local function RunUntil(at)
    while heap[1] and heap[1].at <= at do
        local event = Pop()
        clock = event.at
        event.fn()
    end
    clock = at
end

local function Uniform(a, b)
    return a + math.random() * (b - a)
end

---------------------------------------------------------------------------
-- Records and their encoding
---------------------------------------------------------------------------
local function OwnRecord(id, places, seq)
    local cells, seconds = {}, 0
    for i = 1, places do
        local cell = catch_cell(10, 1, { [FISH] = { 10, 10 } })
        local n = (id:byte(1) * 7 + id:byte(2) * 3 + id:byte(3) * 11 + i) % 900
        cells[("%d:3:%02d"):format(1400 + math.floor(n / 100), n % 100)] = cell
        seconds = seconds + cell.t
    end
    local record = { id = id, epoch = 0, seq = math.max(seq or 1, math.ceil(seconds / ns.CatchDB.private.STEP_SECONDS)),
        builds = { ["1.60.1"] = cells } }
    return prove(record)
end

-- A contribution ID from a number, the least significant digit first (IDs differ from their first character on).
local function NewID(i)
    return ns.Base32(i, 8):reverse()
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, inner in pairs(value) do
        out[key] = Copy(inner)
    end
    return out
end

-- Share.Encode once per record version (id, epoch, seq and proof name one content); Decode as a fresh copy of it.
local encoded, pristine = {}, {}

local function SimEncode(record)
    local key = ("%s@%s.%s.%s"):format(tostring(record.id), tostring(record.epoch), tostring(record.seq),
        tostring(record.proof))
    local text = encoded[key]
    if not text then
        text = Share.Encode(record)
        encoded[key] = text
        pristine[text] = text and Share.Decode(text)
    end
    return text
end

local function SimDecode(text)
    local record = pristine[text]
    if record then
        return Copy(record)
    end
    return Share.Decode(text)
end

---------------------------------------------------------------------------
-- A network: nodes, the channel and whispers
---------------------------------------------------------------------------
local nodes, byName, stats

local function LastHour(info)
    return ns.CountRecent(info.bytes, clock, 0, 60)
end

-- Comm's rule: over the budget only BYE goes out. Counts what goes out; false when the message is dropped.
local function Transmit(info, text)
    local bye = text:sub(1, 1) == "B"
    if not bye and LastHour(info) + MAX_MESSAGE > BUDGET then
        stats.dropped = stats.dropped + 1
        return false
    end
    ns.CountRecent(info.bytes, clock, #text, 60)
    if not bye then
        ns.CountRecent(info.dataBytes, clock, #text, 60)
        local minute = math.floor(clock / MINUTE)
        info.dataByMinute[minute] = (info.dataByMinute[minute] or 0) + #text
    end
    return true
end

local function Deliver(from, to, via, text)
    Schedule(clock + Uniform(0.1, 0.5), function()
        if to.online and (via ~= "channel" or (to.joined and to.index == from.index)) then
            if via == "channel" and to.index == 2 and from ~= to then
                to.metAfterLock = true
            end
            if via == "whisper" and text:sub(1, 1) == "S" then
                stats.sums = stats.sums + 1
            end
            to.node:Receive("w:" .. from.name, via, text)
        end
    end)
end

local function NewSimNode(i)
    local info = { name = "N" .. i, id = NewID(1000 + i * 37), bytes = {}, dataBytes = {}, dataByMinute = {},
        index = 1 }
    local store = { myID = info.id, mine = {}, records = {} }
    store.records[info.id] = OwnRecord(info.id, 3)
    info.store = store
    info.node = Share.NewNode(store, {
        now = function() return clock end,
        time = function() return clock end,
        after = function(delay, fn) Schedule(clock + delay, fn) end,
        send = function(address, text)
            local to = byName[address:match("^w:(.+)$") or ""]
            if Transmit(info, text) and to then
                Deliver(info, to, "whisper", text)
            end
        end,
        broadcast = function() end, -- no guild, no group: only the channel connects them
        channelBroadcast = function(text)
            if not info.joined or not Transmit(info, text) then
                return
            end
            stats.hellos = stats.hellos + 1
            for _, other in ipairs(nodes) do
                Deliver(info, other, "channel", text) -- the sender hears its own echo too
            end
        end,
        forEachFriend = function() end,
        canSend = function(bytes) return LastHour(info) + (bytes or 0) <= BUDGET end,
        absorbed = function() return {} end,
        seedEpoch = function() return 0 end,
        encode = SimEncode,
        decode = SimDecode,
    })
    nodes[i], byName[info.name] = info, info
    return info
end

-- The channel HELLO rounds of the game node: the first after `first` seconds, then every 30-50 minutes.
local function StartRounds(info, first)
    local token = {}
    info.round = token
    local function Round()
        if info.round ~= token then
            return
        end
        if info.joined then
            info.node:ChannelHello()
        end
        Schedule(clock + Uniform(30 * MINUTE, 50 * MINUTE), Round)
    end
    Schedule(clock + first, Round)
end

-- A fresh network of N nodes logging in over the first 10 minutes. warm: each holds every other one's record.
local function NewNetwork(warm)
    clock, order, heap = 0, 0, {}
    nodes, byName, stats = {}, {}, { hellos = 0, sums = 0, dropped = 0 }
    for i = 1, N do
        local info = NewSimNode(i)
        Schedule(Uniform(0, 10 * MINUTE), function()
            info.online = true
            Schedule(clock + Uniform(30, 60), function()
                info.joined = true
                StartRounds(info, Uniform(30, 90))
            end)
        end)
    end
    if warm then
        -- One copy of each record, shared by every store that holds it (a store only replaces whole records).
        for _, owner in ipairs(nodes) do
            local held = Copy(owner.store.records[owner.id])
            held.seen = 0
            for _, info in ipairs(nodes) do
                if info ~= owner then
                    info.store.records[owner.id .. "@0"] = held
                end
            end
        end
    end
end

-- The most bytes other than BYE one node sent in any 60 minutes of the run so far.
local function BusiestHour()
    local worst = 0
    for _, info in ipairs(nodes) do
        local window = 0
        local last = math.floor(clock / MINUTE)
        for minute = 0, last do
            window = window + (info.dataByMinute[minute] or 0) - (info.dataByMinute[minute - 60] or 0)
            worst = math.max(worst, window)
        end
    end
    return worst
end

---------------------------------------------------------------------------
-- The runs
---------------------------------------------------------------------------
test(("%d nodes, cold start, one hour: <= 5 SUMs per channel HELLO, no node over the budget"):format(N), function()
    NewNetwork(false)
    RunUntil(HOUR)
    local perHello = stats.sums / math.max(1, stats.hellos)
    local worst = BusiestHour()
    print(("  sim cold: %d nodes, %d channel HELLOs, %d SUMs (%.2f per HELLO), busiest hour %d bytes (BYE aside), "
        .. "%d messages held back by the budget, %.1f s"):format(N, stats.hellos, stats.sums, perHello, worst,
        stats.dropped, os.clock() - started))
    assert(perHello <= 5, ("SC-002: %.2f SUMs per channel HELLO"):format(perHello))
    assert(worst <= BUDGET, ("SC-003: %d bytes in one hour"):format(worst))
end)

local NEW, newSeq -- the node whose contribution changes at minute 30, and that version's seq

test(("%d nodes, warm start, 3 hours: a contribution changed at minute 30 reaches 90%%"):format(N), function()
    NewNetwork(true)
    Schedule(30 * MINUTE, function()
        NEW = nodes[1]
        local old = NEW.store.records[NEW.id]
        local record = OwnRecord(NEW.id, 5, old.seq + 1)
        NEW.store.records[NEW.id] = record
        newSeq = record.seq
    end)
    RunUntil(3 * HOUR)
    local holding = 0
    for _, info in ipairs(nodes) do
        local held = info == NEW and info.store.records[NEW.id] or info.store.records[NEW.id .. "@0"]
        if held and held.seq >= newSeq then
            holding = holding + 1
        end
    end
    print(("  sim warm: %d nodes, %d channel HELLOs, %d SUMs (%.2f per HELLO), the new version at %d nodes (%.0f%%), "
        .. "busiest hour %d bytes, %.1f s"):format(N, stats.hellos, stats.sums, stats.sums / math.max(1, stats.hellos),
        holding, 100 * holding / N, BusiestHour(), os.clock() - started))
    assert(holding >= 0.9 * N, ("SC-001: the new version reached %d of %d nodes"):format(holding, N))
    assert(BusiestHour() <= BUDGET, "SC-003 in the warm network")
end)

test("the channel locked at hour 3: within 15 minutes at least 90% meet again in the first fallback", function()
    local lockedAt = clock
    for _, info in ipairs(nodes) do
        if info.joined then
            -- Channel.lua: a password by a player not heard announcing, nobody undoes it within the 10-20 s wait.
            Schedule(clock + Uniform(10, 20), function()
                info.joined = false
                info.index = 2
                Schedule(clock + Uniform(0, 5), function() -- the join and its confirmation
                    info.joined = true
                    StartRounds(info, Uniform(5, 30))
                end)
            end)
        end
    end
    RunUntil(lockedAt + 15 * MINUTE)
    local met = 0
    for _, info in ipairs(nodes) do
        if info.joined and info.index == 2 and info.metAfterLock then
            met = met + 1
        end
    end
    print(("  sim lock: %d of %d nodes met again in the fallback within 15 minutes (%.0f%%), %.1f s"):format(met, N,
        100 * met / N, os.clock() - started))
    assert(met >= 0.9 * N, ("SC-011: %d of %d nodes"):format(met, N))
end)
