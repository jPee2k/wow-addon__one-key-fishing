-- Data: static game data. The client can run in any language, so everything is matched by ID, never by name.
local _, ns = ...

-- Fishing spell ranks, lowest to highest: Apprentice, Journeyman, Expert, Artisan.
ns.FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248 }

ns.FISHING_SKILL_LINE = 356

-- Game object entry of the fishing bobber, as seen in its GUID (the "softinteract" unit, fishing loot sources).
ns.BOBBER_OBJECT_ID = "35591"

-- The object ID (entry) of a game object GUID, or nil for any other GUID. Forever scrambles the spawn part of
-- GUIDs, so the object ID is the part to compare.
function ns.GameObjectID(guid)
    if not guid then
        return nil
    end
    local unitType, _, _, _, _, objectID = strsplit("-", guid)
    return unitType == "GameObject" and objectID or nil
end

-- Base32 in lower case without padding: anonymous contribution IDs, node tags, session IDs and hashes of the
-- catch exchange (CatchDB.lua, Comm.lua, Share.lua).
ns.BASE32 = "abcdefghijklmnopqrstuvwxyz234567"

-- value (a whole number >= 0) in `width` base32 characters, the most significant first.
function ns.Base32(value, width)
    local chars = {}
    for i = width, 1, -1 do
        local digit = value % 32
        chars[i] = ns.BASE32:sub(digit + 1, digit + 1)
        value = math.floor(value / 32)
    end
    return table.concat(chars)
end

-- `length` random base32 characters; `random` (default math.random) for deterministic tests.
function ns.RandomBase32(length, random)
    random = random or math.random
    local chars = {}
    for i = 1, length do
        local index = random(32)
        chars[i] = ns.BASE32:sub(index, index)
    end
    return table.concat(chars)
end

-- The first `count` base32 characters of a hex string, 5 hex digits (20 bits) to 4 characters, most significant
-- first: what the harvest (tools/harvest.mjs) computes the same way.
function ns.HexToBase32(hex, count)
    local chars = {}
    for group = 0, math.ceil(count / 4) - 1 do
        table.insert(chars, ns.Base32(tonumber(hex:sub(group * 5 + 1, group * 5 + 5), 16), 4))
    end
    return table.concat(chars):sub(1, count)
end

-- SHA-256 (FIPS 180-4) of a byte string, as 64 lowercase hex digits, for the version chains of the catch exchange
-- (specs/004-public-channel-sync/research.md R9). Built on the game's bit library; every intermediate value is
-- taken modulo 2^32, so the digest is the same whether the library returns signed or unsigned numbers.
local SHA_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local WORD = 4294967296

-- A 32-bit word as 8 hex digits, in two halves: string.format("%x") of a number above 2^31 is not safe in Lua 5.1.
local function Hex32(word)
    return ("%04x%04x"):format(math.floor(word / 65536), word % 65536)
end

-- The game's bit library, read once (without it the first digest fails, as an index of a missing table would).
local band, bor, bxor, bnot, rshift, lshift
if bit then
    band, bor, bxor, bnot, rshift, lshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rshift, bit.lshift
end

local function RotR(x, n)
    return bor(rshift(x, n), lshift(x, 32 - n)) % WORD
end

local digestH, digestW = {}, {} -- reused by every digest: one is computed in one go, never nested

-- The eight 32-bit words of the digest, in a table the next call reuses.
local function Digest(message)
    local bits = #message * 8
    message = message .. "\128" .. ("\0"):rep((55 - #message) % 64)
        .. ("\0"):rep(3) .. string.char(math.floor(bits / WORD) % 256)
        .. string.char(math.floor(bits / 16777216) % 256, math.floor(bits / 65536) % 256,
            math.floor(bits / 256) % 256, bits % 256)
    local h, w = digestH, digestW
    h[1], h[2], h[3], h[4] = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    h[5], h[6], h[7], h[8] = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    for chunk = 1, #message, 64 do
        for i = 0, 15 do
            local b1, b2, b3, b4 = message:byte(chunk + i * 4, chunk + i * 4 + 3)
            w[i] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        end
        for i = 16, 63 do
            local x, y = w[i - 15], w[i - 2]
            local s0 = bxor(bxor(RotR(x, 7), RotR(x, 18)), rshift(x, 3)) % WORD
            local s1 = bxor(bxor(RotR(y, 17), RotR(y, 19)), rshift(y, 10)) % WORD
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % WORD
        end
        local a, b, c, d, e, f, g, k = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 0, 63 do
            local s1 = bxor(bxor(RotR(e, 6), RotR(e, 11)), RotR(e, 25)) % WORD
            local ch = bxor(band(e, f), band(bnot(e), g)) % WORD
            local t1 = (k + s1 + ch + SHA_K[i + 1] + w[i]) % WORD
            local s0 = bxor(bxor(RotR(a, 2), RotR(a, 13)), RotR(a, 22)) % WORD
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c)) % WORD
            k, g, f, e, d, c, b, a = g, f, e, (d + t1) % WORD, c, b, a, (t1 + s0 + maj) % WORD
        end
        h[1], h[2], h[3], h[4] = (h[1] + a) % WORD, (h[2] + b) % WORD, (h[3] + c) % WORD, (h[4] + d) % WORD
        h[5], h[6], h[7], h[8] = (h[5] + e) % WORD, (h[6] + f) % WORD, (h[7] + g) % WORD, (h[8] + k) % WORD
    end
    return h
end

function ns.SHA256(message)
    local h = Digest(message)
    local out = {}
    for i = 1, 8 do
        out[i] = Hex32(h[i])
    end
    return table.concat(out)
end

local BASE32_DIGITS = {} -- 0-31 -> its character
for i = 1, 32 do
    BASE32_DIGITS[i - 1] = ns.BASE32:sub(i, i)
end

-- 20 bits as 4 base32 characters, the most significant first (ns.Base32(value, 4) without its table).
local function Base32Of20(value)
    return BASE32_DIGITS[math.floor(value / 32768) % 32] .. BASE32_DIGITS[math.floor(value / 1024) % 32]
        .. BASE32_DIGITS[math.floor(value / 32) % 32] .. BASE32_DIGITS[value % 32]
end

-- One link down a version chain: the first 80 bits of SHA256(link) as 16 base32 characters (data-model.md of
-- specs/004-public-channel-sync, "The version chain"), read from the digest's words in the four 20-bit groups
-- HexToBase32(SHA256(link), 16) takes; no hex on the way, since a chain walk runs this thousands of times. The
-- harvest computes the same with node:crypto.
-- VERIFY(V26): the game has the bit library, SHA256("abc") is the known digest, and 64 steps take under 5 ms
function ns.ProofStep(link)
    local h = Digest(link)
    local h1, h2, h3 = h[1], h[2], h[3]
    return Base32Of20(math.floor(h1 / 4096)) .. Base32Of20((h1 % 4096) * 256 + math.floor(h2 / 16777216))
        .. Base32Of20(math.floor(h2 / 16) % 1048576) .. Base32Of20((h2 % 16) * 65536 + math.floor(h3 / 65536))
end

-- A rolling sum over the last `minutes` minutes, kept per minute in `counts` (minute -> sum): adds `weight` at
-- `now` (seconds; a weight of 0 only reads), drops the minutes outside the window and returns the sum. The traffic
-- budget (Comm.lua) and the per-sender limits (Share.lua) count with it, so their window ends at the same edge.
function ns.CountRecent(counts, now, weight, minutes)
    local minute, total = math.floor(now / 60), 0
    if weight ~= 0 then
        counts[minute] = (counts[minute] or 0) + weight
    end
    for at, count in pairs(counts) do
        if at > minute - minutes then
            total = total + count
        else
            counts[at] = nil
        end
    end
    return total
end

-- The number of keys of a table.
function ns.CountKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- A character name with its realm: the game names a player of the own realm without one ("Name" -> "Name-Realm").
local function WithRealm(name)
    if name:find("-", 1, true) then
        return name
    end
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    return realm and (name .. "-" .. realm) or name
end

-- True when two character names ("Name-Realm", or "Name" for the player's own realm) are the same character: a
-- player of the same name on another realm is somebody else.
function ns.SameCharacter(a, b)
    return a == b or WithRealm(a) == WithRealm(b)
end

-- True when the interact key would hit the bobber (not some other object nearby).
-- The bobber has no nameplate and UnitExists is false for it, but its name and GUID are readable.
function ns.IsBobberTargeted()
    return ns.GameObjectID(UnitGUID("softinteract")) == ns.BOBBER_OBJECT_ID
end

local fishingSpellLookup = {}
for _, id in ipairs(ns.FISHING_SPELL_IDS) do
    fishingSpellLookup[id] = true
end

function ns.IsFishingSpell(spellID)
    return fishingSpellLookup[spellID] == true
end

local function IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    return IsPlayerSpell(spellID)
end

-- Highest known Fishing rank, or nil if Fishing is not learned.
function ns.GetFishingSpellID()
    for i = #ns.FISHING_SPELL_IDS, 1, -1 do
        local id = ns.FISHING_SPELL_IDS[i]
        if IsSpellKnown(id) then
            return id
        end
    end
end

-- Calls fn(info, bag, slot) for every item in the regular bags. Stops when fn returns true
-- and returns that bag, slot.
function ns.ForEachBagItem(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and fn(info, bag, slot) then
                return bag, slot
            end
        end
    end
end
