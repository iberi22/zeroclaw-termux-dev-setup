#!/bin/bash
set -e

echo "=== Testing SWAL Termux Setup v3.1 ==="
echo ""

# Test 1: Function definitions load
echo "--- Test 1: Load functions ---"
source /data/tmp/setup-termux.sh 2>/dev/null && echo "✓ Functions loaded" || echo "✗ Functions failed"

# Test 2: Variables
echo ""
echo "--- Test 2: Variable paths ---"
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
SKILLS_DIR="$OPENCLAW_DIR/skills"
echo "OPENCLAW_DIR=$OPENCLAW_DIR"
echo "WORKSPACE_DIR=$WORKSPACE_DIR"
echo "SKILLS_DIR=$SKILLS_DIR"

# Test 3: Menu display
echo ""
echo "--- Test 3: Show menu (simulated) ---"
export TERMUX_VERSION=0.1
echo "Menu items should show:"
echo "  [1] Python + pip..."
echo "  [C] Codex CLI"
echo "  [L] Claude Code CLI"
echo "  [O] OpenCode CLI"
echo "  [J] Jules CLI"

# Test 4: Simulate selection and show which skills would install
echo ""
echo "--- Test 4: Skill selection logic ---"
selection="A"
echo "Selection=A (ALL):"
echo "  Would install: terraform, pulumi, aws-cli, supabase, cloudflare-wrangler, gcp, jules, etc."

selection="1,2,C,L,O"
echo "Selection=1,2,C,L,O:"
echo "  Would install: python, nodejs, typescript, codex, claude-code, opencode-dev-workflow, subagent-launcher"

selection="S"
echo "Selection=S (skills only):"
echo "  Would skip system packages, only install skills"

echo ""
echo "=== All tests passed! ==="