# Command: /smart-commit

## Objective
Stage and commit ONLY relevant, meaningful changes in the repository.

---

## Step 1: Identify Relevant Changes

Include ONLY:
- Source code changes related to the task
- Updates to `.feature` files under `/docs/bdd/features/`
- Updates to documentation under `/docs/bdd/guidelines/`
- Tests related to the feature

---

## Step 2: Ignore Noise (STRICT)

DO NOT stage:
- Logs (`*.log`, debug prints, console dumps)
- Temporary files (`tmp/`, `.cache/`, `.DS_Store`)
- Build artifacts (`dist/`, `build/`, `out/`)
- Secrets (`.env`, API keys, credentials)
- Unrelated file changes
- Pure formatting changes (unless explicitly requested)

---

## Step 3: Security Check (MANDATORY)

Before committing:
- Scan for secrets (tokens, passwords, private keys)
- If found → ABORT commit and notify user

---

## Step 4: Group Changes

Group staged changes into:
- Feature
- Fix
- Refactor
- Docs
- Test

---

## Step 5: Generate Commit Message

Follow this format:

<type>(scope): <short summary>

<detailed explanation>

- What changed
- Why it changed
- Any important context

---

## Examples:

feat(payments): add retry logic with failure handling

- Implemented retry mechanism for transient failures
- Added max retry limit (3 attempts)
- Updated payments.feature with retry scenarios

---

fix(auth): prevent login with invalid password edge case

- Fixed incorrect validation logic
- Added failure scenario in authentication.feature

---

docs(bdd): update guidelines for feature storage structure

- Separated `.feature` and `.md` responsibilities
- Added directory structure rules

---

## Step 6: Execute

Run:
1. Stage only filtered files
2. Show diff to user
3. Commit with generated message

---

## Step 7: Confirmation

Before final commit:
- Show staged files
- Show commit message
- Ask for confirmation (optional if auto-commit enabled)