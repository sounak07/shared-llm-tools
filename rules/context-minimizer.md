---
name: context-minimizer
description: Reduce cognitive and codebase complexity by enforcing localized changes, minimal cross-referencing, and self-contained workflows. Ensures tasks require minimal context and produce verifiable outputs.
license: MIT
---

# Context Minimizer

Optimize code and workflows so that every task requires **minimal context**, ideally confined to a single file or module.

**Tradeoff:** Prioritizes simplicity, locality, and clarity over abstraction reuse or architectural generalization.

---

## 1. Think Before Expanding Context

**Do not pull in more files than necessary.**

Before making changes:

- Identify the smallest possible scope (file/module)
- Ask: "Can this be solved within a single file?"
- If multiple files are required → explicitly justify why

If unsure:
→ default to LOCAL change

---

## 2. Simplicity First

**Write the minimum code required. Nothing speculative.**

- No features beyond the request
- No abstractions for single-use logic
- No premature generalization
- No over-engineering

Ask:

> Would a senior engineer consider this overcomplicated?

If yes → simplify

---

## 3. Locality Over Indirection

**Keep logic where it is used.**

- Inline logic if used once
- Avoid creating helper/util files for single usage
- Avoid jumping across modules for simple flows

Bad:

- Logic defined far from usage

Good:

- Logic implemented directly in the feature/module

---

## 4. Surgical Changes Only

**Touch only what is necessary.**

When editing:

- Do NOT refactor unrelated code
- Do NOT change formatting
- Do NOT clean up adjacent logic

Allowed:

- Modify only lines directly tied to the task
- Remove artifacts caused by YOUR changes

Test:

> Every changed line must trace to the task

---

## 5. Single-File Ownership Principle

**A feature change should primarily live in one place.**

- Keep behavior, logic, and configuration close together
- Avoid scattering related logic across files

Ask:

> Can a developer understand this change by reading one file?

If not → restructure locally

---

## 6. Avoid Cross-Referencing

**Understanding should not require multiple files.**

Avoid patterns like:

- “Check file A → then B → then C”

Instead:

- Consolidate logic
- Reduce indirection
- Keep flows self-contained

---

## 7. Modular but Self-Contained

**Modules should be independent, not fragmented.**

- Each module should:
  - Have a clear responsibility
  - Require minimal external context
- Prefer clear boundaries with low coupling

Avoid:

- Tight dependencies across modules

---

## 8. Prefer Simpler Architecture

**Do not introduce complexity unless required.**

- No unnecessary layers
- No premature microservices
- No over-designed systems

Ask:

> Is there a simpler way?

If yes → use it

---

## 9. Co-Locate Changes and Context

**Keep related information together.**

- Logic → near usage
- Config → near feature
- Behavior → near implementation

Avoid:

- Splitting related changes across distant files

---

## 10. Verification Must Be Simple

**Every change must be easy to verify.**

Prefer:

- Small, focused tests
- Clear outputs
- Readable assertions

Avoid:

- Complex setups
- Hard-to-understand validation

---

## 11. Goal-Driven Execution

Transform tasks into verifiable steps:

If verification is unclear:
→ refine approach before proceeding

---

## 12. What NOT to Do

- ❌ Do NOT introduce multi-file changes unnecessarily
- ❌ Do NOT create abstractions without reuse
- ❌ Do NOT scatter logic across modules
- ❌ Do NOT require reading multiple files to understand behavior
- ❌ Do NOT over-engineer solutions

---

## 13. Output Requirements

After completing a task:

### Files Changed

- List all modified files

### Justification

- Explain why each file was necessary

### Context Check

- Confirm that minimal context was used

---

## 14. Fallback Rule

If unsure:

- Default to simpler, more local solution
- Avoid expanding scope
- Ask for clarification if needed

---

## 15. Guiding Principle

> The best solution is the one that can be understood in the fewest files.

---

## Example

### Task:

"Add retry logic to payments API"

### Bad:

- Modify multiple layers
- Add utility files
- Spread logic across modules

### Good:

- Update payment handler directly
- Keep retry logic local (if single-use)
- Modify only necessary file(s)

---

## End of Skill
