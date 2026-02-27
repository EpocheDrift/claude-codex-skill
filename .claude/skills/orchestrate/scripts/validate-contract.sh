#!/usr/bin/env bash
#
# validate-contract.sh — Validate that generated code matches the API contract.
#
# Usage:
#   validate-contract.sh <API_CONTRACT.md> <backend_dir> [frontend_dir]
#
# Checks:
#   1. Extracts endpoint definitions from API_CONTRACT.md
#   2. Scans backend router files for route decorators, resolving prefixes
#   3. Scans frontend api client for fetch/axios paths
#   4. Reports: matched / mismatched / missing endpoints

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CONTRACT="${1:?Usage: validate-contract.sh <API_CONTRACT.md> <backend_dir> [frontend_dir]}"
BACKEND_DIR="${2:?Usage: validate-contract.sh <API_CONTRACT.md> <backend_dir> [frontend_dir]}"
FRONTEND_DIR="${3:-}"

if [ ! -f "$CONTRACT" ]; then
  echo -e "${RED}ERROR: Contract file not found: $CONTRACT${NC}"
  exit 1
fi

echo "=== CONTRACT VALIDATION ==="
echo "Contract: $CONTRACT"
echo "Backend:  $BACKEND_DIR"
[ -n "$FRONTEND_DIR" ] && echo "Frontend: $FRONTEND_DIR"
echo ""

# --- Step 1: Extract endpoints from contract ---
CONTRACT_ENDPOINTS=$(grep -oEi '(GET|POST|PUT|DELETE|PATCH)\s+/[a-zA-Z0-9/_{}:.-]+' "$CONTRACT" \
  | tr '[:lower:]' '[:upper:]' \
  | sed 's/  */ /' \
  | sort -u)

if [ -z "$CONTRACT_ENDPOINTS" ]; then
  echo -e "${YELLOW}WARNING: No endpoints found in contract. Check the format.${NC}"
  exit 0
fi

CONTRACT_COUNT=$(echo "$CONTRACT_ENDPOINTS" | wc -l | tr -d ' ')
echo "Found $CONTRACT_COUNT endpoints in contract:"
echo "$CONTRACT_ENDPOINTS" | sed 's/^/  /'
echo ""

# --- Step 2: Extract routes from backend (with prefix resolution) ---
TMPFILE="/tmp/validate_backend_routes_$$.tmp"
: > "$TMPFILE"

if [ -d "$BACKEND_DIR" ]; then
  # Python (FastAPI/Flask): resolve APIRouter prefix + @router.method("/path")
  for pyfile in $(find "$BACKEND_DIR" -name "*.py" 2>/dev/null); do
    # Extract prefix from APIRouter(prefix="...")
    PREFIX=$(grep -oE 'APIRouter\s*\(\s*prefix\s*=\s*"[^"]*"' "$pyfile" 2>/dev/null \
      | sed -E 's/.*prefix\s*=\s*"([^"]*)".*/\1/' | head -1 || true)
    [ -z "$PREFIX" ] && PREFIX=""

    # Extract route decorators - handles both single-line and multiline
    # Use python3 with env vars (avoids positional arg being treated as script path)
    PYFILE="$pyfile" PYPREFIX="$PREFIX" python3 << 'PYEOF' >> "$TMPFILE" 2>/dev/null || true
import os, re
pyfile = os.environ['PYFILE']
prefix = os.environ['PYPREFIX']
with open(pyfile) as f:
    content = f.read()
# Match decorators across multiple lines: @router.get(\n    "/path",\n)
pattern = r'@(router|app)\.(get|post|put|delete|patch)\s*\(\s*["\']([^"\']+)["\']'
for match in re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE):
    method = match.group(2).upper()
    path = match.group(3)
    full_path = (prefix + path).replace('//', '/')
    print(f"{method} {full_path}")
PYEOF
  done

  # Node.js (Express): router.get("/path"), app.post("/path")
  for jsfile in $(find "$BACKEND_DIR" \( -name "*.js" -o -name "*.ts" \) 2>/dev/null); do
    MATCHES=$(grep -oEi "(router|app)\.(get|post|put|delete|patch)\s*\(\s*['\"]([^'\"]*)['\"]" "$jsfile" 2>/dev/null || true)
    if [ -n "$MATCHES" ]; then
      echo "$MATCHES" | while IFS= read -r match; do
        METHOD=$(echo "$match" | sed -E 's/(router|app)\.(get|post|put|delete|patch).*/\2/I' | tr '[:lower:]' '[:upper:]')
        PATH_PART=$(echo "$match" | sed -E "s/.*\(\s*['\"]([^'\"]*)['\"].*/\1/")
        echo "${METHOD} ${PATH_PART}"
      done >> "$TMPFILE"
    fi
  done
fi

BACKEND_ROUTES=$(cat "$TMPFILE" 2>/dev/null | tr '[:lower:]' '[:upper:]' | sort -u | grep -v '^$' || true)
rm -f "$TMPFILE"

BACKEND_COUNT=0
if [ -n "$BACKEND_ROUTES" ]; then
  BACKEND_COUNT=$(echo "$BACKEND_ROUTES" | wc -l | tr -d ' ')
fi
echo "Found $BACKEND_COUNT routes in backend:"
[ -n "$BACKEND_ROUTES" ] && echo "$BACKEND_ROUTES" | sed 's/^/  /'
echo ""

# --- Step 3: Extract API paths from frontend ---
FRONTEND_PATHS=""
if [ -n "$FRONTEND_DIR" ] && [ -d "$FRONTEND_DIR" ]; then
  # Write a python helper to a temp file (avoids heredoc quoting issues with backticks)
  PY_FRONTEND="/tmp/validate_frontend_$$.py"
  cat > "$PY_FRONTEND" << 'PYEOF'
import re, sys
files = [f.strip() for f in sys.stdin.read().strip().split('\n') if f.strip()]
paths = set()
# Match string literals with /api/ paths: single/double quote or backtick prefix
pattern = re.compile(r"[\"'`]/api/[a-zA-Z0-9/_{}$:.-]+")
template_var = re.compile(r"\$\{[^}]+\}")
for f in files:
    try:
        content = open(f).read()
        for m in pattern.finditer(content):
            raw = m.group().lstrip("\"'`")
            normalized = template_var.sub("*", raw).rstrip("\"'`")
            if normalized.startswith("/api/"):
                paths.add(normalized.upper())
    except Exception:
        pass
for p in sorted(paths):
    print(p)
PYEOF

  FRONTEND_PATHS=$(find "$FRONTEND_DIR" \
    \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    | python3 "$PY_FRONTEND" 2>/dev/null || true)
  rm -f "$PY_FRONTEND"
fi

FRONTEND_COUNT=0
if [ -n "$FRONTEND_PATHS" ]; then
  FRONTEND_COUNT=$(echo "$FRONTEND_PATHS" | wc -l | tr -d ' ')
fi
[ -n "$FRONTEND_DIR" ] && echo "Found $FRONTEND_COUNT API paths in frontend:"
[ -n "$FRONTEND_PATHS" ] && echo "$FRONTEND_PATHS" | sed 's/^/  /'
[ -n "$FRONTEND_DIR" ] && echo ""

# --- Step 4: Compare ---
# Normalize: convert path params like {post_id} and :id to a common placeholder *
normalize_path() {
  echo "$1" | sed -E 's/\{[^}]+\}/*/g; s/:[a-zA-Z_]+/*/g'
}

echo "=== COMPARISON RESULTS ==="

MATCH=0
MISSING_BACKEND=0
MISSING_FRONTEND=0
MISSING_BACKEND_LIST=""
MISSING_FRONTEND_LIST=""

while IFS= read -r endpoint; do
  METHOD=$(echo "$endpoint" | awk '{print $1}')
  ROUTE=$(echo "$endpoint" | awk '{print $2}')
  NORM_ROUTE=$(normalize_path "$ROUTE")

  # Check backend: normalize both sides and compare
  BACKEND_MATCH=false
  if [ -n "$BACKEND_ROUTES" ]; then
    while IFS= read -r br; do
      BR_METHOD=$(echo "$br" | awk '{print $1}')
      BR_PATH=$(echo "$br" | awk '{print $2}')
      BR_NORM=$(normalize_path "$BR_PATH")
      if [ "$METHOD" = "$BR_METHOD" ] && [ "$NORM_ROUTE" = "$BR_NORM" ]; then
        BACKEND_MATCH=true
        break
      fi
    done <<< "$BACKEND_ROUTES"
  fi

  # Check frontend: use normalized path (params -> *) to match against extracted paths
  FRONTEND_MATCH=false
  if [ -n "$FRONTEND_PATHS" ]; then
    # NORM_ROUTE already has {param} -> * substitution applied
    # Frontend paths also use * for dynamic segments (from python extraction)
    # Compare normalized contract path against each frontend path
    while IFS= read -r fp; do
      FP_NORM=$(normalize_path "$fp")
      if [ "$NORM_ROUTE" = "$FP_NORM" ]; then
        FRONTEND_MATCH=true
        break
      fi
    done <<< "$FRONTEND_PATHS"
  fi

  if $BACKEND_MATCH; then
    if [ -z "$FRONTEND_DIR" ] || $FRONTEND_MATCH; then
      echo -e "  ${GREEN}✓${NC} $endpoint"
      MATCH=$((MATCH + 1))
    else
      echo -e "  ${YELLOW}~${NC} $endpoint (backend ✓, frontend ✗)"
      MISSING_FRONTEND=$((MISSING_FRONTEND + 1))
      MISSING_FRONTEND_LIST="${MISSING_FRONTEND_LIST}\n    - $endpoint"
    fi
  else
    echo -e "  ${RED}✗${NC} $endpoint (backend ✗)"
    MISSING_BACKEND=$((MISSING_BACKEND + 1))
    MISSING_BACKEND_LIST="${MISSING_BACKEND_LIST}\n    - $endpoint"
  fi
done <<< "$CONTRACT_ENDPOINTS"

echo ""
echo "=== SUMMARY ==="
echo "  Contract endpoints: $CONTRACT_COUNT"
echo -e "  ${GREEN}Fully matched:       $MATCH${NC}"

ERRORS=0
if [ $MISSING_BACKEND -gt 0 ]; then
  echo -e "  ${RED}Missing in backend:  $MISSING_BACKEND${NC}"
  echo -e "$MISSING_BACKEND_LIST"
  ERRORS=$((ERRORS + MISSING_BACKEND))
fi
if [ $MISSING_FRONTEND -gt 0 ]; then
  echo -e "  ${YELLOW}Missing in frontend: $MISSING_FRONTEND${NC}"
  echo -e "$MISSING_FRONTEND_LIST"
  ERRORS=$((ERRORS + MISSING_FRONTEND))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}VALIDATION PASSED — All contract endpoints are implemented.${NC}"
  exit 0
else
  echo -e "${RED}VALIDATION FAILED — $ERRORS endpoint(s) have issues.${NC}"
  exit 1
fi
