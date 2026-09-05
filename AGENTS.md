# Agent instructions — class_cpu

A 16-bit RISC CPU: 5-stage pipeline, Verilog, targeting the EES-331 board
(Xilinx Zynq-7000). Coursework for Digital Logic Design and Applications,
Glasgow College, UESTC.

> **This file is read-only.** Read it, follow it, never edit it. Only a human
> changes these rules. If a rule blocks the task, say so and stop — do not
> rewrite the rule to make the task pass. This applies to every file listed
> under *Entry points* below.

## Entry points

`CLAUDE.md` and `.github/copilot-instructions.md` both point here. This file is
the only copy of the rules; keep it that way rather than duplicating them.

## Layout

```
doc/ISA.md          the instruction set specification — the contract
doc/pre1/           presentation material
src/define_ISA.v    programmer-visible encoding (opcodes, funct, fields)
src/define_ctrl.v   microarchitecture control encoding (muxes, stalls)
src/*.v             one module per file, file name == module name
```

`doc/ISA.md` is the spec and `src/define_ISA.v` is its machine-readable form.
Code follows the spec. If they disagree, fix one of them **in the same commit**.

## The one design rule

**All zeros means nothing happens.** `inst == 16'h0000` is a NOP, `alu_op == 0`
is a NOP, every control signal is active high, and every pipeline register
resets and flushes to zero. Stalling and flushing both work by writing zeros,
so this rule is what makes them correct. Do not add an encoding that breaks it.

## Verilog

- Include both headers, in this order:
  `` `include "define_ISA.v" `` then `` `include "define_ctrl.v" ``
- **No magic numbers.** Every opcode, funct, mux select and stall index has a
  macro. If a literal is needed and has no macro, add the macro.
- Control signals are active high. Reset is `rst_n`, active low, synchronous.
- Sequential logic uses non-blocking `<=` inside `always @(posedge clk)`.
  Combinational logic uses blocking `=` inside `always @(*)`.
- Every `always @(*)` assigns every one of its outputs on every path. No latches.
- 4-space indent, no tabs. Ports one per line. Signals `lower_snake_case`,
  macros `UPPER_SNAKE` or the existing `MixedBus` style for widths.
- No vendor primitives in `src/` — keep the core portable. IP cores and the
  board wrapper live outside it.

## Documentation

Markdown in `doc/`, one file per topic.

- **Tables over prose.** A table beats three paragraphs; use one wherever the
  content is per-instruction, per-signal, or per-field.
- Say the thing once. No restating the question, no summarising what was just
  said, no "it is important to note".
- No hedging and no defensive qualifiers. State what is true; if something is
  uncertain, say what would settle it.
- Every claim about the hardware must be checkable against `src/`. If a number
  is computed, show the computation.
- Headings are a noun or a short phrase, not a sentence.

## Git

- `main` is the only long-lived branch. Never force-push it.
- Commit subject: one imperative line under 60 characters. Then a blank line,
  then *why*, not *what* — the diff already says what.
- Never commit Vivado project files or build output; see `.gitignore`.
- An instruction-set change touches `doc/ISA.md` and `src/define_ISA.v` in the
  same commit, or it does not go in.

## Never

- Move a field position in `define_ISA.v`. The pipeline reads registers before
  it decodes, which only works while `Rs1` and `Rs2` sit at fixed bits.
- Renumber an existing encoding. Reserved space exists for new ones.
- Add an instruction without a one-line comment saying what it does.
