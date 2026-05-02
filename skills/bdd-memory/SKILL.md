# Skill: bdd_memory_manager

## Purpose
Maintain system behavior as structured BDD memory using `.feature` files.

This skill ensures that every meaningful code or logic change is reflected in `/docs/bdd/features/*.feature`.

---

## When to Trigger

Invoke this skill when ANY of the following occur:

- New feature is implemented
- Existing business logic is modified
- API behavior changes
- Bug fix alters system behavior
- Retry / validation / edge case logic is added

If unsure → TRIGGER the skill

---

## When NOT to Trigger

Do NOT run for:

- Pure refactoring with no behavior change
- Formatting or lint-only changes
- Dependency/version updates
- Comments or documentation-only changes (unless behavior described changes)

---

## Objective

Update or create `.feature` files so they always represent the **latest system behavior**.

---

## Execution Steps

### Step 1: Identify Impacted Feature
- Analyze code changes
- Map them to a logical feature (e.g., auth, payments, search)

---

### Step 2: Locate Feature File
- Path: `/docs/bdd/features/<feature_name>.feature`
- If file does not exist → CREATE it

---

### Step 3: Extract Behavior Changes
Translate code changes into:

- User-visible behavior
- System responses
- Edge cases

---

### Step 4: Check for Existing Scenarios
- Perform semantic comparison with existing scenarios
- If similar exists → UPDATE it
- Else → ADD a new scenario

---

### Step 5: Write Scenarios (STRICT FORMAT)

```gherkin
Feature: <Feature Name>

  @tag1 @tag2
  Scenario: <clear user behavior>
    Given <specific context>
    When <action>
    Then <expected outcome>