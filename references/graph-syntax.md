# Graph Syntax Reference

Vocabulary for typed edges in graph.md. Use these consistently so Claude can reason about relationship types.

---

## Edge Format

```
[[Node A]] → relationship-type → [[Node B]]
```

Always use typed relationships. Never write bare `[[Node A]] → [[Node B]]` without a label.

---

## Relationship Types

### Structural
| Edge | Meaning |
|---|---|
| `is-a` | Node A is a type of Node B |
| `part-of` | Node A is a component of Node B |
| `contains` | Node A contains Node B |
| `extends` | Node A builds on or extends Node B |
| `implements` | Node A is an implementation of Node B |

### Causal / Dependency
| Edge | Meaning |
|---|---|
| `depends-on` | Node A requires Node B to function |
| `blocks` | Node A prevents Node B from proceeding |
| `enables` | Node A makes Node B possible |
| `triggers` | Node A causes Node B to happen |
| `fixes` | Node A resolves the problem in Node B |

### Semantic
| Edge | Meaning |
|---|---|
| `related` | Loose association — use when no stronger type fits |
| `similar-to` | Node A and Node B are analogous |
| `contrasts-with` | Node A and Node B are in tension or opposition |
| `replaces` | Node A supersedes Node B |
| `inspired-by` | Node A was shaped by Node B |

### Epistemic (maps to Nominex authority model)
| Edge | Meaning |
|---|---|
| `ratified-by` | Node A was confirmed by Node B (person or process) |
| `inferred-from` | Node A was derived from Node B |
| `contradicts` | Node A conflicts with Node B — hold in tension |
| `supersedes` | Node A overrides the previous state of Node B |

### Operational
| Edge | Meaning |
|---|---|
| `uses` | Node A uses Node B as a tool or resource |
| `writes-to` | Node A produces output to Node B |
| `reads-from` | Node A consumes input from Node B |
| `owned-by` | Node A belongs to or is maintained by Node B |
| `status` | Node A has current status Node B |

---

## Example graph.md Entries

```markdown
## Project Structure
[[Nominex]] → is-a → [[Memory Infrastructure]]
[[Nominex]] → part-of → [[Claude Ecosystem]]
[[Enricher]] → part-of → [[Nominex]]
[[Embedder]] → part-of → [[Nominex]]
[[all-MiniLM-L6-v2]] → used-by → [[Embedder]]
[[sqlite-vec]] → used-by → [[Embedder]]

## Dependencies
[[Open Source Launch]] → depends-on → [[Phase 3a]]
[[Transport Abstraction]] → blocks → [[Open Source Launch]]
[[Phase 3c]] → fixes → [[Historical Message Retrieval Problem]]
[[Actor Model]] → enables → [[Shared Memory]]

## Decisions
[[SQLite]] → ratified-by → [[Architecture Decision 2026-03]]
[[Claude Agent SDK]] → replaces → [[Direct API Calls]]
[[all-MiniLM-L6-v2]] → supersedes → [[Keyword Matching]]

## Concepts
[[Poor Man Memory]] → inspired-by → [[Felix Memory System]]
[[Felix Memory System]] → similar-to → [[Nominex Semantic Layer]]
[[Tessa]] → demonstrates → [[Metacognition]]
[[Hindsight]] → contrasts-with → [[Nominex]] # per-agent vs shared memory

## People & Orgs
[[Nat Eliason]] → owns → [[Felix]]
[[Nicolò Boschi]] → maintains → [[Hindsight OpenClaw Integration]]
[[Anthropic]] → target-for → [[Acquisition Strategy]]
```

---

## Graph Traversal

When the user asks "how does X relate to Y", Claude should:
1. Find both nodes in graph.md
2. Follow edges in both directions
3. Report the path and edge types connecting them
4. If no path exists, say so — don't invent relationships

When building context for a decision, Claude should:
1. Find the relevant decision node
2. Follow `depends-on`, `blocks`, `enables` edges to surface constraints
3. Follow `ratified-by` edges to surface authority
4. Follow `contradicts` edges to surface tensions to resolve

---

## Nominex Integration Note

This graph.md format maps directly to Nominex's memory node model:
- Node names → entity nodes in the semantic layer
- Edge types → typed graph edges in NetworkX/Kuzu
- `ratified-by` → Ratified authority status
- `inferred-from` → Inferred authority status
- `contradicts` → Contested node pairs

If Nominex is ever pointed at a project using this skill, graph.md entries can be imported as high-confidence seed nodes — manually curated relationships become the ratified layer that automated enrichment builds on top of.

See also `references/vector-syntax.md` — vectors.md is the semantic companion to graph.md, capturing weighted similarities and clusters where typed edges would be too rigid.
