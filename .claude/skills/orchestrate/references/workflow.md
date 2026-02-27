# Smart Delegation Workflow — Reference

## Overview

Claude automatically decides when to delegate bulk code generation to Codex CLI. This workflow is transparent to the user — no manual `/orchestrate` command needed.

---

## Three-Phase Workflow

### Phase A: Analyze (Claude)

**Goal**: Understand requirements and design architecture.

Claude evaluates:
- What is the user asking for?
- Is this well-specified or ambiguous?
- Single component or multi-component system?
- Does this need architecture design or is it implementing a defined spec?

**Outputs**:
- Architecture decisions (if needed)
- API_CONTRACT.md (if multi-component or contract-driven)
- Decision: delegate to Codex vs write myself

---

### Phase B: Execute (Smart Mix)

**Claude writes directly when**:
- Architecture/algorithm design needed
- Code requires deep reasoning
- Task is small (<50 lines)
- Spec is ambiguous

**Claude delegates to Codex when**:
- Clear spec provided (API contract, OpenAPI, interface definitions)
- Repetitive patterns (CRUD routers, React components)
- Bulk code generation (>100 lines)
- Well-defined interface implementation

**Delegation mechanics**:

```bash
# 1. Create isolated workspace
workspace=/tmp/codex-task-$(date +%s)
mkdir -p $workspace && cd $workspace && git init

# 2. Copy contract + Codex skill
cp /path/to/API_CONTRACT.md .
mkdir -p .agents/skills/claude-orchestrated
cp /path/to/.agents/skills/claude-orchestrated/SKILL.md .agents/skills/claude-orchestrated/
git add -A && git commit -m "init"

# 3. Dispatch
codex exec --cd $workspace --full-auto \
  "Implement backend routers per API_CONTRACT.md. Use \$claude-orchestrated skill."
```

**Parallel dispatch** (multiple components):
```bash
codex exec --cd $workspace_backend --full-auto "..." &
codex exec --cd $workspace_frontend --full-auto "..." &
wait
```

**Session reuse** (for fixes):
```bash
cd $workspace
codex exec resume --last --full-auto "Fix: missing GET /api/posts/{id}/comments/"
```

---

### Phase C: Validate (Claude)

**Goal**: Verify correctness and integration.

**Contract validation**:
```bash
bash .claude/skills/orchestrate/scripts/validate-contract.sh \
  API_CONTRACT.md \
  $workspace_backend \
  $workspace_frontend
```

**Review checklist**:
- All contracted endpoints implemented?
- Methods match (GET/POST/etc.)?
- Path parameters consistent?
- Integration tests pass?

**Fix cycle**:
1. If validation fails → use `codex exec resume --last` with targeted fix
2. Re-validate
3. Maximum 2 retry rounds → escalate to user if still failing

---

## Decision Examples

### Example 1: "Build a blog system with CRUD"
- Architecture → **Claude** (system design)
- API_CONTRACT.md → **Claude** (defining standard)
- Backend (5 routers) → **Codex** (repetitive CRUD)
- Frontend (10 components) → **Codex** (repetitive patterns)
- Validation + integration → **Claude** (reasoning)

### Example 2: "Optimize this sorting algorithm"
- **100% Claude** — requires deep algorithmic thinking, no delegation

### Example 3: "Add 8 endpoints matching this OpenAPI spec"
- **100% Codex** — spec already defined, pure generation task
- Claude only validates afterward

---

## Key Optimizations

**Workspace isolation**: Each Codex task gets a minimal git repo (just the contract + skill), reducing input tokens from ~600k to ~16k (97% reduction).

**Session reuse**: `codex exec resume --last` reuses loaded context for fixes without re-scanning.

**Parallel dispatch**: Independent components run simultaneously (backend + frontend in parallel).

---

## Cost Model

**Claude tokens** (what we optimize):
- Smart delegation saves ~93% cache creation, ~22% output tokens
- Based on PoC2: 382k → 26k cache creation tokens

**Codex tokens** (free with ChatGPT Plus):
- Input: ~170-330k per agent (depending on task complexity)
- Output: ~7-9k per agent
- **Cost: $0** (included in Plus subscription)

**Decision threshold**:
- Delegate if: task description <100 tokens, but generation would cost >500 tokens
- Keep if: generation <50 tokens, or requires deep reasoning

---

## Available Tools

- **validate-contract.sh** — Route validation (handles multiline decorators, APIRouter prefixes)
- **measure-tokens.sh** — Measure Claude token usage from session JSONL files
- **api_contract_template.md** — Reusable template for API contracts
