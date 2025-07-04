#!/bin/bash

# Script to clone all Docker repositories for the online mapping project
# This script will clone or pull all model repositories into the parent directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Docker Repository information
declare -A DOCKER_REPOS=(
    ["MapTR"]="git@github.com:koscielny/MapTR_docker.git"
    ["PETR"]="git@github.com:koscielny/PETR_docker.git"
    ["StreamPETR"]="git@github.com:koscielny/StreamPETR-docker.git"
    ["TopoMLP"]="git@github.com:koscielny/TopoMLP.git"
    ["VAD"]="git@github.com:koscielny/VAD_docker.git"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
}

# Function to clone or update a repository
clone_or_update_repo() {
    local model_name=$1
    local repo_url=$2
    local target_dir="$PARENT_DIR/$model_name"
    
    print_status "INFO" "Processing $model_name repository..."
    echo "   Repository: $repo_url"
    echo "   Target directory: $target_dir"
    
    if [ -d "$target_dir/.git" ]; then
        print_status "WARNING" "Repository already exists. Updating..."
        (
            cd "$target_dir"
            
            # Check if there are uncommitted changes
            if [ -n "$(git status --porcelain)" ]; then
                print_status "WARNING" "Uncommitted changes detected in $model_name"
                print_status "INFO" "Stashing changes..."
                git stash push -m "Auto-stash before pull at $(date)" || true
            fi
            
            # Fetch and pull latest changes
            print_status "INFO" "Fetching latest changes..."
            git fetch origin || print_status "WARNING" "Fetch operation had issues"
            
            # Get current branch
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            print_status "INFO" "Current branch: $current_branch"
            
            # Pull latest changes
            if git pull origin "$current_branch"; then
                print_status "INFO" "Successfully pulled latest changes"
            else
                print_status "WARNING" "Pull operation had issues, but continuing..."
            fi
            
            # Check for stashed changes
            if git stash list | grep -q "Auto-stash before pull" 2>/dev/null; then
                print_status "WARNING" "Previously stashed changes available. Run 'git stash pop' in $target_dir to restore them."
            fi
        )
        print_status "SUCCESS" "Repository $model_name updated successfully"
    else
        print_status "INFO" "Cloning repository..."
        
        # Create parent directory if it doesn't exist
        mkdir -p "$PARENT_DIR"
        
        # Clone the repository
        if git clone "$repo_url" "$target_dir"; then
            print_status "SUCCESS" "Repository $model_name cloned successfully"
        else
            print_status "ERROR" "Failed to clone $model_name repository"
            return 1
        fi
    fi
    
    echo ""
    return 0
}

# Function to check SSH key access
check_ssh_access() {
    print_status "INFO" "Checking SSH access to GitHub..."
    
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_status "SUCCESS" "SSH access to GitHub is working"
        return 0
    else
        print_status "ERROR" "SSH access to GitHub failed"
        print_status "INFO" "Please ensure:"
        echo "   1. Your SSH key is added to your GitHub account"
        echo "   2. SSH agent is running: eval \$(ssh-agent -s)"
        echo "   3. SSH key is added to agent: ssh-add ~/.ssh/id_rsa"
        echo "   4. GitHub is in known_hosts: ssh-keyscan github.com >> ~/.ssh/known_hosts"
        return 1
    fi
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS] [MODEL_NAMES...]"
    echo ""
    echo "Clone or update all Docker repositories for the online mapping project."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --check    Check SSH access only"
    echo "  -l, --list     List all available models"
    echo "  --https        Use HTTPS instead of SSH (for environments without SSH access)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Clone/update all repositories"
    echo "  $0 PETR MapTR         # Clone/update only PETR and MapTR"
    echo "  $0 --check            # Check SSH access only"
    echo "  $0 --list             # List all available models"
    echo "  $0 --https PETR       # Clone PETR using HTTPS"
}

# Function to list available models
list_models() {
    print_status "INFO" "Available models:"
    for model in "${!DOCKER_REPOS[@]}"; do
        echo "  - $model: ${DOCKER_REPOS[$model]}"
    done
}

# Function to convert SSH URLs to HTTPS
convert_to_https() {
    local ssh_url=$1
    # Convert git@github.com:user/repo.git to https://github.com/user/repo.git
    echo "$ssh_url" | sed 's/git@github.com:/https:\/\/github.com\//'
}

# Main execution
main() {
    local use_https=false
    local check_only=false
    local target_models=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -l|--list)
                list_models
                exit 0
                ;;
            --https)
                use_https=true
                shift
                ;;
            -*)
                print_status "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # Check if it's a valid model name
                if [[ -n "${DOCKER_REPOS[$1]}" ]]; then
                    target_models+=("$1")
                else
                    print_status "ERROR" "Unknown model: $1"
                    print_status "INFO" "Available models: ${!DOCKER_REPOS[*]}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # If no specific models are provided, use all models
    if [ ${#target_models[@]} -eq 0 ]; then
        target_models=("${!DOCKER_REPOS[@]}")
    fi
    
    print_status "INFO" "=== Docker Repository Cloning Script ==="
    print_status "INFO" "Target directory: $PARENT_DIR"
    print_status "INFO" "Models to process: ${target_models[*]}"
    echo ""
    
    # Check SSH access if not using HTTPS
    if [ "$use_https" = false ]; then
        if ! check_ssh_access; then
            if [ "$check_only" = true ]; then
                exit 1
            fi
            print_status "WARNING" "SSH access failed. Consider using --https flag for HTTPS cloning."
            echo ""
        fi
    fi
    
    # Exit if check-only mode
    if [ "$check_only" = true ]; then
        print_status "SUCCESS" "SSH access check completed"
        exit 0
    fi
    
    # Process each repository
    local success_count=0
    local total_count=${#target_models[@]}
    
    print_status "INFO" "Starting to process $total_count repositories..."
    
    for model in "${target_models[@]}"; do
        local repo_url="${DOCKER_REPOS[$model]}"
        
        print_status "INFO" "Processing model: $model ($((success_count + 1))/$total_count)"
        
        # Convert to HTTPS if requested
        if [ "$use_https" = true ]; then
            repo_url=$(convert_to_https "$repo_url")
        fi
        
        if clone_or_update_repo "$model" "$repo_url"; then
            ((success_count++))
            print_status "SUCCESS" "Progress: $success_count/$total_count completed"
        else
            print_status "ERROR" "Failed to process $model"
        fi
    done
    
    echo ""
    print_status "INFO" "=== Summary ==="
    print_status "SUCCESS" "Successfully processed $success_count/$total_count repositories"
    
    if [ $success_count -eq $total_count ]; then
        print_status "SUCCESS" "All repositories are ready!"
        print_status "INFO" "You can now build Docker images using: ./build_model_image.sh"
    else
        print_status "WARNING" "Some repositories failed to process. Please check the errors above."
        exit 1
    fi
}

# Run the main function with all arguments
main "$@"