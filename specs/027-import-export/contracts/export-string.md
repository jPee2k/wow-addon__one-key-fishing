# Contract: the export string and the import's answers

## Format 1

```text
OKF:1:<count>:<check>:<token>,<token>,...,<token>:END
```

- `<count>` is a decimal number (1 or more), and `<check>` is 7 base32 characters (`ns.BASE32`).
- `<token>` is Base64 (`A-Z a-z 0-9 + / =`): one record, `C_EncodingUtil` CBOR, then Deflate, then Base64.
- The record is the exchange's sent form (`Store.ForSending`): `id`, `epoch`, `seq`, `proof` and `builds`. No `seen`,
  no mark.
- `<check>` = `ns.Base32(Share.Hash(table.concat(tokens, ",")), 7)`.

Reading a pasted text:

1. Remove every whitespace character (`%s`).
2. Take the text from the first `OKF:` to the first `:END` after it.
   - No `OKF:` gives `error = "empty"`.
   - No `:END` gives `"cut"`.
3. Split it by `:` into 5 fields.
   - A format other than `1` gives `"format"`.
   - A count that is not a number, or does not equal the number of tokens, gives `"cut"`.
4. Compute the check over the token text.
   - A mismatch gives `"damaged"`.
5. Only now are any records stored.

## Answers per record (the tally)

| Store answer | Counted as |
|---|---|
| the record's ID is the own ID | `own` |
| `new`, `newer` (and still stored after `Store.Evict`) | `new` |
| `same`, `older`, refused as "already in the bundled data" | `known` |
| a decode failure, `CheckRecord` or `CheckVersion` failing, `blocked`, evicted at once | `refused` |

## Guarantees

- An export of store A, imported into an empty store B with the same seed, gives `new` = the records exported
  (minus those B's checks refuse), and B's records equal A's exported ones field by field.
- Importing the same string twice gives `new = 0` the second time.
- Importing one's own export gives `own` for the own units and `known` for the rest.
- A format-1 string never holds more than `EXPORT_LIMIT` (262,144) characters.
