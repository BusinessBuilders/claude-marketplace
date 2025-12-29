#!/usr/bin/env bash
#
# analyze-project.sh - Analyze project codebase to detect tech stack
#
# Usage: ./analyze-project.sh [project-dir]
#
# Outputs JSON with detected technologies, frameworks, and patterns
#

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Initialize technologies array
TECHNOLOGIES="[]"

# Function to add a technology
add_tech() {
  local category="$1"
  local name="$2"
  local confidence="$3"
  local evidence="$4"

  local tech=$(jq -n \
    --arg cat "$category" \
    --arg name "$name" \
    --argjson conf "$confidence" \
    --arg ev "$evidence" \
    '{
      category: $cat,
      name: $name,
      confidence: $conf,
      evidence: $ev
    }')

  TECHNOLOGIES=$(echo "$TECHNOLOGIES" | jq --argjson t "$tech" '. += [$t]')
}

# Check package.json (Node.js/TypeScript projects)
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  # TypeScript
  if grep -q '"typescript"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "language" "TypeScript" 0.95 "package.json dependencies"
  fi

  # tRPC
  if grep -q '@trpc' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "backend" "tRPC" 0.95 "package.json dependencies"
  fi

  # Prisma
  if grep -q '"@prisma/client"\\|"prisma"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "database" "Prisma" 0.95 "package.json dependencies"
  fi

  # Express
  if grep -q '"express"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "backend" "Express" 0.90 "package.json dependencies"
  fi

  # Next.js
  if grep -q '"next"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "frontend" "Next.js" 0.95 "package.json dependencies"
  fi

  # React
  if grep -q '"react"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "frontend" "React" 0.95 "package.json dependencies"
  fi

  # React Native / Expo
  if grep -q '"expo"\\|"react-native"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "mobile" "React Native/Expo" 0.95 "package.json dependencies"
  fi

  # Jest (testing)
  if grep -q '"jest"\\|"@jest"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "testing" "Jest" 0.90 "package.json dependencies"
  fi

  # AI/LLM libraries
  if grep -q '"openai"\\|"@anthropic-ai"\\|"langchain"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "ai" "LLM Integration" 0.95 "package.json dependencies"
  fi

  # BullMQ (queues)
  if grep -q '"bullmq"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    add_tech "infrastructure" "BullMQ" 0.95 "package.json dependencies"
  fi
fi

# Check for Prisma schema
if [[ -f "$PROJECT_DIR/prisma/schema.prisma" ]] || find "$PROJECT_DIR" -name "schema.prisma" -type f 2>/dev/null | grep -q .; then
  add_tech "database" "Prisma ORM" 0.95 "schema.prisma file found"

  # Detect database type from schema
  if grep -q 'provider[[:space:]]*=[[:space:]]*"postgresql"' "$PROJECT_DIR/prisma/schema.prisma" 2>/dev/null; then
    add_tech "database" "PostgreSQL" 0.90 "Prisma schema provider"
  fi
fi

# Check for Python requirements
if [[ -f "$PROJECT_DIR/requirements.txt" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  add_tech "language" "Python" 0.90 "requirements.txt or pyproject.toml found"

  # Check for common Python frameworks
  if grep -q 'fastapi\\|django\\|flask' "$PROJECT_DIR/requirements.txt" 2>/dev/null || \
     grep -q 'fastapi\\|django\\|flask' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    add_tech "backend" "Python Web Framework" 0.85 "requirements file"
  fi
fi

# Check for Docker
if [[ -f "$PROJECT_DIR/Dockerfile" ]] || [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
  add_tech "infrastructure" "Docker" 0.90 "Dockerfile or docker-compose.yml found"
fi

# Check for Kubernetes
if [[ -d "$PROJECT_DIR/k8s" ]] || [[ -d "$PROJECT_DIR/kubernetes" ]] || \
   find "$PROJECT_DIR" -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "apiVersion: v1" 2>/dev/null | head -1 | grep -q .; then
  add_tech "infrastructure" "Kubernetes" 0.80 "K8s manifests found"
fi

# Check for GitHub Actions
if [[ -d "$PROJECT_DIR/.github/workflows" ]]; then
  add_tech "cicd" "GitHub Actions" 0.95 ".github/workflows directory found"
fi

# Grep codebase for patterns (if git repo)
if [[ -d "$PROJECT_DIR/.git" ]]; then
  cd "$PROJECT_DIR"

  # tRPC patterns
  if git grep -q "createTRPCRouter\\|createTRPCContext" 2>/dev/null; then
    add_tech "backend" "tRPC Router" 0.90 "tRPC router patterns in code"
  fi

  # AI provider patterns
  if git grep -q "OpenAI\\|Anthropic\\|Claude" 2>/dev/null; then
    add_tech "ai" "AI Provider Integration" 0.85 "AI provider usage in code"
  fi

  # Authentication patterns
  if git grep -q "jwt\\|passport\\|auth0" 2>/dev/null; then
    add_tech "security" "Authentication" 0.75 "Auth patterns in code"
  fi
fi

# Output JSON result
jq -n \
  --arg project "$(basename "$PROJECT_DIR")" \
  --argjson techs "$TECHNOLOGIES" \
  '{
    project: $project,
    analyzed_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    technologies: $techs,
    tech_count: ($techs | length)
  }'

exit 0
