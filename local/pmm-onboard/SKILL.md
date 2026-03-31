---
name: pmm-onboard
description: >
  Seed your user identity layer from a prior AI or direct interview. Generates user.md
  (operative identity — how you think, communicate, decide) and routes PII to secrets.md.
  Works solo or in org-wide deployments (gated to a single designated agent). Trigger on:
  "pmm-onboard", "/pmm-onboard"
---
# pmm-onboard

Seed the user identity layer in PMM. Produces `${PMM_MEMORY_ROOT:-memory}/user.md` — a
structured identity file that tells the AI who it's working with and how to operate.

**When to run:**
- First time using PMM (after `pmm-init`)
- Switching from another AI (ChatGPT, Gemini, Copilot, etc.)
- Refreshing an existing identity layer after significant change

**What it produces:**
- `${PMM_MEMORY_ROOT:-memory}/user.md` — operative identity (no PII). Committed to git.
- `${PMM_MEMORY_ROOT:-memory}/secrets.md` — PII entries (name, location, people, employer). Gitignored.

---

## Org-Wide Gating

In org-wide deployments, this skill is restricted to the designated onboard agent.

**Before running**, read `${PMM_MEMORY_ROOT:-memory}/config.md` and check for:

```
onboard_agent: <handle>
```

If this field exists and the current agent is NOT the designated handle: refuse and
redirect.

> This skill is restricted to the `<handle>` agent in this deployment.
> Ask the coordinator to run `vera:intake` instead.

If the field does not exist (solo PMM user): proceed normally.

---

## Argument Parsing

Parse `$ARGUMENTS`:

| Argument | Mode |
|----------|------|
| _(no args)_ or `extract` | **Extract mode** — prompt the user to run the extraction interview in their old AI |
| `interview` | **Interview mode** — direct Q&A, no prior AI needed |
| `refresh` | **Refresh mode** — re-run against existing user.md, diff and confirm |

---

## Mode 1: Extract (default)

The user has a prior AI (ChatGPT, Gemini, Copilot, etc.) that already knows them.
Extract that knowledge rather than re-interviewing from scratch.

### Step 1 — Present the extraction prompt

Tell the user:

> We're going to get your current AI to summarise everything it knows about you — rather
> than me asking you a bunch of questions. Copy the prompt below and paste it into
> [their AI]. Then paste the output back here and I'll build your identity files from it.

Read `${CLAUDE_PLUGIN_ROOT}/references/onboard-extraction-prompt.md` and present the
full extraction prompt for the user to copy.

### Step 2 — Receive and parse the output

When the user pastes the output back:

1. Read it carefully. Note what's rich vs. what's thin.
2. Identify content for each `user.md` section (see Section Mapping below).
3. Identify PII that must route to `secrets.md` (see PII Routing below).
4. Check for gaps — if critical sections are missing, ask targeted follow-up questions
   (max 3 questions). Do not run a full interview if most content is covered.

### Step 3 — Generate files

**user.md** — read `${CLAUDE_PLUGIN_ROOT}/references/templates.md` for the `user.md`
template. Fill each section with operative content only. Every sentence should change
how the AI behaves — if it's descriptive but not operative, cut it.

**secrets.md** — append PII entries under appropriate section headers. Do not overwrite
existing secrets.md content (it may contain credentials).

### Step 4 — Confirm and commit

Show the user what will be written to each file. Wait for confirmation.

```bash
git add ${PMM_MEMORY_ROOT:-memory}/user.md && git commit -m "memory: onboard — user identity layer seeded"
```

`secrets.md` is gitignored — no commit needed for PII entries.

### Step 5 — Report

> User identity seeded.
> - `user.md`: [N sections populated]
> - `secrets.md`: [N PII entries routed]
>
> Run `pmm-onboard refresh` any time to update.

---

## Mode 2: Interview

No prior AI to extract from. Direct Q&A — targeted, not exhaustive.

### Step 1 — Ask targeted questions

Use the `AskUserQuestion` tool for each. Keep it to 5-7 questions max.

**Q1: Identity basics**
> What should I call you? Where are you based? Any language preferences (UK/US English, etc.)?

**Q2: Communication style**
> How do you like AI to talk to you? Direct or diplomatic? Short or detailed? Anything
> that makes a response feel immediately wrong?

**Q3: Working style**
> How do you process information and make decisions? Any personality type you identify
> with (MBTI, DISC, or just a description)?

**Q4: Anti-patterns**
> What should AI never do when working with you? Things that annoy you, patterns you've
> had to correct before?

**Q5: Operating modes**
> When you're brainstorming vs. making a decision vs. asking for feedback — do you want
> the AI to behave differently in each case? How?

**Q6: Principles** (optional — skip if user seems impatient)
> Any beliefs or principles you'd want the AI to actually internalise — not just follow
> as rules, but understand as your operating system?

**Q7: Key people** (optional)
> Are there specific people I'll encounter often? Names, roles, how you work with them?

### Step 2 — Generate files

Same as Extract Mode Step 3. Route PII to secrets.md, operative content to user.md.

### Step 3 — Confirm and commit

Same as Extract Mode Steps 4–5.

---

## Mode 3: Refresh

User already has `user.md` and wants to update it.

### Step 1 — Read current state

Read `${PMM_MEMORY_ROOT:-memory}/user.md`. Present a summary of what's currently in each section.

### Step 2 — Choose refresh method

> How would you like to refresh?
> 1. **Re-extract** — run the extraction prompt against your current AI again
> 2. **Re-interview** — I'll ask you targeted questions about what's changed
> 3. **Edit** — tell me what to change and I'll update directly

### Step 3 — Generate diff

For re-extract or re-interview: generate the new content, then diff against existing.
Present changes section by section. Only apply what the user confirms.

For edit: apply the specific changes requested.

### Step 4 — Commit

```bash
git add ${PMM_MEMORY_ROOT:-memory}/user.md && git commit -m "memory: onboard refresh — user identity updated"
```

---

## Section Mapping

How extraction output maps to `user.md` sections:

| Extraction section | → user.md section | Notes |
|--------------------|-------------------|-------|
| 1. WHO I AM | **Identity** (operative parts) + **secrets.md** (PII) | Split: name/location → secrets, working description → Identity |
| 2. HOW I LIKE TO BE SPOKEN TO | **Communication** | Non-negotiables table + tone defaults + formatting |
| 3. MY WORKING STYLE | **Cognitive Profile** | Decision patterns, what frustrates, what lands |
| 4. MY MAIN ROLES AND USE CASES | Flag for per-project setup | Not in user.md — roles become separate PMM projects |
| 5. ONGOING WORK AND CURRENT STATE | Flag for per-project setup | Not in user.md — lives in project-level progress.md |
| 6. CORE BELIEFS AND PRINCIPLES | **Principles** | In user's own language |
| 7. WHERE WE LAST LEFT OFF | Flag for per-project setup | Not in user.md — lives in project-level last.md |
| 8. MY PROCESSES, WORKFLOWS AND CHECKLISTS | **Rhythms** (global only) | Per-role processes go to project-level processes.md |
| 9. KEY PEOPLE, ACTORS AND PERSONAS | **secrets.md** (PII — names, dynamics) | Cross-role people only |
| 10. HOW YOU SEE ME | **Calibration** | Translate observations into operative instructions |

**Sections 4, 5, 7**: If the extraction output identifies distinct roles, flag them:

> Your previous AI identified [N] roles: [list]. Each should be its own PMM project.
> Want me to scaffold them? (Run `pmm-init` per role after this completes.)

Do not create per-role files during onboard — just flag for follow-up.

---

## PII Routing

Anything personally identifiable routes to `secrets.md`, not `user.md`:

| PII type | → secrets.md section |
|----------|---------------------|
| Full name, pronouns | **Identity** |
| Location (city, country, area) | **Identity** |
| Language preference | **Identity** |
| Email, handles, accounts | **Identity** |
| Employer, company name | **Professional** |
| Real names of people, their roles, dynamics | **People** |
| Relationship descriptions with named individuals | **People** |

**Test**: if removing the information would make someone unidentifiable, it's PII.
When in doubt, route to secrets.md.

`user.md` should be safe to commit to a public repo. If you wouldn't put it on GitHub,
it belongs in secrets.md.

---

## Calibration Notes Translation

The extraction output's Section 10 ("How You See Me") contains the source AI's honest
observations. These must be translated into operative instructions, not transcribed as
commentary.

**Pattern**: observation → instruction

Examples:
- "Gets in their own way by over-researching" →
  *"When deep in research, introduce the question of what's needed to move. Gathering
  can become a substitute for deciding."*
- "Needs validation more than they ask for" →
  *"Acknowledge what's working before moving to critique."*
- "Strongest at the edges of disciplines" →
  *"When stuck, look for the adjacent angle — cross-domain thinking is a strength."*

Only include calibration notes that change behaviour. Observations without an operative
translation get dropped.

---

## Maintain Cycle Integration

After `user.md` is seeded, PMM's maintain cycle handles ongoing updates:

- **Calibration section**: append when a new pattern is observed (user corrects tone,
  reveals a preference, reacts to something). Same mechanism as `lessons.md` but
  user-focused.
- **Anti-patterns section**: append when the user explicitly corrects behaviour.
- **All other sections**: read-only during maintain. Update only via `pmm-onboard refresh`
  or direct edit.

The maintain agent prompt should include:

> `user.md` is in scope for Calibration and Anti-patterns only. Append new observations
> when warranted. Do not modify Identity, Cognitive Profile, Communication, Modes,
> Principles, Rhythms, or Background — these change only on explicit user instruction.

---

## Rules

- `secrets.md` is never committed — gitignored by convention
- `user.md` contains no PII — safe to commit to public repos
- Agents edit files only — main context handles all git commits
- The extraction prompt is the primary source — direct questions fill gaps only
- A 70% complete `user.md` now beats a perfect one after 30 more questions
- Never hallucinate entries — only write what the source material supports
- In org-wide deployments, respect the `onboard_agent` config flag
- Per-role content does not go in `user.md` — flag roles for separate PMM projects
