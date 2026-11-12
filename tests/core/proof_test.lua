-- Data.lua: SHA-256 and the version chain's link step with the real hash (specs/004-public-channel-sync, research
-- R9). Real SHA-256 costs milliseconds per call in fengari, so this file only checks the vectors; the chains are
-- tested with the fast stand-in in tests/catchdb/proof_chain_test.lua.

real_proof = true
load_addon()

local ABC = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
local VECTORS = {
    { "", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
    { "abc", ABC },
    { "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" },
}
do -- 200 bytes, crossing two block borders (the digest from node:crypto)
    local chars = {}
    for i = 0, 199 do
        chars[i + 1] = string.char(32 + (i * 7) % 95)
    end
    table.insert(VECTORS, { table.concat(chars), "55780e20c35ad478b68cfe7293521df897d84a6644d777fb6336a5ac2296f7a9" })
end

test("the bit stub gives LuaBitOp's signed results, and unsigned ones on request", function()
    eq(bit.bnot(0), -1, "bnot")
    eq(bit.band(-1, 4294967295), -1, "band")
    eq(bit.rshift(-1, 28), 15, "logical right shift")
    eq(bit.lshift(2147483648, 1), 0, "shifts wrap at 32 bits")
    bit_unsigned = true
    eq(bit.bnot(0), 4294967295, "unsigned bnot")
    bit_unsigned = nil
end)

test("SHA256 gives the FIPS 180-4 test vectors, with signed and with unsigned bit results", function()
    for _, vector in ipairs(VECTORS) do
        eq(ns.SHA256(vector[1]), vector[2], ("%d bytes"):format(#vector[1]))
    end
    bit_unsigned = true
    for _, vector in ipairs(VECTORS) do
        eq(ns.SHA256(vector[1]), vector[2], ("%d bytes, unsigned"):format(#vector[1]))
    end
    bit_unsigned = nil
end)

test("a link step is the first 80 bits of the digest as 16 base32 characters, as the harvest computes it", function()
    eq(ns.HexToBase32(ABC, 16), "xj4bnp4pahh6uqkb", "the digest of abc (node:crypto)")
    eq(ns.ProofStep("abcdefghijklmnop"), "6oo2y3f2xjjv4lba", "one step (node:crypto)")
    eq(ns.ProofStep(ns.ProofStep("abcdefghijklmnop")), "sbb5d3yn6x6u3vuz", "two steps")
    for _, unsigned in ipairs({ false, true }) do
        bit_unsigned = unsigned or nil
        for _, vector in ipairs(VECTORS) do
            eq(ns.ProofStep(vector[1]), ns.HexToBase32(ns.SHA256(vector[1]), 16),
                ("read from the digest's words as from its hex (%d bytes)"):format(#vector[1]))
        end
    end
    bit_unsigned = nil
end)
