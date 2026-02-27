---
name: orchestrate
description: >
  Smart delegation skill: Claude automatically decides when to delegate bulk code generation
  to Codex CLI (free with ChatGPT Plus) vs doing it itself. Transparent to the user —
  no manual triggering needed. Optimizes Claude token usage by offloading repetitive work.
---

# Smart Delegation — Claude + Codex CLI

## 1. When Does This Activate?

Claude auto-evaluates every code generation request. The user never needs to trigger this manually.

When a user asks for code, Claude internally decides:
- **I need to think deeply** (architecture, algorithms, cross-component reasoning) → I do it myself
- **This is well-specified repetitive work** (CRUD, boilerplate, templates) → delegate to Codex

## 2. Decision Heuristics

### Delegate to Codex when:
- User provided a clear spec (API contract, OpenAPI schema, interface definitions)
- Task contains repetitive patterns (5 similar routers, 10 React components, CRUD endpoints)
- Estimated code output >100 lines
- The task implements an already-defined interface (no architecture decisions needed)
- I can describe the task in <100 tokens, but generating it myself would cost >500 tokens

### Claude does it when:
- Architecture design needed (system layering, tech choices, component boundaries)
- Algorithm design or optimization needed
- Cross-component reasoning required (dependency analysis, impact assessment)
- Spec is ambiguous (needs clarification rounds with user)
- Code is <50 lines (delegation overhead not worth it)
- Task requires reading/understanding existing codebase deeply

## 3. Workflow (Transparent to User)

### Phase A: Analyze (Claude)
- Understand user's request
- Design architecture if needed
- Generate API contract / spec if multi-component

### Phase B: Execute (Smart Mix)
- Core logic, architecture, algorithms → Claude writes directly
- Bulk CRUD, boilerplate, repetitive components → delegate to Codex via `codex exec`
- Each Codex task gets an isolated workspace (minimal git repo with only the contract)

### Phase C: Validate (Claude)
- Run `validate-contract.sh` if contract-driven
- Review Codex output for correctness
- Fix integration issues
- Run tests if available

## 4. Examples

### Example: "Build a blog system"

Claude's internal decision:
1. Architecture design → **Claude** (needs creative thinking)
2. API_CONTRACT.md → **Claude** (defining the standard)
3. Backend CRUD (5 routers) → **Codex** (repetitive, contract is clear)
4. Frontend components → **Codex** (repetitive patterns)
5. Integration + validation → **Claude** (needs reasoning)

### Example: "Optimize this sorting algorithm"

Claude's internal decision:
- Analyze bottleneck → **Claude**
- Design new approach → **Claude**
- Implement → **Claude** (creative, needs precision)
- **No delegation** — this is a thinking task

### Example: "Add 8 REST endpoints matching this OpenAPI spec"

Claude's internal decision:
- Spec already defined → **Codex** (clear contract, bulk generation)
- Validation → **Claude** (verify against spec)

## 5. Technical Implementation

### Calling Codex

```bash
# Create isolated workspace (key optimization: Codex scans entire git repo)
workspace=/tmp/codex-task-$(date +%s)
mkdir -p $workspace && cd $workspace && git init

# Copy contract + Codex skill
cp /path/to/API_CONTRACT.md .
mkdir -p .agents/skills/claude-orchestrated
cp /path/to/.agents/skills/claude-orchestrated/SKILL.md .agents/skills/claude-orchestrated/
git add -A && git commit -m "init"

# Dispatch
codex exec --cd $workspace --full-auto \
  "Implement backend routers per API_CONTRACT.md.
   Use \$claude-orchestrated skill.
   Create routers/ with one file per resource.
   Run pytest after completion."

# Validate
bash /path/to/validate-contract.sh API_CONTRACT.md $workspace
```

### Parallel Dispatch (Multiple Agents)

When delegating backend + frontend simultaneously:
```bash
# Run both in background
codex exec --cd $workspace_backend --full-auto --json "..." &
PID_BACKEND=$!
codex exec --cd $workspace_frontend --full-auto --json "..." &
PID_FRONTEND=$!
wait $PID_BACKEND $PID_FRONTEND
```

### Fixing Issues

```bash
cd $workspace
codex exec resume --last --full-auto \
  "Fix: GET /api/posts/{id}/comments/ is missing. Add it to the posts router."
```

## 6. Cost-Benefit (PoC2 Data)

Based on blog system generation (16 endpoints, backend + frontend):

| Metric | Baseline (Claude only) | Smart Delegation | Savings |
|--------|----------------------|------------------|---------|
| Claude output tokens | 7,533 | 5,892 | -22% |
| Claude cache creation | 382,199 | 25,667 | -93% |
| Claude non-cached input | 382,255 | 25,706 | -93% |
| Claude API calls | 48 | 33 | -31% |

Codex tokens are free (ChatGPT Plus subscription). Only Claude tokens matter for cost.

**Best for**: 2+ components with repetitive patterns and clear specs.
**Not worth it**: Single small task, ambiguous requirements, pure algorithm work.

## 7. Available Scripts

- `scripts/validate-contract.sh` — Verify generated code matches API contract
- `scripts/measure-tokens.sh` — Measure Claude token usage from session JSONL files
- `assets/api_contract_template.md` — Reusable API contract template
- `references/workflow.md` — Detailed workflow reference

---

## 8. Self-Assessment

### After Every Delegation Task

After completing a delegation (Phase C done), append one line to
`.claude/skills/orchestrate/performance_log.jsonl`:

```json
{"timestamp": "<ISO8601>", "task": "<brief description>", "delegated": true, "success": true, "endpoints": 20, "validation": "20/20", "claude_output_tokens": 14166, "claude_api_calls": 77, "codex_agents": 2, "duration_s": 139, "notes": ""}
```

For non-delegated tasks (Claude did it all):
```json
{"timestamp": "<ISO8601>", "task": "<brief description>", "delegated": false, "reason": "small task / ambiguous / algorithm", "claude_output_tokens": 800, "claude_api_calls": 5}
```

Use the Write tool to append — read the file first, add the new line, write it back.

### When to Trigger Self-Evaluation

Do **not** evaluate after every task. Only evaluate when one of these signals appears:

| Signal | Threshold | Action |
|--------|-----------|--------|
| Delegation failed (Codex exit ≠ 0) | 2 consecutive | Alert immediately |
| Validation failure not fixed in 2 retries | Any | Alert immediately |
| Token savings below target | <20% over last 3 delegations | Suggest adjustment |
| New framework/scenario seen for 2nd time | 2 occurrences | Suggest new rule |
| User manually rewrites large chunks of Codex output | Detected | Log as false positive |

If none of these signals are present: **stay silent**, continue working.

### How to Propose an Improvement

When a signal triggers, after completing the user's task, add a brief note:

```
💡 Skill note: [one sentence summary of what was observed]
Suggested improvement: [one sentence of what to change]
Apply? [Y/n]
```

If user says Y: edit SKILL.md directly (use the Edit tool), then append to
`.claude/skills/orchestrate/improvement_history.md`.

If user says N or ignores: drop it, don't repeat next session.

### Improvement Types (in priority order)

1. **New heuristic** — user's project uses a framework/pattern not in Section 2
   → Add a subsection under "Delegate to Codex when" or "Claude does it when"

2. **Exclusion rule** — delegation produced poor output that user had to rewrite
   → Add a named exclusion: "Exception: [task type] — needs deep context"

3. **Threshold adjustment** — token savings consistently below target
   → Adjust the line-count threshold in Section 2 (e.g., >100 lines → >150 lines)

4. **Validator fix** — validate-contract.sh missed real errors
   → Note the gap; fix the script

### What NOT to Suggest

- Don't propose Python classes, scoring engines, or config files
- Don't suggest improvements after a single data point
- Don't evaluate if the task was non-delegated (no delegation = no signal)
- Don't re-suggest a rejected improvement in the same project

### Manual Trigger

User can say: "evaluate orchestrate skill performance" or "how is the skill doing?"
→ Read `performance_log.jsonl`, summarize stats, check for any of the signals above.
