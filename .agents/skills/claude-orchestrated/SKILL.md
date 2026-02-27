---
name: claude-orchestrated
description: >
  Use this skill when working on a task dispatched by Claude Code's /orchestrate skill.
  Triggers: "orchestrated task", "API contract", "contract-driven development".
  Do NOT use this skill for standalone tasks without an API_CONTRACT.md.
---

# Claude-Orchestrated Task Execution

You are executing a sub-task as part of a Claude Code orchestrated multi-agent workflow.
An API contract has been provided that defines the interface between components.

## Rules (STRICT — violations cause integration failures)

1. **Read API_CONTRACT.md FIRST** before writing any code.
2. **Match endpoint paths EXACTLY** as defined in the contract. Do not rename, reorder parameters, or "improve" paths.
3. **Match request/response schemas EXACTLY**. Field names, types, and nesting must be identical to the contract.
4. **Do not add undocumented endpoints.** If you think an endpoint is missing, add a `// TODO: contract missing endpoint for X` comment — do not invent one.
5. **Do not remove or skip contracted endpoints.** Every endpoint in the contract must have a corresponding implementation.

## Self-Verification Checklist

Before finishing, verify:
- [ ] Every endpoint in API_CONTRACT.md has a matching route definition
- [ ] HTTP methods match (GET/POST/PUT/DELETE)
- [ ] URL paths match character-for-character (including leading/trailing slashes)
- [ ] Request body field names match the contract schema
- [ ] Response body field names match the contract schema
- [ ] Status codes match the contract (if specified)

## Output Format

When you finish, print a summary:
```
=== CONTRACT COMPLIANCE SUMMARY ===
Endpoints implemented: X/Y
Missing endpoints: [list or "none"]
Extra endpoints: [list or "none"]
Schema deviations: [list or "none"]
===================================
```
