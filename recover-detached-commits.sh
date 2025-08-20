#!/bin/bash

# Script to recover detached HEAD commits and merge them into proper branches
# This script helps recover commits that were made in detached HEAD state

echo "🔍 Checking for detached HEAD commits that need to be recovered..."
echo ""

# Function to recover commits in a submodule
recover_detached_commits() {
    local submodule_path=$1
    local commit_hash=$2
    local commit_message=$3
    
    if [ -d "$submodule_path" ]; then
        echo "📁 Processing $submodule_path"
        cd "$submodule_path"
        
        # Check if the commit exists
        if git cat-file -e "$commit_hash" 2>/dev/null; then
            echo "  ✅ Found detached commit: $commit_hash"
            echo "  📝 Message: $commit_message"
            
            # Get current branch
            current_branch=$(git branch --show-current)
            echo "  🌿 Current branch: $current_branch"
            
            # Check if this commit is already in the current branch
            if git merge-base --is-ancestor "$commit_hash" HEAD 2>/dev/null; then
                echo "  ✅ Commit is already in the current branch - no action needed"
            else
                echo "  🔄 Creating recovery branch and merging..."
                
                # Create a branch from the detached commit
                recovery_branch="recovery-$(date +%Y%m%d-%H%M%S)"
                git branch "$recovery_branch" "$commit_hash"
                
                # Merge the recovery branch into current branch
                echo "  🔀 Merging $recovery_branch into $current_branch"
                git merge "$recovery_branch" --no-ff -m "Recover detached HEAD commit: $commit_message"
                
                if [ $? -eq 0 ]; then
                    echo "  ✅ Successfully merged detached commit"
                    echo "  🗑️  Cleaning up recovery branch"
                    git branch -d "$recovery_branch"
                    
                    echo "  🚀 You can now push this to remote:"
                    echo "      cd $submodule_path && git push origin $current_branch"
                else
                    echo "  ⚠️  Merge conflict occurred. Please resolve manually:"
                    echo "      cd $submodule_path"
                    echo "      git merge --continue  # after resolving conflicts"
                    echo "      git branch -d $recovery_branch  # after successful merge"
                fi
            fi
        else
            echo "  ❌ Commit $commit_hash not found"
        fi
        
        cd ..
        echo ""
    fi
}

# Main execution
cd "$(dirname "$0")"

echo "🔍 Detached HEAD commits found in submodules:"
echo ""

# Based on the warnings from the previous script run:
echo "📋 Commits to recover:"
echo "  python:      7610569 - Add authentication support for Solr connection in data-update module"
echo "  solr:        e72cbfc - Add security configuration scripts and update Dockerfile for Solr"
echo "  solr-client: 1b341d3 - Add SOLR_USERNAME and SOLR_PASSWORD to environment validation and configuration"
echo ""

read -p "Do you want to recover these commits? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting recovery process..."
    echo ""
    
    # Recover commits
    recover_detached_commits "python" "7610569" "Add authentication support for Solr connection in data-update module"
    recover_detached_commits "solr" "e72cbfc" "Add security configuration scripts and update Dockerfile for Solr"
    recover_detached_commits "solr-client" "1b341d3" "Add SOLR_USERNAME and SOLR_PASSWORD to environment validation and configuration"
    
    echo "✅ Recovery process completed!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Review the merged changes in each submodule"
    echo "2. Test that everything works correctly"
    echo "3. Push the changes to remote repositories"
    echo "4. Update the parent repository to reference the new commits"
    echo ""
    echo "💡 To push all recovered changes:"
    echo "   cd python && git push origin main"
    echo "   cd ../solr && git push origin main"
    echo "   cd ../solr-client && git push origin main"
    echo "   cd .. && git add . && git commit -m 'Update submodules with recovered commits' && git push"
    
else
    echo "❌ Recovery cancelled. Your commits are still safe in the reflog."
    echo ""
    echo "💡 If you want to recover them manually later:"
    echo "   cd python && git branch recovery-python 7610569"
    echo "   cd ../solr && git branch recovery-solr e72cbfc"
    echo "   cd ../solr-client && git branch recovery-solr-client 1b341d3"
    echo ""
    echo "   Then merge each recovery branch into the main branch when ready."
fi
