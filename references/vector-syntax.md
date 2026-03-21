# Vector Syntax Reference

Vocabulary and format for vectors.md. The semantic companion to graph.md — where graph.md captures explicit typed relationships, vectors.md captures implicit weighted similarities, concept clusters, and embedding provenance.

---

## Similarity Format

```
[[Node A]] ↔ [[Node B]] | score: 0.XX | basis: <why these are similar>
```

- Scores range from 0.0 (unrelated) to 1.0 (identical)
- `basis` is **required** — no naked scores. Explain why the similarity exists.
- Use ↔ (bidirectional) — similarity is symmetric
- Claude estimates scores based on semantic understanding; actual embeddings override when available

### Score Guidelines

| Range | Meaning |
|---|---|
| 0.9–1.0 | Near-identical concepts, aliases, or restatements |
| 0.7–0.89 | Strong overlap — same domain, similar purpose |
| 0.5–0.69 | Moderate — related but distinct concerns |
| 0.3–0.49 | Weak — tangential connection |
| < 0.3 | Not worth recording |

### Examples

```markdown
[[graph.md]] ↔ [[vectors.md]] | score: 0.72 | basis: both capture inter-concept relationships, but graph.md is explicit/typed and vectors.md is implicit/weighted
[[last.md]] ↔ [[progress.md]] | score: 0.65 | basis: both track recent state, but last.md is high-fidelity window and progress.md is structured milestones
[[decisions.md]] ↔ [[standinginstructions.md]] | score: 0.58 | basis: both record committed positions, but decisions are about choices made and instructions are about behaviour mandated
```

---

## Cluster Format

```
Cluster: <name> → [[[A]], [[B]], [[C]]] | theme: <what unifies them>
```

- Every cluster needs a `theme` — no unnamed groupings
- Clusters can overlap — a node can appear in multiple clusters
- Use clusters for soft grouping where graph edges would be too rigid

### Examples

```markdown
Cluster: recent-context → [[[last.md]], [[progress.md]], [[timeline.md]]] | theme: files that track temporal state and recency
Cluster: append-only → [[[decisions.md]], [[timeline.md]], [[standinginstructions.md]], [[graph.md]]] | theme: files with immutable history — never delete entries
Cluster: identity → [[[preferences.md]], [[assets.md]], [[memory.md]]] | theme: files that define who/what this project is and how to work with it
```

---

## Embedding Registry Format

Track which entities have been embedded, with what model, and where the vectors live.

| Entity | Model | Dimensions | Location | Date | Notes |
|---|---|---|---|---|---|
| `<concept or file>` | `<model name>` | `<dim>` | `<path or URI>` | `<date>` | `<optional>` |

- Registry entries are **append-only** — if an entity is re-embedded, add a new row
- Location can be a file path, database URI, or "in-memory"
- This section remains empty until actual embeddings are computed — it's a registry, not a requirement

### Example

```markdown
| memory.md | all-MiniLM-L6-v2 | 384 | ./vectors/memory.npy | 2026-03-16 | full file content |
| decisions.md | all-MiniLM-L6-v2 | 384 | ./vectors/decisions.npy | 2026-03-16 | per-entry chunks |
```

---

## Rules

- Never record similarities below 0.3 — they add noise, not signal
- Always include `basis` on similarities and `theme` on clusters
- Similarities and clusters are living — update scores and memberships as understanding evolves
- Embedding registry entries are append-only — never delete, even if superseded
- When actual computed embeddings exist, they override Claude's estimated scores
- Cross-reference graph.md — if a strong similarity (>0.8) doesn't have a corresponding graph edge, consider adding one

---

## Nominex Integration Note

vectors.md maps to Nominex's embedding layer:
- Similarity scores → cosine similarity in the vector store
- Clusters → cluster labels from HDBSCAN or manual curation
- Embedding registry → provenance metadata for the vector store

When Nominex ingests a project using this skill, vectors.md entries become seed similarities and cluster labels — manually curated semantic relationships that automated embedding pipelines refine.
