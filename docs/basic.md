# Applesoft BASIC — `basic/basic.sage`

A full Applesoft-compatible BASIC interpreter written in SageLang (~2160
lines). It runs **natively** (as Sage code, not 6502 machine code) and
drives the machine peripherally — the same design is used by the DOS 3.3
command processor and the host test harness.

## Design

* numbered program store: `prog` is a *sorted* list of `[line_number,
  text]`;
* `vars` — real-number variables (`a`..`z`, `a0`..`a9` and `a$`..`z$`
  string variants);
* INPUT works from either a queue (`inq`, scripted by the harness) or
  interactive `feed(ch)` streaming (the terminal path);
* output accumulates in `out` — the OS/the tests read it via `out()`.

## Tokenizer

`tokenize(line)` normalizes identifiers to upper case and produces a token
stream: `["num", n]`, `["str", s]`, `["id", WORD]`, `["sym", c]`,
`["o", ...]`. Numbers include scientific notation (`1E9`), and string
literals use `"..."` (doubled `""` inside for embedded quotes).

## Expression parser (recursive descent)

```
eval_arith -> eval_add ( + - ) with < > via eval_mul
eval_mul       * / ^   (divide-by-zero -> DIVISION BY ZERO;
                        ^ overflow checked before computing)
eval_un        unary minus
eval_atom      numbers, ( ... ), variables, array subscripts, functions
```

Floating-point arithmetic; `INT`, `SQR`, `ABS`, `SGN`, `RND`, `EXP`,
`LOG`, `SIN`, `COS`, `TAN`, `ATN`, `FRE`, `PEEK`, `PDL`, `POS`, `SPC`,
`TAB` are numeric; `ASC`, `CHR$`, `LEFT$`, `RIGHT$`, `MID$`, `LEN`,
`STR$`, `VAL` are string functions. `&` is not an operator — it triggers
the in-line `CALL`-style handling for `&` + hex (Apple II monitor call).

## Statements

| statement | behavior |
|---|---|
| `PRINT` | strings/expressions, `;` and `,` separators, `TAB`/`SPC`, trailing `;`/`,` suppresses CRLF |
| `LET x=expr` / `x=expr` | default assignment when the first token is an identifier |
| `GOTO n` | jump by line number |
| `IF cond THEN stmts` / `IF cond GOTO n` | conditions `= < <= > >= <>`, bare nonzero = true |
| `FOR v=a TO b [STEP s]` | push frame `[name, limit, step, line_index]` |
| `NEXT v` | apply step, reloop while the test holds |
| `INPUT [prompt;]var[,...]` | take from the queue or input prompt |
| `GOSUB n` / `RETURN` | subroutine call/return |
| `ON expr GOTO n1,n2,...` / `ON expr GOSUB ...` | computed branch |
| `READ v[,...]` / `DATA ...` / `RESTORE` | data statements |
| `DEF FN name(x)=expr` | user functions (`FN name(...)`) |
| `DIM name(n)` | arrays (0-based, bounds-checked: BAD SUBSCRIPT) |
| `GET v` | single-character input |
| `POKE addr,val` / `CALL addr` | drive the machine bus (`CALL -151`/`CALL 65449` enter the monitor) |
| `BEEP [freq]` | optional speaker tone |
| `HOME` | clear the terminal (ANSI `ESC[2J ESC[H`) |
| `ONERR GOTO n` / `RESUME` | error trapping |
| `END` / `STOP` | stop the program |
| `REM` | skip comment |

Program editing: `LIST`, `NEW`, `RUN` (with `RUN n` form), `CONT`; a
1,000,000-step guard prevents runaway loops; statements may be separated
by `:` on one line; every program ends silently (no `OK`), idle prompt `]`.

## Errors

Reports match Applesoft shape: `?SYNTAX ERROR IN n`, `?TYPE MISMATCH
ERROR IN n`, `DIVISION BY ZERO`, `?ILLEGAL QUANTITY ERROR`, `OVERFLOW`,
`?UNDEF'D STATEMENT ERROR IN n`, `?NEXT WITHOUT FOR ERROR IN n`, `BAD
SUBSCRIPT`, `OUT OF DATA`, `REDIM'D ARRAY`, `UNDEF'D FUNCTION`. All are
trappable with `ONERR GOTO` (the error code is available for
`RESUME`/conditional handling).

## Program store & persistence shape

* `set_line(n, text)` — sorted insert, or replace same-number lines;
* `find_line(n)` returns content index;
* the OS serializes programs via DOS (`SAVE file`, CRLF-joined lines,
  preserving exact list order — see [docs/os.md](os.md)).

## Test coverage

* `tests/basic/test_basic.sage` — 49 checks (Applesoft expressions,
  control flow, errors, string functions)
* `tests/machine/test_apple2.sage` — 30 checks (DOS verbs, file types,
  monitor shell, `CALL -151`, POKE/PEEK interop)
