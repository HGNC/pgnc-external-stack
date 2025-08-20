# Git Submodules Best Practices Guide

## Problem Description

When you clone a repository with submodules, Git checks out the specific commit SHA that was recorded in the parent repository, not the actual branch. This puts the submodule in a "detached HEAD" state, and any commits made in this state can't be pushed to the remote branch.

## Solution: Proper Submodule Workflow

### 1. Initial Setup (after cloning)

```bash
# Clone the repository with submodules
git clone --recurse-submodules <repository-url>

# OR if already cloned without submodules
git submodule update --init --recursive

# Check out proper branches in all submodules
./checkout-submodule-branches.sh
```

### 2. Daily Workflow

#### Working on a Submodule

```bash
# Navigate to the submodule
cd path/to/submodule

# Ensure you're on the correct branch (not detached HEAD)
git checkout main  # or dev, depending on the submodule

# Pull latest changes
git pull origin main

# Make your changes, commit, and push
git add .
git commit -m "Your commit message"
git push origin main
```

#### Updating Parent Repository

```bash
# After pushing submodule changes, update the parent repository
cd /path/to/parent/repository

# The parent repo will show the submodule as modified
git add path/to/submodule
git commit -m "Update submodule to latest version"
git push origin main
```

### 3. Useful Commands

#### Check submodule status

```bash
git submodule status
```

#### Update all submodules to latest commits on their branches

```bash
git submodule update --remote
```

#### Check out proper branches in all submodules

```bash
./checkout-submodule-branches.sh
```

#### Pull latest changes in all submodules

```bash
git submodule foreach 'git pull origin $(git branch --show-current)'
```

### 4. Submodule Configuration in This Repository

Based on `.gitmodules`, here are the submodules and their target branches:

| Submodule | Path | Repository | Branch |
|-----------|------|------------|--------|
| angular | angular | HGNC/pgnc-ext-angular | dev |
| api | api | HGNC/pgnc-api | main |
| certbot | certbot | HGNC/pgnc-certbot | main |
| db-data | db-data | HGNC/pgnc_db_schema | dev |
| nginx | nginx | HGNC/pgnc-ext-nginx | main |
| python | python | HGNC/pgnc_solr_load | main |
| solr | solr | HGNC/pgnc-solr | main |
| solr-client | solr-client | HGNC/pgnc-solr-client | main |
| solr-data | solr-data | HGNC/pgnc-ext-solr-data | main |

### 5. Important Notes

1. **Always check the branch**: Before making changes in a submodule, ensure you're on the correct branch, not in detached HEAD state.

2. **Two-step process**:
   - First, commit and push changes in the submodule
   - Then, commit the updated submodule reference in the parent repository

3. **Communication**: When working in a team, coordinate submodule updates to avoid conflicts.

4. **Use the script**: The `checkout-submodule-branches.sh` script automates the process of checking out the correct branches in all submodules.

### 6. Troubleshooting

#### If you accidentally committed in detached HEAD

```bash
# In the submodule directory
git branch backup-branch  # Save your work
git checkout main
git merge backup-branch
git push origin main
```

#### If submodule appears modified but you haven't changed anything

```bash
# Check the difference
git diff path/to/submodule

# If it's just a commit hash change, you can:
git add path/to/submodule
git commit -m "Update submodule reference"
```

### 7. Automation

Consider adding this to your workflow:

```bash
# Add to your shell profile (.bashrc, .zshrc, etc.)
alias submodule-branches='./checkout-submodule-branches.sh'
alias submodule-status='git submodule foreach "echo \"=== \$name ===\" && git status --porcelain && git branch --show-current"'
```

This guide should help you avoid the detached HEAD issue and work effectively with submodules!
