#!/bin/bash

# Script to create and push runpod/init branch for all model repositories
# This script assumes you have already set up the new remote origins

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Repository information
declare -A REPOS=(
    ["MapTR"]="https://github.com/koscielny/MapTR_docker.git"
    ["PETR"]="https://github.com/koscielny/PETR_docker.git"
    ["StreamPETR"]="https://github.com/koscielny/StreamPETR-docker.git"
    ["TopoMLP"]="https://github.com/koscielny/TopoMLP.git"
    ["VAD"]="https://github.com/koscielny/VAD_docker.git"
)

echo "=== Creating runpod/init branches for all model repositories ==="
echo ""

for MODEL in "${!REPOS[@]}"; do
    REPO_URL="${REPOS[$MODEL]}"
    REPO_PATH="$PARENT_DIR/$MODEL"
    
    echo "📦 Processing $MODEL repository..."
    echo "   Repository: $REPO_URL"
    echo "   Local path: $REPO_PATH"
    
    if [ ! -d "$REPO_PATH" ]; then
        echo "   ❌ Repository directory not found: $REPO_PATH"
        echo "   Please ensure the repository exists at the expected location."
        echo ""
        continue
    fi
    
    cd "$REPO_PATH"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        echo "   ❌ Not a git repository: $REPO_PATH"
        echo ""
        continue
    fi
    
    echo "   📋 Current git status:"
    git status --porcelain
    
    # Check if there are uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "   ⚠️  Warning: There are uncommitted changes in $MODEL"
        echo "   Please commit or stash changes before creating the branch."
        echo ""
        continue
    fi
    
    # Fetch latest changes
    echo "   🔄 Fetching latest changes..."
    git fetch origin
    
    # Ensure we're on main branch
    echo "   🔄 Switching to main branch..."
    git checkout main
    git pull origin main
    
    # Create runpod/init branch
    echo "   🌿 Creating runpod/init branch..."
    if git show-ref --verify --quiet refs/heads/runpod/init; then
        echo "   ℹ️  Branch runpod/init already exists locally"
        git checkout runpod/init
        git merge main --no-edit
    else
        git checkout -b runpod/init
    fi
    
    # Push the branch to origin
    echo "   🚀 Pushing runpod/init branch to origin..."
    git push -u origin runpod/init
    
    # Verify the branch exists remotely
    if git ls-remote --heads origin runpod/init | grep -q runpod/init; then
        echo "   ✅ Successfully created and pushed runpod/init branch for $MODEL"
    else
        echo "   ❌ Failed to push runpod/init branch for $MODEL"
    fi
    
    echo ""
done

echo "=== Summary ==="
echo "All repositories should now have a runpod/init branch."
echo "The Dockerfiles have been updated to use:"
echo "  - New repository URLs under github.com/koscielny/"
echo "  - runpod/init branch instead of main"
echo ""
echo "Next steps:"
echo "1. Verify all branches were created successfully"
echo "2. Test Docker builds with the new configuration"
echo "3. Update any CI/CD pipelines to use the new branch"