#!/bin/bash

# Script to checkout proper branches in all submodules
# This solves the detached HEAD issue when working with submodules

echo "Checking out proper branches in all submodules..."

# Function to get the target branch for a submodule
get_target_branch() {
    case $1 in
        "angular") echo "dev" ;;
        "api") echo "main" ;;
        "certbot") echo "main" ;;
        "db-data") echo "dev" ;;
        "nginx") echo "main" ;;
        "python") echo "main" ;;
        "solr") echo "main" ;;
        "solr-client") echo "main" ;;
        "solr-data") echo "main" ;;
        *) echo "main" ;;
    esac
}

# Function to checkout branch in a submodule
checkout_submodule_branch() {
    local submodule_path=$1
    local branch=$2
    
    if [ -d "$submodule_path" ]; then
        echo "Processing $submodule_path -> $branch"
        cd "$submodule_path"
        
        # Check if we're in detached HEAD
        if git symbolic-ref -q HEAD > /dev/null; then
            echo "  Already on a branch"
        else
            echo "  In detached HEAD state, checking out $branch"
        fi
        
        # Fetch latest changes
        git fetch origin
        
        # Check if branch exists locally
        if git show-ref --verify --quiet refs/heads/$branch; then
            echo "  Local branch $branch exists, checking out"
            git checkout $branch
            git pull origin $branch
        else
            echo "  Local branch $branch doesn't exist, creating from origin/$branch"
            git checkout -b $branch origin/$branch
        fi
        
        echo "  ✓ $submodule_path is now on branch $branch"
        cd ..
    else
        echo "  ⚠ Directory $submodule_path not found"
    fi
    echo ""
}

# Main execution
cd "$(dirname "$0")"

# List of submodules
submodules=("angular" "api" "certbot" "db-data" "nginx" "python" "solr" "solr-client" "solr-data")

for submodule in "${submodules[@]}"; do
    branch=$(get_target_branch "$submodule")
    checkout_submodule_branch "$submodule" "$branch"
done

echo "✅ All submodules have been checked out to their proper branches"
echo ""
echo "You can now make changes in submodules and push them normally."
echo "Remember to commit and push the parent repository after making submodule changes!"
