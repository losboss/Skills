---
name: spec
description: Generates fully fleshed out feature specification documents through interactive Q&A. Use this skill when the user wants to spec out a feature, write a spec doc, plan a new feature before building it, do spec-driven development, or says "let's spec this out", "write a spec for", "spec this feature", "create a feature spec", or "I want to plan this feature". Conducts multi-round Q&A using codebase context to produce a spec doc in docs/specs/ and a task plan in docs/tasks/todo.md.
---

# Spec Skill

Generates a fully fleshed out feature specification through intelligent, codebase-aware Q&A rounds, then outputs a spec doc and task plan.

## Philosophy

A good spec is not a form to fill out — it's a conversation that uncovers what you don't know you don't know. The goal is to surface ambiguity, identify integration points, and make decisions before code is written, not during.

This skill front-loads thinking so implementation is straightforward. Each round of questions builds on previous answers. The codebase is used throughout to ask specific, grounded questions rather than generic ones.

## Process Overview

1. **Codebase orientation** — read the project to understand existing patterns
2. **Seed round** — mission, users, problem, scope
3. **Q&A rounds** (up to 5, soft limit) — domain-specific follow-ups based on answers + codebase
4. **Gap analysis** — holistic review to catch contradictions and missing pieces
5. **Output** — spec doc to `docs/specs/` + task plan to `docs/tasks/todo.md`

---

## Step 1: Codebase Orientation

Before asking anything, read the codebase to build context. This makes every question specific and grounded.

Read or search for:
- `CLAUDE.md` — project overview, architecture, conventions
- `docs/adr/` — existing ADRs to understand prior decisions and domain vocabulary
- Any existing `docs/specs/` files — understand the project's feature history
- Related models, views, API endpoints, and React pages relevant to the feature being specced
- `api/urls.py` — existing URL patterns
- Any investigation notes in `docs/investigations/` that overlap with the feature area

Note the following Unfresh-specific patterns to watch for and ask about:
- **Transmuters** — data transformation layer (`api/transmuters/`) — will this feature need new transmuter fields or a new transmuter?
- **Audit logging** — `activity/audit.py` — what state changes must be audited?
- **Staff roles** — does this feature have staff-only actions? Does it respect the existing `StaffRole` model?
- **Celery queues** — does this involve async processing? Which queue (`default`, `media.orchestrate`, `media.copy`, `media.delete`)?
- **MinIO/S3 storage** — does this involve file uploads or media?
- **Django Channels / WebSockets** — does this need real-time updates?
- **Pre-commit hooks** — does this touch `urls.py`? (will trigger `generate-reverse-ts`)

---

## Step 2: Seed Round

Ask these questions first. They are always asked regardless of feature type. Ask them all at once in a numbered list.

```
I've reviewed the codebase and I'm ready to spec this out. Let's start with the foundation:

1. **Problem** — What problem does this solve, and for whom? Who are the actors (buyer, seller, staff, system)?
2. **User story** — Complete this: "As a [user], I want to [action] so that [outcome]." Add multiple if needed.
3. **Scope** — What is explicitly IN scope for this feature? What is explicitly OUT of scope?
4. **Mission fit** — How does this serve the core marketplace mission? Is this for buyers, sellers, or platform health?
5. **Constraints** — Any hard constraints? (Must reuse X, must not break Y, performance requirements, deadline)
6. **Success criteria** — How will we know this feature is working correctly? What does success look like?
```

Wait for answers before proceeding.

---

## Step 3: Q&A Rounds

Run up to **5 rounds** of follow-up questions. Each round:

1. Review all previous answers
2. Scan relevant code based on what was learned
3. Identify the highest-value gaps in these domains (not all domains apply to every feature):

### Domain Checklist

**Data Model**
- New models or fields needed? What are the field types, constraints, indexes?
- Soft delete (via `deleted_at`) or hard delete?
- Relationships to existing models? (ForeignKey, M2M, OneToOne)
- Does existing data need migration or backfill?
- Any uniqueness constraints?

**API Contract**
- New endpoints or extending existing ones?
- What does the request body look like? What does the response look like?
- Pagination needed?
- Will this need a new transmuter or extend an existing one?
- What URL pattern? (follow existing `api/urls.py` conventions)

**Permissions & Auth**
- Who can read this data? Who can write/update/delete?
- Staff-only actions? Which staff roles?
- Ownership checks? (does `obj.user == request.user` apply?)
- Any rate limiting concerns?

**UI/UX Flow**
- New page, modal, or section within an existing page?
- What does the empty state look like?
- What do loading, error, and success states look like?
- Any form validation? Client-side or server-side or both?
- Mobile considerations?

**Edge Cases & Error States**
- What happens if a required related object doesn't exist?
- Concurrent access — what if two users act on the same resource simultaneously?
- What if the async job fails partway through?
- What are the failure modes, and what does the user see?

**Audit Logging**
- What state changes must be emitted as audit events?
- Who is the `actor` in each case?
- What `metadata` is useful to capture?
- Any failure outcomes that should be audited?

**Async / Background Tasks**
- Does any part of this need to run asynchronously via Celery?
- Which queue? What's the retry strategy?
- What triggers the task? What does it produce?

**Notifications & Real-time**
- Does this need to push updates to connected clients via WebSockets?
- Any email or in-app notifications triggered by this feature?

**Testing**
- What are the critical paths that must have test coverage?
- What external services need mocking? (S3, email, SMS, ClamAV)
- Any edge cases that are especially important to test?

**Integration Points**
- Does this touch the conversation/chat system?
- Does this touch the gallery or media processing pipeline?
- Does this interact with billing/subscriptions?
- Does this require changes to MFA or auth flows?

### Round Format

Group questions by domain. Only ask about domains that are relevant given what you know so far. Aim for 4–8 focused questions per round. Label the round number clearly:

```
**Round 2 of Q&A**

These questions are based on your answers so far and what I found in [relevant files].

**Data model:**
- [specific question based on codebase]

**Permissions:**
- [specific question]

**Edge cases:**
- [specific question grounded in existing patterns]
```

### Deciding Whether to Continue

After each round (starting from round 2), assess:
- Are there unresolved decisions that would block implementation?
- Are there contradictions in the answers so far?
- Are there integration points not yet explored?

If yes to any: continue to the next round.
If no: proceed to gap analysis.

If you reach round 5 and still see value in continuing, say:

```
We've completed 5 rounds of Q&A. I think one more round would help clarify [specific areas].
Want to continue, or shall I proceed to writing the spec with the information we have?
```

---

## Step 4: Gap Analysis

Before writing the spec, do a holistic review of all collected answers:

- Are there contradictions? ("Admin can delete X" but "only the owner can delete X")
- Are there implicit assumptions that need to be made explicit?
- Are there decisions that were skipped that could block implementation?
- Does the scope still make sense given everything learned?

If gaps exist, surface them in a final mini-round:

```
**Gap Analysis — a few things to resolve before I write the spec:**

1. [Specific contradiction or ambiguity]
2. [Missing decision]
```

If no significant gaps: proceed directly to output.

---

## Step 5: Output

### 5a: Spec Document

Create `docs/specs/<kebab-case-feature-name>.md`. If the file already exists, read it first and update rather than overwrite.

Use this structure:

```markdown
# Spec: [Feature Name]

**Status:** Draft
**Date:** [today's date]
**Author:** [inferred or leave blank]
**Related ADR:** [link once ADR is written]

---

## Overview

[2–4 sentence summary of the feature, the problem it solves, and for whom.]

## Mission Fit

[How this feature serves the core marketplace mission. Which user segment benefits.]

## User Stories

- As a [actor], I want to [action] so that [outcome].
- (add all relevant stories)

## Acceptance Criteria

- [ ] [Specific, testable criterion]
- [ ] [Another criterion]
- [ ] (cover all user stories)

## Data Model Changes

[Tables/models being added or modified. Field names, types, constraints, relationships. Note any migrations or backfills needed.]

## API Contract

[For each new or modified endpoint:]

### `METHOD /api/path/`

**Auth:** [required / staff only / public]
**Request:**
\```json
{ "field": "type" }
\```
**Response:**
\```json
{ "field": "value" }
\```
**Errors:** [list error cases]

## Permissions & Authorization

[Who can do what. Ownership checks, staff role requirements, rate limits.]

## UI/UX Flow

[Step-by-step user journey. Empty, loading, error, and success states. Any form validation.]

## Edge Cases & Error Handling

[Failure modes and how the system handles them. Concurrent access scenarios. Async failure handling.]

## Audit Logging

[What events are emitted, what actor/subject/metadata, and under what conditions.]

## Async & Background Tasks

[Any Celery tasks involved. Queue, trigger, retry strategy, output.]

## Notifications & Real-time

[WebSocket events, emails, or in-app notifications triggered by this feature.]

## Testing Strategy

[Critical paths, mocking requirements, edge cases to cover, coverage targets.]

## Out of Scope

[Explicit list of what is NOT included in this feature.]

## Open Questions

[Any unresolved decisions or questions to answer before or during implementation.]

## Implementation Order

[Suggested sequence: e.g., models → migrations → API → frontend → tests]
```

### 5b: Task Plan

Create or update `docs/tasks/todo.md` with an implementation checklist derived from the spec:

```markdown
# [Feature Name] — Implementation Plan

Spec: [link to docs/specs/<name>.md]
Date: [today's date]

## Tasks

### Backend
- [ ] Create/update models (`<app>/models.py`)
- [ ] Write and apply migrations
- [ ] Add transmuter fields or create new transmuter
- [ ] Implement API view(s) (`<app>/api/views/`)
- [ ] Register URL(s) in `api/urls.py`
- [ ] Add audit logging calls
- [ ] Write Celery task(s) if needed
- [ ] Write unit + integration tests

### Frontend
- [ ] Create/update React page or component
- [ ] Add STRINGS constants (`constants.ts`)
- [ ] Wire up API calls
- [ ] Handle loading, error, empty states
- [ ] Write frontend tests

### Infrastructure / Other
- [ ] Update investigation notes if relevant (`docs/investigations/`)
- [ ] Write ADR once implementation is complete (reference this spec)

## Review Section

[Left blank — fill in after implementation]
```

### 5c: Closing Summary

After writing both files, give the user:

```
Spec written to: docs/specs/<name>.md
Task plan written to: docs/tasks/todo.md

**Key decisions made:**
- [bullet summary of the most important decisions]

**Open questions to resolve:**
- [any remaining open questions from the spec]

**Suggested first implementation step:** [most logical starting point]
```

---

## Quality Bar

A good spec produced by this skill should:
- Be specific enough that any engineer could implement it without asking clarifying questions
- Include concrete field names, endpoint paths, and response shapes — not vague descriptions
- Reflect the actual codebase (referencing real model names, existing patterns, real file paths)
- Surface genuine trade-offs rather than glossing over complexity
- Have zero contradictions between sections

If you find yourself writing vague language like "handle errors appropriately" or "implement as needed", stop and make it concrete.
