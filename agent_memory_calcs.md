---
layout: default
title: "Agentic Memory Scores: Deriving a Governed Retrieval Model"
description: "A source-led derivation of why production agent memory needs eligibility gates, type-specific scores, graph evidence, and budget-aware projection."
date: 2026-02-14
updated: 2026-05-19
permalink: /agent_memory_calcs/
---

# Agentic Memory Scores: Deriving a Governed Retrieval Model

The [Agentic Memory Strategy](../agent_memory/) article argues that agent memory should be managed state: typed records, strict write policy, scoped retrieval, temporal graph context, provenance, forgetting, and evaluation. This article proves the scoring side of that claim.

The case is this:

> A production agent memory system should not rank every memory with one generic similarity score. It should first decide whether the memory is eligible, then score it using the right memory-type contract, then add auditable graph evidence, then project the final set into the prompt budget.

The sources do not hand us one complete formula. Appendix A maps what each source contributes and what we derive from it. Our job is to compose those parts into an operating model: not an academic theory of everything, but an engineering contract that keeps memory useful without turning the prompt into a landfill with embeddings.

## Short version

- **Scores are retrieval utilities, not truth.** A high score means "this eligible memory is likely useful for this task", not "this memory is universally correct".
- **Policy is not a score.** If a memory violates scope, time, sensitivity, or authorisation, it is removed before ranking.
- **Memory types need different score contracts.** Semantic facts, episodes, procedures, identity preferences, operational lessons, and policies answer different questions.
- **Graph is a cross-cutting evidence layer.** It connects users, repos, services, incidents, files, tools, procedures, and decisions across memory types.
- **Prompt budget is a hard constraint.** A ranked list is not enough. The selected memories must fit and must not repeat the same context in five accents.
- **Weights are calibration knobs.** Hand-set weights are acceptable for the first version. Production weights should be learned from task outcomes and human judgement.

The final retrieval shape is:

$$
\Pi_r
=
\operatorname{Project}_{B}
\circ
\operatorname{Rank}_{G,\kappa}
\circ
\operatorname{Gate}_{\Pi_g}
$$

Where:

| Operator    | Job                                                                                  | Source pressure                                      |
| ----------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| `Gate`      | Remove memory that is not allowed, in scope, currently valid, or safe for the actor. | OPA, Cedar, temporal graph memory, data governance   |
| `Rank`      | Score eligible memory using the scorer for its memory type.                          | CoALA, Generative Agents, Reflexion, Mem0, RAG, BM25 |
| `Rank_G`    | Add local graph path evidence and community-level evidence.                          | Zep, Graphiti, GraphRAG, PageRank lineage            |
| `Project_B` | Select a non-redundant subset that fits the prompt-token budget.                     | MMR, practical context-window economics              |

That decomposition is the proof. The rest of the article explains where each part comes from and how to interpret the scores.

## What we are deriving

The retrieval policy maps a memory store, task, actor, time, and token budget to a selected memory set:

$$
\Pi_r(\mathcal{M}, q, a, t, B) \rightarrow R
$$

Where:

| Symbol            | Meaning                                                            |
| ----------------- | ------------------------------------------------------------------ |
| \\(\mathcal{M}\\) | Full memory store                                                  |
| \\(q\\)           | Current task or query                                              |
| \\(a\\)           | Acting principal: user, agent, service identity, or delegated role |
| \\(t\\)           | Logical time                                                       |
| \\(B\\)           | Token budget reserved for retrieved memory                         |
| \\(R\\)           | Selected memory records that enter the prompt or runtime context   |

The selected set must satisfy four invariants:

1. **Eligibility:** every returned memory is allowed for the actor, task, scope, time, and data classification.
2. **Type utility:** each memory type is scored against the question it is meant to answer.
3. **Relational evidence:** graph neighbourhoods and communities can explain why a memory matters beyond text similarity.
4. **Prompt fit:** selected memories must fit a finite budget and avoid redundant context.

Those invariants force the split. If eligibility is folded into a weighted score, a highly similar but unauthorised memory can sneak back into the result. If every type shares one score, a successful procedure, a stale incident, and an explicit user preference are forced onto the same scale. If graph evidence is ignored, the system loses ownership, dependency, causality, and temporal validity. If projection is ignored, the ranking list may be beautiful and still useless because it does not fit.

We have all built one of those systems by accident. It usually starts as "just add vector search" and ends as a small production archaeology programme.

## How to interpret the scores

The scores in this article are operational estimates. They are not universal grades.

| Score or term                       | Interpretation                                                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| \\(\operatorname{Allow}(a,q,m,t)\\) | A hard policy and validity decision. If this is false, the memory has no ranking score because it is not eligible. |
| \\(S\_{\kappa}(m)\\)                | Utility of memory \\(m\\) for the current task under its own memory-type contract.                                 |
| \\(S^{\prime}\_{\kappa}(m)\\)       | Type utility plus graph evidence. This is the main ranking score after eligibility.                                |
| \\(D(q,m)\\)                        | Semantic similarity. Useful for paraphrase and thematic recall. Weak for exact identifiers.                        |
| \\(B(q,m)\\)                        | Normalised lexical match. Useful for exact names, paths, errors, commands, and IDs.                                |
| \\(C(m)\\)                          | Confidence that the memory was extracted, validated, or measured correctly.                                        |
| \\(A(m)\\)                          | Authority of the source. A confirmed architecture decision should outrank a guessed note from a noisy transcript.  |
| \\(F(m,t)\\) or \\(\rho(m,t)\\)     | Freshness or recency, with timestamp semantics chosen by memory type.                                              |
| \\(P_G(q,m,t)\\)                    | Local graph proximity through valid, reliable paths.                                                               |
| \\(K_G(q,m)\\)                      | Community-level graph relevance.                                                                                   |

The practical reading is:

| Range          | Meaning after normalisation                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------------- |
| `0.0` to `0.2` | Little useful evidence for the current task.                                                            |
| `0.3` to `0.6` | Weak, partial, or mixed evidence. This may be useful as supporting context, but it should not dominate. |
| `0.7` to `1.0` | Strong candidate within that memory type for the current task.                                          |

These ranges are guidance, not law. A `0.8` semantic score and a `0.8` procedural score do not mean the same thing. The semantic score says "this fact looks relevant and reliable." The procedural score says "this way of working seems applicable and has earned trust." Cross-type comparison only becomes meaningful after calibration, or inside a final ranker that has been trained against task outcomes.

This is why separate scores matter. They keep interpretation honest. One giant score looks simple until it has to explain why a policy memory, a repo preference, and a failed deployment episode all landed in the same list.

## Production memory as a contract

The strategy article defines memory in prose. The formal version is:

$$
\mathfrak{M}
=
\left(
\mathcal{X},
\Pi_w,
\Pi_r,
\Pi_g,
\mathcal{E}
\right)
$$

| Term               | Meaning                  |
| ------------------ | ------------------------ |
| \\(\mathfrak{M}\\) | Production memory system |
| \\(\mathcal{X}\\)  | Persisted memory state   |
| \\(\Pi_w\\)        | Write policy             |
| \\(\Pi_r\\)        | Retrieval policy         |
| \\(\Pi_g\\)        | Governance policy        |
| \\(\mathcal{E}\\)  | Evaluation process       |

CoALA and the memory survey give us the agent-architecture basis: memory is part of agent state, not just a document store. Mem0 adds the production pressure: extraction, update, retrieval, and evaluation are separate concerns. Schema-grounded memory sharpens the write side: reliable memory starts as structured, validated records. OPA and Cedar add the governance boundary: policy should be evaluated outside the model.

This tuple matters because it prevents a category mistake. A vector database can help implement part of \\(\mathcal{X}\\) and part of \\(\Pi_r\\). It does not implement \\(\Pi_w\\), \\(\Pi_g\\), or \\(\mathcal{E}\\) by itself.

That is the first derivation: if memory is a production subsystem, not a search widget, its retrieval score cannot carry every responsibility.

## Why the one-score model fails

A first version often looks like this:

$$
\operatorname{score}
=
w_s \cdot \operatorname{semantic}
+ w_r \cdot \operatorname{recency}
+ w_a \cdot \operatorname{authority}
+ w_c \cdot \operatorname{confidence}
+ w_u \cdot \operatorname{usefulness}
- w_p \cdot \operatorname{policyRisk}
$$

This shape is familiar. It is a weighted sum over normalised features. Generative Agents uses relevance, importance, and recency as additive retrieval signals. Search systems routinely combine dense, sparse, and metadata features.

The problem is not weighted sums. The problem is putting the wrong things inside them.

Policy risk should not be a negative weight. If a memory is outside tenant scope, outside validity time, or above the actor's clearance, semantic similarity must not rescue it. This is the same reason we do not implement access control by saying "the file is forbidden, but it is very relevant, so let us give it minus 0.2 and see what happens." That road ends in an incident review with too many people on the call.

Memory type is the second problem. A procedure should rank highly when it applies to the current task and has a good outcome history. A semantic fact should rank highly when it is current, authoritative, and relevant. An episode should rank highly when it happened before, matters now, and carries useful outcome evidence. One score hides those differences.

So the production model is:

```text
candidate memory
  -> eligibility gate
  -> type-specific score
  -> graph augmentation
  -> prompt-budget projection
```

The equations below are just the operating details of that split.

## Step 1: Gate before ranking

The first production equation is not a score. It is the eligible memory set:

$$
\mathcal{C}(q,a,t)
=
\left\{
m \in \mathcal{M}
\;:\;
\operatorname{Allow}(a,q,m,t)=1
\land
\operatorname{ScopeAllowed}(a,q,m)=1
\land
b_m \le t < e_m
\land
\operatorname{Sensitivity}(m) \le \operatorname{Clearance}(a)
\right\}
$$

| Term                                                                | Meaning                                                  |
| ------------------------------------------------------------------- | -------------------------------------------------------- |
| \\(\mathcal{C}(q,a,t)\\)                                            | Eligible candidate set                                   |
| \\(\operatorname{Allow}\\)                                          | External authorisation decision                          |
| \\(\operatorname{ScopeAllowed}\\)                                   | User, repo, tenant, organisation, or label compatibility |
| \\(b_m,e_m\\)                                                       | Validity interval for the memory                         |
| \\(\operatorname{Sensitivity}\\) and \\(\operatorname{Clearance}\\) | Data-classification controls                             |

The source derivation is direct:

1. OPA and Cedar model policy as a decision over principal, action, resource, and context.
2. For memory retrieval, the resource is the memory record, the action is "use this memory", and the context includes task, scope, time, and sensitivity.
3. Zep and Graphiti make temporal validity first-class through valid and invalid timestamps.
4. Production tenancy and data classification are hard constraints.

So the gate is Boolean. It does not rank. A memory that fails the gate is not a low-scoring candidate; it is not a candidate.

If a memory has no planned expiry, set \\(e_m = \infty\\). If validity is unknown, do not silently treat it as global truth. Either reduce confidence, require verification, or keep it out of high-risk retrieval paths.

## Step 2: Dispatch by memory type

After eligibility, the scorer is selected by memory type:

$$
S(m \mid q,a,t)
=
S_{\kappa(m)}(m \mid q,a,t)
$$

The indicator form says the same thing more explicitly:

$$
S(m \mid q,a,t)
=
\sum_{k \in \mathcal{K}}
\mathbf{1}[\kappa(m)=k] S_k(m \mid q,a,t)
$$

| Term              | Meaning                 |
| ----------------- | ----------------------- |
| \\(\kappa(m)\\)   | Memory type             |
| \\(\mathcal{K}\\) | Supported memory types  |
| \\(S_k\\)         | Scorer for type \\(k\\) |

CoALA and the memory survey give us the taxonomy pressure. Production systems add policy and operational memory because "what is allowed" and "what went wrong in production" behave differently from facts and episodes.

The useful interpretation is:

| Memory type | Question it answers                                | The score should favour                                      |
| ----------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Semantic    | What is believed to be true now?                   | Relevance, exact match, authority, confidence, freshness     |
| Episodic    | What happened before?                              | Relevance, importance, recency, outcome evidence, confidence |
| Procedural  | How should this work be done?                      | Applicability, success probability, usage, authority         |
| Identity    | How should the agent adapt to this actor or scope? | Preference match, source authority, confidence, stability    |
| Operational | What delivery or production lesson matters here?   | Relevance, severity, impact, outcome, recency                |
| Policy      | Is this allowed?                                   | A hard decision, not a soft score                            |

This is the mathematical version of a boring but necessary engineering rule: do not rank policies, user preferences, incidents, playbooks, and factual claims as anonymous chunks.

## Step 3: Build a small feature library

The type-specific scorers share features, but they use them differently. Before defining each scorer, here is the feature coverage map:

| Feature                    | Semantic | Episodic | Procedural | Identity | Operational | Policy |
| -------------------------- | -------- | -------- | ---------- | -------- | ----------- | ------ |
| D(q,m) semantic similarity | ✓        | ✓        | ✓          |          | ✓           |        |
| B(q,m) lexical match       | ✓        |          | ✓          |          |             |        |
| C(m) confidence            | ✓        | ✓        | ✓          | ✓        | ✓           |        |
| A(m) authority             | ✓        |          | ✓          | ✓        |             |        |
| F(m,t) freshness           | ✓        |          |            |          |             |        |
| ρ(m,t) recency             |          | ✓        |            |          | ✓           |        |
| I(m) importance            |          | ✓        |            |          |             |        |
| O(m) outcome utility       |          | ✓        | ✓          |          | ✓           |        |
| App(q,m) applicability     |          |          | ✓          |          |             |        |
| p_success(m) success rate  |          |          | ✓          |          |             |        |
| U(m) usage                 |          |          | ✓          |          |             |        |
| Match(q,m) preference fit  |          |          |            | ✓        |             |        |
| Stability(m) persistence   |          |          |            | ✓        |             |        |
| Severity(m) risk level     |          |          |            |          | ✓           |        |
| Impact(m) consequence      |          |          |            |          | ✓           |        |

This table clarifies why separate scorers are necessary: each memory type answers a different question and uses different evidence.

### Dense semantic recall

RAG gives us dense retrieval over external memory:

$$
D(q,m)=\cos(E(q),E(m))
$$

Dense similarity is good for paraphrase and thematic recall. It is weak when the task depends on exact identifiers, repository paths, CLI flags, incident IDs, or error codes.

### Sparse lexical recall

BM25 gives exact-term evidence:

$$
\operatorname{BM25}(q,m)
=
\sum_{x \in q}
\operatorname{IDF}(x)
\frac{f(x,m)(k_1+1)}
{f(x,m)+k_1\left(1-b+b\frac{|m|}{\operatorname{avgdl}}\right)}
$$

BM25 is not naturally bounded in \\([0,1]\\), so the scoring model uses a normalised term:

$$
B(q,m)
=
\operatorname{Norm}_{\operatorname{BM25}}
\left(\operatorname{BM25}(q,m)\right)
$$

That normalisation can be a calibrated monotone transform, percentile scaling, or a learned feature transform. The exact choice is implementation detail. The requirement is that raw BM25 must not be added to cosine similarity as if they were on the same scale.

### Freshness and recency

Generative Agents makes recency part of memory retrieval. Production memory needs a sharper timestamp rule:

$$
F(m,t)
=
\exp\left(-\frac{t-u_m}{\tau_{\operatorname{sem}}}\right)
$$

For semantic memory, \\(u_m\\) should usually be the last verification time, not the last access time. A fact can be popular and stale. Anyone who has watched a stale Confluence page survive five migrations knows the feeling.

For episodic memory, recency usually decays from occurrence or last relevant access:

$$
\rho(m,t)
=
\exp\left(-\frac{t-\ell_m}{\tau_{\operatorname{epi}}}\right)
$$

The half-life form is often easier to configure. If the desired half-life is \\(h\\), set \\(\tau=h/\ln 2\\).

### Confidence and authority

Confidence and authority are not the same thing.

$$
C(m) = \operatorname{ConfidenceFromExtractionValidationAndCorroboration}(m)
$$

$$
A(m) = \operatorname{AuthorityFromSourceOwnerAndReviewState}(m)
$$

Schema-grounded memory supports confidence because structured extraction and validation gates tell us how much trust to place in the record. Authority comes from source class: user-confirmed preference, approved ADR, production telemetry, incident postmortem, generated summary, noisy transcript, speculative model note, and so on.

High-confidence extraction from a weak source should not equal a reviewed decision. Likewise, a trusted source can contain old or contradicted facts. Keeping \\(C(m)\\) and \\(A(m)\\) separate gives the scorer room to express that.

### Outcome utility

Reflexion contributes a concrete loop:

```text
trial trajectory -> evaluator feedback -> self-reflection -> memory for later trials
```

We convert that into a governed memory record:

$$
m_{sr,t}
=
\operatorname{ExtractReflectionMemory}
\left(
\tau_t,
y_t,
sr_t,
h_t
\right)
$$

| Reflexion object | Memory field                                  |
| ---------------- | --------------------------------------------- |
| \\(\tau_t\\)     | Episode content, task context, graph entities |
| \\(y_t\\)        | Evaluator result: pass, fail, score, critique |
| \\(sr_t\\)       | Reflection or reusable lesson                 |
| \\(h_t\\)        | External or human correction                  |

Outcome utility can then be:

$$
O(m)
=
\alpha_s \operatorname{EvalPass}(y_m)
+ \alpha_f \operatorname{LessonQuality}(sr_m,y_m)
+ \alpha_h \operatorname{HumanCorrection}(h_m)
$$

This is where failed attempts can still be valuable. A failed deployment with a precise correction may deserve more future attention than a clean run with no lesson.

### Procedure trust

Procedures should not be trusted after one lucky success. A smoothed beta-binomial estimate is safer than a raw success ratio:

$$
\widehat{p}_{\operatorname{success}}(m)
=
\frac{s_m + \alpha}{n_m + \alpha + \beta}
$$

Where \\(s_m\\) is successful evaluated use count, \\(n_m\\) is total evaluated use count, and \\(\alpha,\beta\\) are prior pseudo-counts.

With \\(\alpha=\beta=1\\), a new procedure starts at \\(0.5\\). With larger equal priors, the model becomes more sceptical of early wins. This is useful because production systems have a gift for making the first green build look prophetic.

### Usage

Usage can help, but raw counts are dangerous. Old popular procedures can bulldoze newer, better procedures unless the count is bounded:

$$
U(m)
=
\min\left(
1,
\frac{\log(1+n_{\operatorname{use}}(m))}
{\log(1+n_{\max})}
\right)
$$

Usage means "this has been used", not "this is correct". It should sit beside success, authority, and applicability.

## Step 4: Define type-specific scorers

Every score below assumes features are normalised into \\([0,1]\\) unless stated otherwise. The linear form is deliberately simple and auditable. A learned ranker can replace it later, but the feature contracts should remain visible.

### Semantic memory

Semantic memory answers: what is believed to be true now?

$$
S_{\operatorname{sem}}(m)
=
\lambda_v D(q,m)
+ \lambda_b B(q,m)
+ \lambda_c C(m)
+ \lambda_A A(m)
+ \lambda_f F(m,t)
$$

Source derivation:

| Feature      | Source basis                                                   | Why it belongs                                       |
| ------------ | -------------------------------------------------------------- | ---------------------------------------------------- |
| \\(D(q,m)\\) | RAG                                                            | Semantic recall over external memory                 |
| \\(B(q,m)\\) | BM25                                                           | Exact identifiers and lexical evidence               |
| \\(C(m)\\)   | Schema-grounded memory                                         | Verified records should outrank weak extraction      |
| \\(A(m)\\)   | Provenance and source governance                               | Confirmed sources should outrank speculative notes   |
| \\(F(m,t)\\) | Generative Agents recency plus temporal production constraints | Current truth needs freshness from verification time |

The score means: "this eligible fact looks relevant, exact enough, trusted enough, and current enough for this task."

Graph evidence is added later. That keeps the semantic contract clean: first score the fact itself, then ask whether graph relationships strengthen it.

### Episodic memory

Episodic memory answers: what happened before?

Generative Agents gives the starting point:

```text
episode retrieval = relevance + importance + recency
```

For production agents, an episode also needs outcome and confidence:

$$
S_{\operatorname{epi}}(m)
=
\lambda_r R(q,m)
+ \lambda_i I(m)
+ \lambda_{\rho} \rho(m,t)
+ \lambda_o O(m)
+ \lambda_c C(m)
$$

Source derivation:

| Feature         | Source basis                            | Why it belongs                                       |
| --------------- | --------------------------------------- | ---------------------------------------------------- |
| \\(R(q,m)\\)    | Generative Agents and retrieval systems | The episode must relate to the task                  |
| \\(I(m)\\)      | Generative Agents                       | Some episodes matter more than routine chatter       |
| \\(\rho(m,t)\\) | Generative Agents recency               | Recent experience is often more useful               |
| \\(O(m)\\)      | Reflexion and Mem0 evaluation pressure  | Prior outcomes and corrections are reusable evidence |
| \\(C(m)\\)      | Schema-grounded or summarised memory    | Episode summaries vary in quality                    |

The score means: "this prior experience is relevant, important, recent enough, and has a useful outcome signal."

This is not just chat-history recall. It is evaluated experience.

### Procedural memory

Procedural memory answers: how should this work be done?

$$
S_{\operatorname{proc}}(m)
=
\lambda_a \operatorname{App}(q,m)
+ \lambda_s \widehat{p}_{\operatorname{success}}(m)
+ \lambda_u U(m)
+ \lambda_A A(m)
+ \lambda_c C(m)
$$

Source derivation:

| Feature                                        | Source basis                                    | Why it belongs                                          |
| ---------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------- |
| \\(\operatorname{App}(q,m)\\)                  | CoALA action and memory separation              | A good procedure is useless if it does not apply        |
| \\(\widehat{p}\_{\operatorname{success}}(m)\\) | Reflexion outcome loop, beta-binomial mechanics | Repeated evaluated success should matter                |
| \\(U(m)\\)                                     | Operational practice                            | Used procedures have evidence, but counts need bounding |
| \\(A(m)\\)                                     | Source governance                               | Approved playbooks should outrank inferred habits       |
| \\(C(m)\\)                                     | Validation and extraction reliability           | Weakly inferred procedures should not dominate          |

The score means: "this procedure seems applicable and has earned trust."

This is the clearest reason separate scores are needed. Semantic similarity alone cannot tell whether a runbook actually works.

### Identity memory

Identity memory answers: how should the agent adapt to this user, team, or organisation?

Scope remains a hard gate. The scorer focuses on match, authority, confidence, and stability:

$$
S_{\operatorname{id}}(m)
=
\lambda_m \operatorname{Match}(q,m)
+ \lambda_A A(m)
+ \lambda_c C(m)
+ \lambda_s \operatorname{Stability}(m)
$$

A practical stability estimate is:

$$
\operatorname{Stability}(m)
=
\operatorname{clip}_{[0,1]}
\left(
\frac{\log(1+c_m)}
{\log(1+c_{\max})}
\right)
(1-r_m)
$$

Where \\(c*m\\) is the number of confirmations, \\(c*{\max}\\) is a scaling cap, and \\(r_m\\) is the contradiction rate.

The score means: "this preference or profile fact is relevant to the current task, comes from a good source, and has been stable enough to use."

This prevents one accidental preference from becoming a lifelong character trait. Agents already have enough ways to be annoying.

### Operational memory

Operational memory answers: what has the system learned from delivery or production?

$$
S_{\operatorname{ops}}(m)
=
\lambda_r R(q,m)
+ \lambda_{\operatorname{sev}} \operatorname{Severity}(m)
+ \lambda_{\operatorname{imp}} \operatorname{Impact}(m)
+ \lambda_o O(m)
+ \lambda_{\rho}\rho(m,t)
+ \lambda_c C(m)
$$

Source derivation:

| Feature                          | Source basis                         | Why it belongs                                          |
| -------------------------------- | ------------------------------------ | ------------------------------------------------------- |
| \\(R(q,m)\\)                     | Retrieval systems                    | The incident or delivery lesson must relate to the task |
| \\(\operatorname{Severity}(m)\\) | Operations practice                  | Severe failures deserve attention even when older       |
| \\(\operatorname{Impact}(m)\\)   | Business and reliability practice    | High-impact failures should not be buried               |
| \\(O(m)\\)                       | Reflexion and post-incident learning | Failed attempts and corrections become reusable lessons |
| \\(\rho(m,t)\\)                  | Recency and temporal memory          | Recent failures often signal current risk               |
| \\(C(m)\\)                       | Postmortem and telemetry quality     | Incident notes vary in reliability                      |

The score means: "this production or delivery lesson is relevant and risky enough to influence the current work."

Operational memory is deliberately risk-sensitive. A severe old outage on the same component may deserve more attention than a low-severity warning from yesterday.

### Policy memory

Policy memory is not advice. It should compile into a decision.

$$
\operatorname{Allow}(a,q,m,t)
=
\bigwedge_{j=1}^{n}
\pi_j(a,q,m,t)
$$

OPA and Cedar give the enforcement shape: evaluate policy using principal, action, resource, and context. For memory retrieval, the resource is the candidate memory record.

The score interpretation is simple: there is no score. If policy denies access, the memory is removed before ranking. Deny-override should be the default: one failed predicate is enough to reject the memory for this retrieval.

## Step 5: Add temporal graph evidence

Graph is not an eighth memory type. It is the relational layer that connects records across types.

Zep and Graphiti give the object model:

| Graph object                | What it contributes                                                            | Retrieval field                                           |
| --------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------- |
| Episode                     | Raw conversation, document, tool output, or business event that produced facts | Source evidence for confidence, authority, and provenance |
| Entity node                 | Canonical user, repo, service, incident, file, tool, policy, or decision       | Query seeds and memory nodes                              |
| Fact edge                   | Typed relationship between entities                                            | Relationship evidence                                     |
| `valid_at` and `invalid_at` | Temporal truth interval                                                        | Edge validity gate                                        |
| Hybrid search               | Semantic, keyword, and graph traversal                                         | Candidate paths and neighbourhoods                        |
| Community or cluster        | Related graph neighbourhood                                                    | Community relevance                                       |

At time \\(t\\), the graph contains only valid edges:

$$
G_t = (V,E_t)
$$

$$
E_t=
\{e \in E : b_e \le t < e_e\}
$$

A fact edge becomes:

$$
e =
\left(
u,
r,
v,
b_e,
e_e,
C(e),
A(e)
\right)
$$

Where \\(u\\) and \\(v\\) are entity vertices, \\(r\\) is the relationship type, \\(b_e,e_e\\) are validity bounds, and \\(C(e),A(e)\\) are edge confidence and authority.

The query first resolves seed entities:

$$
V_q=\operatorname{ResolveEntities}(q)
$$

For a path \\(\pi\\) from a query seed \\(s\\) to memory node \\(v_m\\), define path reliability:

$$
\operatorname{RelPath}(\pi,t)
=
\prod_{e \in \pi}
C(e)A(e)\mathbf{1}[b_e \le t < e_e]
$$

Then local graph proximity can be:

$$
P_G(q,m,t)
=
\max_{s \in V_q}
\max_{\pi:s \leadsto v_m}
\operatorname{RelPath}(\pi,t)
\exp\left(-\frac{\operatorname{len}(\pi)}{\tau_g}\right)
$$

The derivation is intentionally practical:

1. Start from query entities.
2. Walk valid paths to the memory node.
3. Multiply confidence and authority along the path.
4. Penalise long chains.
5. Keep the best path as an audit explanation.

In production, compute path reliability in log space to avoid underflow.

GraphRAG adds the other side: community-level context. Some memories matter because they live inside a relevant cluster, even when the single record text is not the closest match.

$$
K_G(q,m)
=
\cos\left(
E(q),
E(\operatorname{Summary}(\operatorname{Community}(v_m)))
\right)
$$

The graph-augmented score is:

$$
S^{\prime}_{\kappa}(m)
=
S_{\kappa}(m)
+ \lambda_p P_G(q,m,t)
+ \lambda_k K_G(q,m)
$$

### Graph-score philosophy

Graph evidence is additive because it answers a different question than base utility. The base score \\(S\_{\kappa}(m)\\) asks "is this memory useful for the task?" Graph evidence asks "is this memory connected to the task through reliable relationships?" A memory can be textually weak but relationally critical (e.g., a sparse incident note on a service the current work depends on).

Additive combination allows both signals to contribute. In practice:

- Use \\(\lambda_p\\) and \\(\lambda_k\\) to weight graph relative to base utility. If \\(\lambda_p=\lambda_k=0\\), the system ignores graph. If they are comparable to the base weights, graph becomes a peer signal.
- When \\(S*{\kappa}(m)\\) is very low but \\(P_G(q,m,t)\\) is high, the augmented score \\(S^{\prime}*{\kappa}(m)\\) can still reach the projection threshold. This is correct: a related but weak record may still be worth explaining.
- Store the best path or community reference used to boost the score. This audit trail is essential: if the system includes a memory, it must be able to explain why, especially when the connection is relational rather than textual.

### Temporal validity and policy eligibility

The gate enforces temporal validity at retrieval time (\\(b_m \le t < e_m\\)). Policy eligibility must be recomputed dynamically: a memory valid at time \\(t_1\\) may become ineligible at time \\(t_2\\) if policy changes.

For example:

- A user loses access to a repository. Any memory tagged with that repo becomes ineligible.
- A security classification changes. Any memory above the new threshold is removed.
- An incident postmortem is archived. Associated operational memory may be excluded from low-risk queries.

Implement this by:

1. Gating before scoring: apply \\(\operatorname{Allow}(a,q,m,t)\\) at retrieval time, not at write time.
2. For scope changes, tag memories by scoped entity (repo, user, tenant) and validate at each retrieval.
3. Separate static validity windows (\\(b_m, e_m\\)) from dynamic policy (user access, sensitivity classification). A memory can be within its validity window but still gated by current policy.

That is our hybrid retrieval proposal:

- keep the type-specific base utility
- add local path evidence
- add community evidence
- keep the path or community reference for audit
- recompute policy eligibility at retrieval time, not write time

Personalised PageRank can replace or supplement \\(P_G\\) when a global graph score is useful:

$$
p
=
(1-\gamma)r
+ \gamma P^{\top}p
$$

For governed memory, explicit paths are often easier to explain than propagated rank mass. If the memory affects an action, being able to show "this was connected through repo -> service -> incident -> rollback note" is worth a lot.

## Step 6: Project into the prompt

Scoring produces candidates. It does not solve the context-window problem.

Let \\(B\\) be the memory-token budget and \\(L(m)\\) be the token length of memory \\(m\\). The ideal selection is:

$$
\begin{aligned}
R^*
&=
\arg\max_{R \subseteq \mathcal{C}}
\left[
\sum_{m \in R} S^{\prime}(m)
-
\delta
\sum_{\substack{i,j \in R \\ i < j}}
\operatorname{sim}(m_i,m_j)
\right] \\
&\text{subject to}
\quad
\sum_{m \in R} L(m) \le B
\end{aligned}
$$

This says:

1. Reward useful memory.
2. Penalise redundant memory.
3. Enforce the token budget.

MMR gives the relevance-versus-novelty idea. The memory adaptation replaces plain relevance with the graph-augmented memory score:

$$
m_i^*
=
\arg\max_{m \in \mathcal{C} \setminus R_{i-1}}
\left[
\alpha S^{\prime}(m)
-
(1-\alpha)
\max_{r \in R_{i-1}}
\operatorname{sim}(m,r)
\right]
$$

At each step, add the best non-redundant eligible memory that still fits:

$$
\sum_{m \in R_i} L(m) \le B
$$

That last line is boring and extremely important. Memory that does not fit into the prompt cannot help the model. It only wins an argument in a dashboard.

### Fallback and partial-fit strategies

When no eligible memory fits the token budget:

1. **Empty fallback:** If \\(B < L(m^_)\\) for all eligible \\(m^_\\), the system has no managed memory to offer. Consider:
   - Returning zero managed memory and letting the model handle the task without it.
   - Escaping to semantic search over the unmanaged store as a last resort (with lower authority weight than managed memories).
   - Surfacing this as an operational signal that the memory store is overloaded or the budget is too tight.

2. **Partial-fit handling:** A high-utility memory \\(m\\) may have \\(L(m) > B\\). Options:
   - Truncate \\(m\\) to fit, preserving high-confidence content (title, key facts) and dropping lower-confidence details.
   - Summarise \\(m\\) on-the-fly if a summariser is available (e.g., extract the key actionable outcome from a long incident postmortem).
   - Skip \\(m\\) and move to the next candidate.
   - Grow \\(B\\) temporarily, accepting reduced space for other memories, if \\(m\\) is sufficiently high-utility.

3. **Semantic and operational redundancy:** The redundancy term \\(\operatorname{sim}(m_i, m_j)\\) detects textual similarity. But two memories can be operationally redundant without textual overlap (e.g., two runbooks that both roll back the same service). If available, tag memories with operational category (rollback, incident, config, architecture) and penalise multiple entries in the same category even if their text diverges.

We must choose a strategy that fits our budget allocation philosophy: conservative (do not project if fit is uncertain), aggressive (truncate and include), or adaptive (adjust budget per query type).

## Step 7: Calibrate from outcomes

The first implementation can be linear and auditable. It should not remain hand-tuned forever.

Given preference pairs \\((m^+,m^-)\\), where \\(m^+\\) was judged more useful than \\(m^-\\) for the same task, learn weights with a pairwise ranking loss:

$$
\mathcal{L}(\theta)
=
\sum_{(m^+,m^-)}
\log\left(
1+\exp\left(
-
\left[
S_{\theta}(m^+)-S_{\theta}(m^-)
\right]
\right)
\right)
+ \lambda \lVert \theta \rVert_2^2
$$

The evaluation set should come from real outcomes:

- human corrections
- task success
- avoided retries
- fewer repeated tool calls
- incidents avoided
- lower latency or cost per successful task
- post-action judgement of whether the retrieved memory helped

Mem0 gives the pressure to evaluate memory by downstream performance. The pairwise loss is our bridge from interpretable first-version formulas to calibrated production ranking.

### Outcome to preference pair mapping

Not all outcomes are equally credible signals. Use this priority when building preference pairs:

1. **Explicit human judgment** (highest credibility): User or reviewer marks memory A as more helpful than memory B for the same task. This is ground truth; collect it whenever possible.

2. **Task outcome + memory presence:** Task succeeded, memory M was retrieved and remained in the context window. This is weak evidence that M contributed. Counterpoint: the task might have succeeded without M. We should use this only when we have high task success rate variance correlated with which memories were retrieved.

3. **Avoided action:** Memory was retrieved, and the model skipped a harmful or redundant step it would normally take. Example: "I was about to query a deprecated API, but the memory showed me the replacement." This requires action-level instrumentation and is harder to detect but reliable when captured.

4. **Cost or latency impact:** Memory reduced tool invocations, API calls, or token usage compared to a baseline. Useful for operational memory tuning. Caveat: correlation with success is not guaranteed.

5. **Indirect signals** (lowest credibility): Task failed but the failure would have been worse without the memory; latency improved; user did not correct the output. These are noisy and should be downweighted in the loss function or used only for weak initial calibration.

**Decision tree for outcome → preference pair:**

```text
IF explicit human judgment
  THEN create preference pair with high weight (w=1.0)
ELSE IF task succeeded AND memory M was retrieved
  THEN create weak preference pair (w=0.5)
  IF memory N was NOT retrieved but could have been relevant
    THEN prefer M > N with w=0.3
ELSE IF avoided harmful action detected
  THEN create strong preference pair (w=0.8)
ELSE IF cost/latency improvement measured
  THEN create weak preference pair (w=0.4)
ELSE
  THEN skip or use very weak signal (w=0.1)
```

**Calibration frequency:** Retrain weights:

- After every 500 tasks if preference pairs are abundant.
- Weekly in production if task volume is high.
- After any major policy or memory schema change.
- If outcome distribution shifts (e.g., task success rate changes), retrain to avoid overfitting to stale patterns.

Keep non-negativity constraints on evidence weights where possible. Relevance, confidence, authority, freshness, outcome utility, and graph evidence should remain interpretable. Policy still stays outside the learned scorer.

## Notation and minor clarifications

**Freshness and recency.** The article uses \\(F(m,t)\\) for semantic freshness and \\(\rho(m,t)\\) for episodic recency. Both decay exponentially over time, but they measure different timestamps:

- \\(F(m,t)\\) decays from the last **verification time** \\(u_m\\), not the last access time. This prevents popular but stale facts from staying fresh indefinitely.
- \\(\rho(m,t)\\) decays from the last **occurrence or relevance time** \\(\ell_m\\), capturing how recently the episode happened.

Use separate names and track the right timestamps. If our system does not yet track verification time separately from extraction time, we must add it. Without it, stale facts win popularity contests.

**Applicability score \\(\operatorname{App}(q,m)\\).** This is defined at line 478 but not detailed in the feature library. Compute it as:

$$
\operatorname{App}(q,m)
=
\cos(E(q), E(m))
$$

or use semantic similarity if task/memory semantic distance is our applicability proxy. For procedural memory, applicability can also be a learned classification: given task features and procedure features, does this procedure apply? If a richer applicability model exists (e.g., precondition checking), use that. The key point is that procedural memory is useless if it does not apply, so applicability is a hard-threshold or major weight contributor.

**Stability formula edge case.** Line 519–524 defines:

$$
\operatorname{Stability}(m)
=
\operatorname{clip}_{[0,1]}
\left(
\frac{\log(1+c_m)}
{\log(1+c_{\max})}
\right)
(1-r_m)
$$

This multiplies confirmation strength by contradiction rate. A memory with 10 confirmations and 2 contradictions (80% stable) scores differently from 1 confirmation and 0 contradictions (100% stable). The question is whether contradiction rate should dominate confirmation count:

- If \\(r_m = 0.2\\) (2 contradictions in 10 trials), the score is 80% of the confirmation strength.
- If \\(r_m = 0\\) (no contradictions), the score is 100% of the confirmation strength.

This is correct: one contradiction in a strongly confirmed memory is meaningful. But operationally, we must consider whether we want to require higher confirmation counts before trusting a preference with contradictions. Add a threshold:

$$
\operatorname{Stability}(m)
=
\begin{cases}
0 & \text{if } r_m > r_{\max} \text{ (too contradictory)} \\
\operatorname{clip}_{[0,1]}\left(\frac{\log(1+c_m)}{\log(1+c_{\max})}\right)(1-r_m) & \text{otherwise}
\end{cases}
$$

This prevents a contradicted preference from recovering through repeated confirmation alone.

## Failure mode gallery

The retrieval pipeline has several archetypal failure modes. Recognizing them helps debug production memory systems.

**All graph, no type distinction.** A system that heavily weights relational evidence \\(P_G\\) and \\(K_G\\) but ignores type-specific utility can return a memory just because it is connected, even if it answers the wrong question. Example: a repo is connected to the current work, so all memories tagged with that repo are retrieved and ranked high, even if they are old policies or failed procedures. Symptom: high redundancy in results, low relevance to specific task type.

**Perfect projection with a broken gate.** A system that nails memory selection under budget but fails eligibility enforcement can leak sensitive data or apply outdated policies. Example: an unauthorised user gets a high-utility memory because the gate was skipped for performance. Symptoms: security incidents, policy violations, user confusion from contradictory advice. Fix: always gate before scoring, never project then filter.

**Calibrated weights, stale training data.** A system that learns weights from task outcomes but retrains infrequently can drift as memory content or user patterns change. Example: weights optimised for 2024 task distribution are applied to 2025 tasks with different risk profiles. Symptoms: declining memory utility over time, scores that feel wrong after major incidents or policy changes. Fix: monitor outcome distribution and retrain monthly or on policy changes.

**One-score-but-more-features.** A system that resists separate type scorers and adds more features to a single score (\\(S = w*1 D + w_2 B + w_3 C + \ldots w*{15} X\\)) becomes a 15-knob tuning nightmare. Weights interact unpredictably, ablation studies fail, and nobody can explain why procedure X scores so high. Symptoms: feature explosion with no interpretability gain, weight conflicts. Fix: respect the type boundary and keep scorers under 5–6 features each.

**No temporal validity.** A system that treats all memories as eternally true can serve stale facts indefinitely. Example: an architecture decision is overridden, but the old memory is never invalidated and keeps influencing design discussions. Symptoms: users asking "isn't this obsolete?" long after it was retired. Fix: enforce \\(b_m\\) and \\(e_m\\) strictly, and update them when policy changes.

**Budget exhausted by a single memory.** A high-utility but long memory consumes the entire projection budget, leaving no room for supporting context. Example: a detailed incident postmortem is so valuable it fills \\(B\\), and no procedural memory fits. Symptoms: over-reliance on single memories, no comparative context. Fix: implement truncation or summarisation for very long memories, or reserve a minimum budget for each memory type.

**Silent failure on missing signals.** A memory type is missing data (e.g., no outcome utility for a procedure). The scorer silently defaults the missing value to zero, which is indistinguishable from "no outcome evidence." Symptoms: procedures with no outcome history score identically to newly invented procedures. Fix: use missingness indicators or explicit defaults with confidence reduction, never silent zeros.

## Retrieval pipeline visual

The memory retrieval process is a composition of gates, dispatchers, scorers, and projection:

```text
Candidate Memory Store
        |
        v
[Gate] -- Filter by eligibility, scope, time, sensitivity
        |
        +-> Ineligible (dropped)
        |
        v
[Dispatch by Type] -- Select scorer for memory type
        |
        +-> Semantic: use dense + lexical + authority + freshness
        |
        +-> Episodic: use relevance + importance + recency + outcome
        |
        +-> Procedural: use applicability + success rate + usage + authority
        |
        +-> Identity: use match + authority + stability
        |
        +-> Operational: use relevance + severity + impact + outcome + recency
        |
        +-> Policy: reject (policy is a gate, not a score)
        |
        v
[Score by Type] -- Compute S_κ(m) for eligible memory
        |
        v
[Graph Augmentation] -- Add path evidence P_G + community evidence K_G
        |
        v
[Rank] -- Sort by S'_κ(m) descending
        |
        v
[Project into Budget] -- MMR: add high-score, non-redundant memories until budget exhausted
        |
        +-> Fallback: if no memory fits, return empty or escape to semantic search
        |
        v
[Return Auditable Memories] -- Include the best path/community reference for each selected memory
```

Each gate failure or scorer mismatch breaks the chain. The diagram makes it clear: policy is a gate, not a score; type dispatch is mandatory, not optional; and projection is a hard constraint, not a soft preference.

The article is not trying to prove that these exact coefficients are universal. They are not. The point is the structure:

```text
hard eligibility
  then type-specific utility
  then temporal graph evidence
  then budget-aware projection
  then outcome calibration
```

Separate scores are necessary because each memory type has a different job:

| Memory type | Correct interpretation of a high score                                |
| ----------- | --------------------------------------------------------------------- |
| Semantic    | This fact is likely relevant, current, and trustworthy for the task.  |
| Episodic    | This past experience is relevant and carries useful outcome evidence. |
| Procedural  | This procedure applies and has earned enough trust to guide action.   |
| Identity    | This preference or profile fact is scoped, stable, and relevant.      |
| Operational | This incident or delivery lesson is relevant and risk-bearing.        |
| Policy      | This action or memory use is allowed, or it is not.                   |

A single score hides those meanings. Separate scores expose them.

The final score \\(S^{\prime}\_{\kappa}(m)\\) should be interpreted as an eligible, type-aware, graph-supported retrieval utility for the current task. It should answer:

```text
Given this actor, this task, this time, and this memory budget,
which memories are safe, useful, explainable, and worth spending prompt tokens on?
```

That is the operating model we need. Not maximum memory. Managed memory.

## Practical implementation rules

| Concern        | Rule                                                                                                                                               |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Feature scale  | Normalise every soft feature before weighting.                                                                                                     |
| Missing values | Use a documented default, a missingness indicator, or route to verification. Do not let missing data quietly mean zero unless that is intentional. |
| Scope          | Enforce scope before scoring.                                                                                                                      |
| Policy         | Keep authorisation, sensitivity, retention, and deny rules outside ranking.                                                                        |
| Freshness      | Use timestamp semantics by type: verification time for semantic facts, occurrence time for episodes, review time for procedures.                   |
| Confidence     | Distinguish extraction certainty from source authority.                                                                                            |
| Graph          | Store the graph path or community evidence used to boost a memory.                                                                                 |
| Projection     | Treat token budget as a hard constraint.                                                                                                           |
| Calibration    | Refit weights from task outcomes, not vibes.                                                                                                       |

The first version can be a linear model. The second can learn weights. The third can use a stronger ranker. But the boundary should remain: gates outside the model, type contracts inside the model, graph evidence as explanation, and projection under budget.

That boundary is the difference between a memory system and a prompt hack with excellent posture.

## Appendix A: Source map

The important distinction: some sources contribute reusable equations, while others contribute architecture constraints. The final model is ours, but each step is traceable.

| Source                                                                                                                                                                                                        | What it gives us                                                                                           | What we derive from it                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [RAG](https://arxiv.org/abs/2005.11401)                                                                                                                                                                       | Dense retrieval over non-parametric memory.                                                                | Dense semantic similarity as one recall signal, not the whole memory system.                                    |
| [BM25](https://doi.org/10.1561/1500000019)                                                                                                                                                                    | Sparse lexical ranking with term frequency, inverse document frequency, and document-length normalisation. | A normalised exact-match signal for IDs, paths, error codes, names, and commands.                               |
| [Generative Agents](https://arxiv.org/abs/2304.03442)                                                                                                                                                         | Retrieval using relevance, importance, and recency.                                                        | Episodic retrieval starts from those signals, but production memory adds scope, outcome, graph, and confidence. |
| [Reflexion](https://arxiv.org/abs/2303.11366)                                                                                                                                                                 | Trial feedback, reflection text, and later policy improvement through memory.                              | Evaluated attempts become episodic, procedural, or operational memory with outcome utility.                     |
| [CoALA](https://arxiv.org/abs/2309.02427) and the [memory survey](https://arxiv.org/abs/2404.13501)                                                                                                           | Modular agent memory and memory taxonomies.                                                                | Memory type becomes a routing variable, not a display label.                                                    |
| [Mem0](https://arxiv.org/abs/2504.19413)                                                                                                                                                                      | Selective memory extraction, update, retrieval, and evaluation against task outcomes.                      | Memory has to earn its place; scores should be calibrated from task outcomes.                                   |
| [Zep](https://arxiv.org/abs/2501.13956), [Zep graph docs](https://help.getzep.com/v2/understanding-the-graph), [Zep facts](https://help.getzep.com/facts), and [Graphiti](https://github.com/getzep/graphiti) | Episodes, entity nodes, fact edges, source evidence, and temporal validity windows.                        | Graph proximity is computed over valid, sourced, confidence-weighted relationships.                             |
| [GraphRAG](https://microsoft.github.io/graphrag/query/overview/)                                                                                                                                              | Local entity search and global community reports.                                                          | We use both local graph path relevance and community-level relevance.                                           |
| [Schema-grounded memory](https://arxiv.org/abs/2604.27906)                                                                                                                                                    | Schema-aware extraction, validation gates, and verified records.                                           | Write-path reliability becomes confidence in retrieval.                                                         |
| [OPA](https://www.openpolicyagent.org/docs) and [Cedar](https://docs.cedarpolicy.com/policies/syntax-policy.html)                                                                                             | Policy decisions over principal, action, resource, and context.                                            | Eligibility is an external hard gate, not a ranking penalty.                                                    |
| [MMR](https://www.cs.cmu.edu/~jgc/publication/The_Use_MMR_Diversity_Based_LTMIR_1998.pdf)                                                                                                                     | Relevance and novelty tradeoff for reranking.                                                              | Prompt projection selects useful and non-redundant memory under a token budget.                                 |
| [Bayes Rules, Chapter 3](https://www.bayesrulesbook.com/chapter-3.html)                                                                                                                                       | Beta-binomial posterior mechanics.                                                                         | Procedure success should use a smoothed estimate, not a raw success ratio.                                      |
| [PageRank](https://research.google/pubs/the-anatomy-of-a-large-scale-hypertextual-web-search-engine/) and [Personalised PageRank surveys](https://arxiv.org/abs/2403.05198)                                   | Graph ranking through propagated relevance.                                                                | Personalised PageRank is an optional global graph-ranking alternative when path-level audit is less important.  |

This map also tells us what not to claim. GraphRAG does not give us a governed agent-memory formula. OPA does not give us a memory ranker. Generative Agents does not solve tenant scope. Mem0 does not tell us to put policy into a weighted sum. We are composing source-backed ideas into one model.

## Source notes

1. Lewis et al., _Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks_, for dense retrieval over non-parametric memory: <https://arxiv.org/abs/2005.11401>
2. Robertson and Zaragoza, _The Probabilistic Relevance Framework: BM25 and Beyond_, for BM25: <https://doi.org/10.1561/1500000019>
3. Park et al., _Generative Agents: Interactive Simulacra of Human Behavior_, for relevance, importance, and recency in memory retrieval: <https://arxiv.org/abs/2304.03442>
4. Shinn et al., _Reflexion: Language Agents with Verbal Reinforcement Learning_, for feedback and reflection improving later attempts: <https://arxiv.org/abs/2303.11366>
5. Sumers et al., _Cognitive Architectures for Language Agents_, for modular memory and agent architecture framing: <https://arxiv.org/abs/2309.02427>
6. Zhang et al., _A Survey on the Memory Mechanism of Large Language Model based Agents_, for memory taxonomy and agent-memory mechanisms: <https://arxiv.org/abs/2404.13501>
7. Chhikara et al., _Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory_, for selective memory management and outcome-oriented evaluation: <https://arxiv.org/abs/2504.19413>
8. Rasmussen et al., _Zep: A Temporal Knowledge Graph Architecture for Agent Memory_, for temporal graph memory: <https://arxiv.org/abs/2501.13956>
9. Zep documentation, _Understanding the Graph_, for entity nodes, entity edges, and episodic nodes: <https://help.getzep.com/v2/understanding-the-graph>
10. Zep documentation, _Facts_, for edge facts, `valid_at`, `invalid_at`, and source episodes: <https://help.getzep.com/facts>
11. Graphiti README, for temporal context graphs, episodes, validity windows, custom ontology, and hybrid retrieval: <https://github.com/getzep/graphiti>
12. Microsoft GraphRAG query documentation, for local search, global search, and community reports: <https://microsoft.github.io/graphrag/query/overview/>
13. Microsoft Research, _Project GraphRAG_, for graph retrieval and community summaries: <https://www.microsoft.com/en-us/research/project/graphrag/>
14. Petrov et al., _From Unstructured Recall to Schema-Grounded Memory_, for schema-grounded records and verified memory writes: <https://arxiv.org/abs/2604.27906>
15. LangChain Deep Agents memory documentation, for practical memory forms and consolidation: <https://docs.langchain.com/oss/python/deepagents/memory>
16. Open Policy Agent documentation, for policy-as-code gate patterns: <https://www.openpolicyagent.org/docs>
17. Cedar policy language documentation, for principal, action, resource, and context policy structure: <https://docs.cedarpolicy.com/policies/syntax-policy.html>
18. Carbonell and Goldstein, _The Use of MMR, Diversity-Based Reranking for Reordering Documents and Producing Summaries_: <https://www.cs.cmu.edu/~jgc/publication/The_Use_MMR_Diversity_Based_LTMIR_1998.pdf>
19. Johnson, Ott, and Dogucu, _Bayes Rules! An Introduction to Applied Bayesian Modeling_, Chapter 3: <https://www.bayesrulesbook.com/chapter-3.html>
20. Brin and Page, _The Anatomy of a Large-Scale Hypertextual Web Search Engine_: <https://research.google/pubs/the-anatomy-of-a-large-scale-hypertextual-web-search-engine/>
21. Wei et al., _Efficient Algorithms for Personalized PageRank Computation: A Survey_: <https://arxiv.org/abs/2403.05198>
