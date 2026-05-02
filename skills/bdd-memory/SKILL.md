---
name: bdd-memory-manager
description: Maintain system behavior as structured BDD memory using `.feature` files. Ensures every meaningful behavioral change is captured, deduplicated, and stored for retrieval and reasoning.
license: MIT
---

# BDD Memory Manager

Maintain system behavior as structured `.feature` files under `/docs/bdd/features/`.  
These files act as the **source of truth for system behavior** and a **memory layer for the agent**.

**Tradeoff:** This enforces discipline and consistency over speed. For trivial or non-behavioral changes, use judgment.

---

## 1. Think Before Writing Scenarios

**Don't assume behavior. Derive it. Surface ambiguity.**

Before updating any `.feature` file:

- Identify what behavior actually changed (not just code changes)
- State assumptions if behavior is unclear
- If multiple interpretations exist, DO NOT pick one silently
- If behavior is ambiguous → ask or skip

Ask yourself:
- Is this user-visible or system-observable behavior?
- Is this already captured in an existing scenario?

If unclear → STOP

---

## 2. Simplicity First

**Capture the minimum behavior needed. No speculation.**

- Do NOT invent flows not implied by the change
- Do NOT generalize prematurely
- Do NOT add "future-proof" scenarios
- One scenario = one behavior

Bad: