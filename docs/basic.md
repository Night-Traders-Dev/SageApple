# Tiny BASIC — `basic/basic.sage`

A complete Tiny BASIC interpreter written in SageLang (491 lines). It runs
**natively** (as Sage code, not 6502 machine code) and drives the machine
peripherally — the same design is used by the standalone OS and by the
host test harness.

## Design

* numbered program store: `prog` is a *sorted* list of `[line_number,
  text]`;
* `vars` — single-letter variables `a`..`z` (always initialized to 0);
* INPUT works from either a queue (`inq`, scripted by the harness) or
  interactive `feed(ch)` streaming (the terminal path);
* output accumulates in `out` — the OS/the tests read it via `out()`.

## Tokenizer

`tokenize(line)` normalizes identifiers to upper case and produces a token
stream: `["num", n]`, `["str", s]`, `["id", WORD]`, `["sym", c]`.

## Expression parser (recursive descent)

```
eval_arith -> eval_add ( + - ) with < > via eval_mul
eval_mul       * /        (divide-by-zero yields 0)
eval_un        unary minus
eval_atom      numbers, ( ... ), variables
```

Integer arithmetic only; differences from real BASIC: `PRINT` streams
`;` suppressed trailing CRLF only at statement end, `,` inserts 4 spaces.

## Statements

| statement | behavior |
|---|---|
| `PRINT` | strings/expressions, `;` and `,` separators |
| `LET x=expr` / `x=expr` | default assignment when the first token is an identifier |
| `GOTO n` | jump by line number |
| `IF cond THEN stmts` / `IF cond GOTO n` | conditions `= < <= > >= <>`, bare nonzero = true |
| `FOR v=a TO b [STEP s]` | push frame `[name, limit, step, line_index]` |
| `NEXT v` | apply step, reloop while the test holds |
| `INPUT v` | take from the queue or input prompt |
| `END` / `STOP` | stop the program |
| `BEEP [freq]` | optional speaker: tone
| `REM` | skip comment |

Program editing: `LIST`, `NEW`, `RUN` with a `1,000,000` step guard; unknown
GOTO prints `NO LINE <n>`; every program ends with `OK`; idle prompt `>`.

## Program store & persistence shape

* `set_line(n, text)` — sorted insert, or replace same-number lines;
* `find_line(n)` returns content index;
* the OS serializes programs via the filesystem (see [docs/os.md](os.md)),
  storing CRLF-joined lines, preserving exact list order.

## Test coverage

* `tests/basic/test_basic.sage` — 17 checks