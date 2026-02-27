# claude-codex-skill

A Claude Code skill that **automatically delegates bulk code generation to Codex CLI** (free with ChatGPT Plus), reducing Claude token usage by ~43% while maintaining full code quality. Transparent to the user — no manual commands needed.

> Research and PoC results: [claude-codex-research](https://github.com/EpocheDrift/claude-codex-research)

---

## How It Works

When you ask Claude Code to build something, it internally decides:

- **Needs thinking** (architecture, algorithms, ambiguous spec) → Claude does it
- **Repetitive + clear spec** (CRUD routes, React components, boilerplate) → delegates to Codex

Codex runs in an isolated workspace (minimal git repo with just the API contract), generates the code, and Claude validates the result. You see none of this — it just works.

**PoC3 result**: task management API, 20 endpoints, FastAPI + React
→ 1,253 LOC generated in 139s, 20/20 contract compliance, -43% Claude output tokens vs doing it alone.

---

## Install

### Option A — Extract into your project (recommended)

```bash
cd /your/project
curl -L https://github.com/EpocheDrift/claude-codex-research/raw/main/claude-codex-skill.tar.gz \
  | tar -xz
```

### Option B — Clone and copy

```bash
git clone https://github.com/EpocheDrift/claude-codex-skill.git /tmp/skill
cp -r /tmp/skill/.claude /tmp/skill/.agents /your/project/
rm -rf /tmp/skill
```

Either way, two directories land in your project root:

```
your-project/
├── .claude/skills/orchestrate/     ← Claude Code reads this automatically
└── .agents/skills/claude-orchestrated/  ← Codex reads this in isolated workspaces
```

---

## Prerequisites

| Requirement | How to get it |
|-------------|---------------|
| Claude Code CLI | `npm i -g @anthropic-ai/claude-code` |
| Codex CLI | `npm i -g @openai/codex` |
| Codex login | `codex login` (uses ChatGPT Plus — no API key needed) |
| Python 3 | Already on macOS/Linux; used by validator + token meter |

---

## What's Included

```
.claude/skills/orchestrate/
├── SKILL.md                     ← Core: decision heuristics, workflow, self-assessment
├── performance_log.jsonl        ← Delegation outcomes (auto-updated by Claude)
├── improvement_history.md       ← Skill changes over time (auto-updated by Claude)
├── scripts/
│   ├── validate-contract.sh     ← Verify backend + frontend match API contract
│   └── measure-tokens.sh        ← Compare Claude token usage across sessions
├── assets/
│   └── api_contract_template.md ← Template for defining API contracts
└── references/
    └── workflow.md              ← Detailed workflow reference

.agents/skills/claude-orchestrated/
└── SKILL.md                     ← Instructs Codex to read API contract and self-verify
```

---

## Usage

Nothing to invoke manually. Just use Claude Code normally:

```
"Build a task management API with FastAPI and React"
"Add CRUD endpoints for products and orders"
"Generate React components for all the routes in this spec"
```

Claude will delegate to Codex when appropriate. The only visible difference is that bulk generation completes faster and uses fewer Claude tokens.

### Measure token savings

```bash
# Find your session files
ls -t ~/.claude/projects/$(basename $(pwd))/*.jsonl | head -3

# Compare two sessions
bash .claude/skills/orchestrate/scripts/measure-tokens.sh \
  ~/.claude/projects/.../session1.jsonl \
  ~/.claude/projects/.../session2.jsonl
```

### Validate generated code against contract

```bash
bash .claude/skills/orchestrate/scripts/validate-contract.sh \
  API_CONTRACT.md backend/ frontend/
```

---

## Self-Improvement

The skill tracks its own performance in `performance_log.jsonl`. When it detects a pattern worth improving (repeated failures, new framework seen twice, sustained low token savings), it proposes a targeted edit to `SKILL.md` and asks for confirmation before applying. All changes are logged in `improvement_history.md`.

To check performance manually:
```
"evaluate orchestrate skill performance"
```

---

## Updating the Skill

After Claude self-improves (edits `SKILL.md`), push the update back:

```bash
git add .claude/skills/orchestrate/
git commit -m "skill: <what changed>"
git push
```

To pull the latest skill into an existing project:

```bash
# From inside your project
git -C /tmp/skill-update clone https://github.com/EpocheDrift/claude-codex-skill.git .
cp -r /tmp/skill-update/.claude /tmp/skill-update/.agents .
rm -rf /tmp/skill-update
```
