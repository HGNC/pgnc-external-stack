#!/usr/bin/env bash
# title:       total-refresh.sh
# version:     2.0
# author:      PGNC Development Team
# date:        2025-07-16
# 
# Description:
# This script automates the setup and deployment of the PGNC (Plant Gene Nomenclature Committee) 
# environment using Docker Compose. It handles submodule management, environment validation,
# container orchestration, and SSL certificate generation with Certbot for Nginx.
#
# The script supports both fresh setup (--new) and environment refresh operations.
# It automatically manages the proper startup sequence of all services including:
# - Database initialization and data loading
# - Solr search engine setup  
# - API and Angular frontend
# - Nginx reverse proxy with SSL support
# - Certbot for Let's Encrypt SSL certificates
#
# Dependencies:
#   - Docker or Podman with Compose plugin
#   - Git (for submodule management) 
#   - jq (for JSON parsing of container status)
#   - Valid .env file (copy from sample.env and configure)
#   - For SSL: Google Cloud credentials (certbot/gcp-key.json)
#
# Exit codes:
#   0: Success
#   1: Error (invalid arguments, missing dependencies, setup failure)
#
# Examples:
#   ./total-refresh.sh --new --container-tool docker
#   ./total-refresh.sh --container-tool docker --ssl
#   ./total-refresh.sh --container-tool docker --clean-volumes

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Global variables - Configuration flags set by command line arguments
NEW_ENVIRONMENT=false    # Flag: Set up new environment vs refresh existing
CONTAINER_TOOL=""        # Required: Container tool to use (docker/podman)
ENABLE_SSL=false         # Flag: Enable SSL certificate generation with Certbot
CLEAN_VOLUMES=false      # Flag: Remove volumes during cleanup (destroys data)
VERBOSE=false            # Flag: Enable verbose output (currently unused)
RENEW_CERTS=false        # Flag: Renew SSL certificates only (no full refresh)
NO_PULL=false            # Flag: Skip pulling latest changes from git

# Colors for output formatting
readonly RED='\033[0;31m'      # Error messages
readonly GREEN='\033[0;32m'    # Success messages  
readonly YELLOW='\033[1;33m'   # Warning messages
readonly BLUE='\033[0;34m'     # Info messages
readonly NC='\033[0m'          # No Color (reset)

# Function: log_info
# Description: Display an informational message with blue color formatting
# Parameters:
#   $1: Message string to display
# Globals: 
#   BLUE, NC: Color constants for formatting
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function: log_success
# Description: Display a success message with green color formatting
# Parameters:
#   $1: Message string to display
# Globals:
#   GREEN, NC: Color constants for formatting
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function: log_warning
# Description: Display a warning message with yellow color formatting
# Parameters:
#   $1: Message string to display
# Globals:
#   YELLOW, NC: Color constants for formatting
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function: log_error
# Description: Display an error message with red color formatting to stderr
# Parameters:
#   $1: Message string to display
# Globals:
#   RED, NC: Color constants for formatting
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function: log_verbose
# Description: Display a verbose message only when VERBOSE flag is true
# Parameters:
#   $1: Message string to display
# Globals:
#   VERBOSE: Flag to control verbose output
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "[VERBOSE] $1"
    fi
}

# Function: show_help
# Description: Display usage information and available options
show_help() {
    cat << EOF
PGNC Environment Setup and Management Script

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --new                   Set up a new PGNC environment from scratch
    --container-tool TOOL   Container tool to use (docker or podman) [REQUIRED]
    --ssl                   Enable SSL certificate generation with Certbot
    --renew-certs          Renew SSL certificates only (no full refresh)
    --clean-volumes         Remove all volumes during cleanup (WARNING: destroys data)
    --no-pull               Skip pulling latest changes from git (for development)
    --verbose              Enable verbose output
    --help                 Show this help message

EXAMPLES:
    # Set up new environment with Docker
    $(basename "$0") --new --container-tool docker

    # Refresh existing environment with SSL enabled
    $(basename "$0") --container-tool docker --ssl

    # Renew SSL certificates only (for cron jobs)
    $(basename "$0") --container-tool docker --renew-certs

    # Clean refresh with volume removal (destroys all data)
    $(basename "$0") --container-tool docker --clean-volumes

    # Run refresh without pulling latest code (for local development)
    $(basename "$0") --container-tool docker --no-pull

DESCRIPTION:
    This script manages the PGNC multi-service environment consisting of:
    - PostgreSQL database with PGNC data
    - Apache Solr search engine
    - NestJS API backend
    - Angular frontend application
    - Nginx reverse proxy
    - Certbot for SSL certificates (optional)

    The script ensures proper service dependencies and startup order,
    validates environment configuration, and provides detailed logging.

REQUIREMENTS:
    - Docker or Podman with Compose plugin
    - Git (for submodule management)
    - jq (for JSON parsing of container status)
    - Valid .env file (copy from sample.env and configure)
    - For SSL: Google Cloud credentials for DNS validation

EOF
}

# Function: parse_arguments
# Description: Parse and validate command line arguments
# Parameters:
#   $@: All command line arguments passed to the script
# Globals:
#   NEW_ENVIRONMENT: Set to true if --new flag is provided
#   CONTAINER_TOOL: Set to the specified container tool (docker/podman)
#   ENABLE_SSL: Set to true if --ssl flag is provided
#   CLEAN_VOLUMES: Set to true if --clean-volumes flag is provided
#   VERBOSE: Set to true if --verbose flag is provided
#   RENEW_CERTS: Set to true if --renew-certs flag is provided
#   NO_PULL: Set to true if --no-pull flag is provided
# Exit codes:
#   0: Arguments parsed successfully
#   1: Invalid arguments, missing required arguments, or tool not available
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --new)
                NEW_ENVIRONMENT=true
                shift
                ;;
            --container-tool)
                if [[ -z "${2:-}" ]]; then
                    log_error "Container tool value is required"
                    exit 1
                fi
                CONTAINER_TOOL="$2"
                shift 2
                ;;
            --ssl)
                ENABLE_SSL=true
                shift
                ;;
            --renew-certs)
                RENEW_CERTS=true
                shift
                ;;
            --no-pull)
                NO_PULL=true
                shift
                ;;
            --clean-volumes)
                CLEAN_VOLUMES=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate conflicting flags
    if [[ "$NO_PULL" == "true" && "$NEW_ENVIRONMENT" == "true" ]]; then
        log_error "The --no-pull flag cannot be used with --new."
        exit 1
    fi

    if [[ "$NO_PULL" == "true" && "$RENEW_CERTS" == "true" ]]; then
        log_error "The --no-pull flag cannot be used with --renew-certs."
        exit 1
    fi

    # Validate required parameters
    if [[ -z "$CONTAINER_TOOL" ]]; then
        log_error "Container tool must be specified with --container-tool"
        show_help
        exit 1
    fi

    if [[ "$CONTAINER_TOOL" != "docker" && "$CONTAINER_TOOL" != "podman" ]]; then
        log_error "Container tool must be either 'docker' or 'podman'"
        exit 1
    fi

    # Verify container tool is available
    if ! command -v "$CONTAINER_TOOL" &> /dev/null; then
        log_error "$CONTAINER_TOOL is not installed or not in PATH"
        exit 1
    fi

    if ! $CONTAINER_TOOL compose version &> /dev/null; then
        log_error "$CONTAINER_TOOL compose plugin is not available"
        exit 1
    fi

    # Validate certificate renewal options
    if [[ "$RENEW_CERTS" == true ]]; then
        if [[ "$NEW_ENVIRONMENT" == true ]]; then
            log_error "--renew-certs cannot be used with --new"
            exit 1
        fi
        if [[ "$CLEAN_VOLUMES" == true ]]; then
            log_error "--renew-certs cannot be used with --clean-volumes"
            exit 1
        fi
    fi
}

# Function: check_prerequisites
# Description: Verify system prerequisites and dependencies
# Prerequisites:
#   - Must be run from a directory containing docker-compose.yml
#   - Must be run from within a git repository
#   - Git must be installed and accessible
#   - jq must be installed for JSON parsing (required for service health checks)
# Exit codes:
#   0: All prerequisites met
#   1: Prerequisites not met (missing files, tools, or wrong directory)
check_prerequisites() {
    log_info "Checking system prerequisites..."

    # Check if we're in the right directory
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found. Are you in the correct directory?"
        exit 1
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        log_error "Git is required but not installed"
        exit 1
    fi

    # Check for jq (required for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for service health checks but not installed"
        log_info "Install jq:"
        if [[ "$(uname)" == "Darwin" ]]; then
            log_info "  brew install jq"
        else
            log_info "  sudo apt-get install jq  # Ubuntu/Debian"
            log_info "  sudo yum install jq      # CentOS/RHEL"
        fi
        exit 1
    fi

    # Check if this is a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "This is not a git repository"
        exit 1
    fi

    log_success "Prerequisites check completed"
}

# Function: validate_env_file
# Description: Check .env file exists and is properly configured
# Validates:
#   - .env file exists (suggests copying from sample.env if missing)
#   - No placeholder values (< >) remain in configuration
#   - Required environment variables are set with non-empty values
#   - SSL-specific variables when SSL is enabled
# Globals:
#   ENABLE_SSL: Used to determine if SSL-specific validation is needed
# Exit codes:
#   0: Environment file is valid and properly configured
#   1: Environment file missing, contains placeholders, or missing required values
validate_env_file() {
    log_info "Validating environment configuration..."

    if [[ ! -f ".env" ]]; then
        if [[ -f "sample.env" ]]; then
            log_error ".env file not found. Please copy sample.env to .env and configure it:"
            log_info "cp sample.env .env"
            log_info "Edit .env file with your configuration values"
        else
            log_error ".env file not found and no sample.env available"
        fi
        exit 1
    fi

    # Check for placeholder values
    if grep -q '<.*>' ".env"; then
        log_error ".env file contains placeholder values (< >). Please configure all values."
        log_info "Found placeholders:"
        grep '<.*>' ".env" || true
        exit 1
    fi

    # Check for required variables
    local required_vars=(
        "DB_PASSWORD"
        "JWT_SECRET"
        "API_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" ".env" || grep -q "^${var}=$" ".env"; then
            log_error "Required environment variable $var is not set in .env"
            exit 1
        fi
    done

    if [[ "$ENABLE_SSL" == true ]]; then
        if ! grep -q "^MY_EMAIL=" ".env" || grep -q "^MY_EMAIL=$" ".env"; then
            log_error "MY_EMAIL is required when SSL is enabled"
            exit 1
        fi
    fi

    log_success "Environment configuration validated"
}

# Function: get_submodule_branch
# Description: Get the target branch for a given submodule
# Parameters:
#   $1: Submodule name
# Returns:
#   The branch name to be tracked (e.g., "dev", "main")
get_submodule_branch() {
    case "$1" in
        "angular"|"db-data")
            echo "dev"
            ;;
        *)
            echo "main"
            ;;
    esac
}

# Function: log_commit_hash
# Description: Log the current commit hash of the superproject and submodules
# Globals:
#   VERBOSE: Only logs if this is true
log_commit_hash() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Current repository state:"
        local main_commit
        main_commit=$(git rev-parse --short HEAD)
        log_verbose "  - Superproject commit: $main_commit"
        
        log_verbose "  - Submodule commits:"
        git submodule status | while read -r submodule_commit submodule_name submodule_branch; do
            log_verbose "    - $submodule_name: ${submodule_commit:1} ($submodule_branch)"
        done
    fi
}

# Function: pull_latest_code
# Description: Pull latest changes for the superproject and update submodules
# Behavior:
#   - Pulls latest changes for the main repository
#   - Updates submodules to the latest commit on their tracked branch
#   - Provides detailed error handling for each git operation
# Exit codes:
#   0: Success
#   1: Git operation failed
pull_latest_code() {
    log_info "Pulling latest code changes..."
    log_commit_hash # Log state before pulling

    # Pull latest changes for the superproject
    log_info "Updating superproject..."
    if ! git pull; then
        log_error "Failed to pull latest changes for the superproject."
        log_warning "Please resolve any git conflicts and try again."
        return 1
    fi

    # Update submodules to their latest remote versions
    log_info "Updating submodules to latest remote versions..."
    if ! git submodule update --remote --recursive; then
        log_error "Failed to update submodules to their latest versions."
        log_warning "This can happen due to detached HEAD, conflicts, or network issues."
        log_info "Attempting to fix by checking out tracked branches..."

        # Fallback: manually checkout and pull each submodule
        local submodule_failed=false
        for submodule in $(git submodule status | awk '{print $2}'); do
            if [[ -d "$submodule" ]]; then
                (
                    cd "$submodule"
                    branch=$(git config -f ../.gitmodules "submodule.$submodule.branch" || echo "main")
                    log_info "Updating submodule '$submodule' on branch '$branch'..."
                    if ! git checkout "$branch" || ! git pull origin "$branch"; then
                        log_warning "Failed to update submodule: $submodule"
                        submodule_failed=true
                    fi
                )
            fi
        done

        if [[ "$submodule_failed" == "true" ]]; then
            log_error "One or more submodules failed to update. Please check the logs."
            return 1
        fi
    fi

    log_success "Code updated successfully."
    log_commit_hash # Log state after pulling
    return 0
}

# Function: initialize_and_update_submodules
# Description: Initialize and update git submodules based on environment type
# Behavior:
#   - For new environments, initializes submodules and configures branch tracking
#   - For existing environments, updates submodules to latest branch commits
#   - Skips all git operations if --no-pull flag is provided
# Globals:
#   NEW_ENVIRONMENT: Flag to determine if it's a new setup
#   NO_PULL: Flag to skip git operations
# Exit codes:
#   0: Success
#   1: Submodule initialization or update failure
initialize_and_update_submodules() {
    # Always initialize submodules to ensure they are present, even with --no-pull
    log_info "Initializing submodules..."
    if ! git submodule update --init --recursive; then
        log_error "Failed to initialize submodules."
        log_warning "Please check your git configuration and submodule access."
        return 1
    fi

    if [[ "$NO_PULL" == "true" ]]; then
        log_info "Skipping git pull and submodule update as per --no-pull flag."
        log_commit_hash # Log current state even when not pulling
        return 0
    fi

    # For new environments, we need to set up branch tracking
    if [[ "$NEW_ENVIRONMENT" == "true" ]]; then
        log_info "Configuring submodules to track branches..."
        local submodules
        submodules=($(git submodule status | awk '{print $2}'))
        
        for submodule in "${submodules[@]}"; do
            if [[ -d "$submodule" ]]; then
                local branch
                branch=$(get_submodule_branch "$submodule")
                log_info "Configuring $submodule to track branch: $branch"
                
                # Set branch in .gitmodules
                if ! git config -f .gitmodules "submodule.$submodule.branch" "$branch"; then
                    log_warning "Failed to set branch for submodule $submodule in .gitmodules"
                fi
            fi
        done
        
        # Add .gitmodules to staging if it was modified
        if ! git diff --quiet .gitmodules; then
            if ! git add .gitmodules; then
                log_warning "Failed to stage .gitmodules changes."
            fi
        fi
    fi

    # For both new and existing environments (when not using --no-pull), pull the latest code
    if ! pull_latest_code; then
        log_error "Failed to pull latest code."
        return 1
    fi

    # Final verification of submodule status
    log_info "Verifying submodule configuration..."
    git submodule foreach 'echo "Submodule $name: $(git branch --show-current 2>/dev/null || echo "detached") ($(git rev-parse --short HEAD))"'
    
    log_success "Git submodules are up to date."
}

# Function: stop_services
# Description: Stop all running containers gracefully
# Behavior:
#   - Stops all services defined in the docker-compose.yml file
#   - Optionally removes volumes if --clean-volumes is specified
# Globals:
#   CONTAINER_TOOL: The container management tool (docker/podman)
#   CLEAN_VOLUMES: Flag to determine if volumes should be removed
# Exit codes:
#   0: Success
#   1: Failure to stop services
stop_services() {
    log_info "Stopping all running services..."
    
    local compose_cmd=("$CONTAINER_TOOL-compose" "down")
    if [[ "$CLEAN_VOLUMES" == "true" ]]; then
        log_warning "Removing all volumes as requested. ALL DATA WILL BE LOST."
        compose_cmd+=("--volumes")
    fi
    
    if ! "${compose_cmd[@]}"; then
        log_error "Failed to stop services."
        return 1
    fi
    
    log_success "All services stopped successfully."
}

# Function: cleanup_resources
# Description: Remove unused containers, images, and optionally volumes
# Operations:
#   - Removes unused containers, images, and networks
#   - Optionally removes volumes with user confirmation if CLEAN_VOLUMES=true
#   - Provides safety confirmation before destructive volume removal
# Globals:
#   CLEAN_VOLUMES: If true, prompts for volume removal
#   CONTAINER_TOOL: Container tool to use for cleanup operations
# User interaction:
#   - Prompts for "yes/no" confirmation before volume removal
# Exit codes:
#   0: Cleanup completed successfully
#   1: Cleanup operations failed (handled by set -e)
cleanup_resources() {
    log_info "Cleaning up container resources..."

    # Remove unused containers
    $CONTAINER_TOOL container prune -f

    # Remove unused images
    $CONTAINER_TOOL image prune -f

    # Remove unused networks
    $CONTAINER_TOOL network prune -f

    if [[ "$CLEAN_VOLUMES" == true ]]; then
        log_warning "Removing all volumes - this will destroy all data!"
        read -p "Are you sure? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            $CONTAINER_TOOL volume prune -f
            log_success "Volumes cleaned"
        else
            log_info "Volume cleanup cancelled"
        fi
    fi

    log_success "Resource cleanup completed"
}

# Function: build_services
# Description: Build all container images
# Behavior:
#   - Builds images defined in docker-compose.yml
#   - Uses --no-cache flag to ensure fresh builds
#   - Includes SSL profile services if ENABLE_SSL is true
# Globals:
#   ENABLE_SSL: Determines if SSL profile should be included
#   CONTAINER_TOOL: Container tool to use for building
# Exit codes:
#   0: Images built successfully
#   1: Build process failed (handled by set -e)
build_services() {
    log_info "Building container images..."
    
    if [[ "$ENABLE_SSL" == true ]]; then
        $CONTAINER_TOOL compose --profile ssl build --no-cache
    else
        $CONTAINER_TOOL compose build --no-cache
    fi

    log_success "Container images built successfully"
}

# Function: get_service_health
# Description: Get the health status of a specific service
# Arguments:
#   $1: Service name
#   $2: Container tool
# Returns:
#   Health status string (e.g., "healthy", "unhealthy", "running")
get_service_health() {
    local service_name="$1"
    local container_tool="$2"

    # The `docker compose ps --format json` command outputs a stream of JSON objects, not a single JSON array.
    # We need to process this stream. The `jq 'select(.Service == ...)'` filter works correctly on a stream.
    local service_info
    service_info=$($container_tool compose ps --format json | jq "select(.Service == \"$service_name\")" 2>/dev/null)

    if [[ -z "$service_info" ]]; then
        echo "not_found"
        return
    fi

    # For both testing and production, if a container has no health check, its readiness is determined by its state.
    # The alpine containers in the test environment only have a 'running' state.
    # Production containers without a health check are also considered ready if 'running'.
    local health_status
    health_status=$(echo "$service_info" | jq -r '.Health' 2>/dev/null)

    if [[ -z "$health_status" || "$health_status" == "null" ]]; then
        local state
        state=$(echo "$service_info" | jq -r '.State' 2>/dev/null)
        echo "$state"
    else
        echo "$health_status"
    fi
}

# Function: start_services
# Description: Start all services in the correct order
# Operations:
#   - Creates pgnc-network if it doesn't exist
#   - Starts services defined in docker-compose.yml with proper dependencies
#   - Uses SSL profile if ENABLE_SSL is true
#   - Runs containers in detached mode (-d)
# Globals:
#   ENABLE_SSL: Determines if SSL profile should be used
#   CONTAINER_TOOL: Container tool to use for starting services
# Exit codes:
#   0: Services started successfully
#   1: Failed to start services (handled by set -e)
start_services() {
    log_info "Starting PGNC services..."

    # Create required networks if they don't exist
    $CONTAINER_TOOL network create pgnc-network 2>/dev/null || true

    if [[ "$ENABLE_SSL" == true ]]; then
        log_info "Starting services with SSL profile..."
        $CONTAINER_TOOL compose --env-file .env --profile ssl up -d
    else
        log_info "Starting services without SSL..."
        $CONTAINER_TOOL compose --env-file .env up -d
    fi

    log_success "Services started successfully"
}

# Function: wait_for_services
# Description: Wait for all services to be healthy or in their expected final state
# Behavior:
#   - Monitors different service types with appropriate expectations:
#     * Long-running services (pgncdb, api, angular, solr, solr-client): Must be "healthy" or "running"
#     * Task services (python): Must be "exited" with exit code 0
#     * Nginx: Allowed to be "unhealthy" initially (may need SSL setup)
#   - Waits up to 5 minutes (300 seconds) for all services to reach expected states
#   - Provides progress updates every 30 seconds
#   - Uses jq to parse JSON output from docker compose ps
#   - Compatible with both macOS and Linux platforms
# Globals:
#   ENABLE_SSL: Affects which services are monitored and nginx health expectations
#   CONTAINER_TOOL: Container tool to use for health checks
# Dependencies:
#   - jq: Required for parsing JSON output
# Exit codes:
#   0: All services reached expected states within timeout
#   1: Services did not reach expected states within timeout period
wait_for_services() {
    local services_to_check=("pgncdb" "api" "angular" "solr" "nginx")
    if [[ "$ENABLE_SSL" == false ]]; then
        services_to_check+=("solr-client")
    fi
    local start_time=$SECONDS
    local timeout=300 # 5 minutes

    log_info "Waiting for services to reach expected states..."

    while [[ ${#services_to_check[@]} -gt 0 && $SECONDS -lt $((start_time + timeout)) ]]; do
        local i=0
        while [[ $i -lt ${#services_to_check[@]} ]]; do
            local service=${services_to_check[$i]}
            local health
            health=$(get_service_health "$service" "$CONTAINER_TOOL")

            if [[ "${TESTING_MODE:-}" == "true" ]]; then
                echo "DEBUG: In testing mode. Service: $service, Health: $health, Array: (${services_to_check[*]})"
            fi

            if [[ "$health" == "healthy" || "$health" == "running" ]]; then
                log_info "Service '$service' is ready."
                # Remove the element from the array
                services_to_check=("${services_to_check[@]:0:$i}" "${services_to_check[@]:$((i+1))}")
                # Decrement i because the next element is now at the current index
                i=$((i - 1))
            fi
            i=$((i + 1))
        done

        if [[ ${#services_to_check[@]} -gt 0 ]]; then
            sleep 5
            local elapsed_time=$((SECONDS - start_time))
            if (( elapsed_time > 0 && elapsed_time % 30 == 0 )); then
                 log_info "Still waiting for services... (${elapsed_time}s elapsed)"
            fi
        fi
    done

    if [[ ${#services_to_check[@]} -eq 0 ]]; then
        log_success "All services are in expected states!"
        return 0
    fi

    log_error "Services did not reach expected states within $timeout seconds"
    log_info "Final status check:"
    # Check if the array is not empty before iterating
    if [[ ${#services_to_check[@]} -gt 0 ]]; then
        for service in "${services_to_check[@]}"; do
            local health
            health=$(get_service_health "$service" "$CONTAINER_TOOL")
            log_info "  $service: $health"
        done
    fi
    log_info "Full container status:"
    $CONTAINER_TOOL compose ps --all
    return 1
}

# Function: run_certbot
# Description: Generate SSL certificates using Certbot
# Prerequisites:
#   - ENABLE_SSL must be true
#   - certbot/gcp-key.json must exist for Google Cloud DNS validation
#   - MY_EMAIL must be configured in .env file
# Operations:
#   - Runs certbot container to generate Let's Encrypt certificates
#   - Uses DNS challenge with Google Cloud DNS
#   - Restarts nginx to load new certificates
# Globals:
#   ENABLE_SSL: Must be true for function to execute
#   CONTAINER_TOOL: Container tool to use for running certbot
# Exit codes:
#   0: Certificates generated successfully and nginx restarted
#   1: Required files missing or certificate generation failed
run_certbot() {
    if [[ "$ENABLE_SSL" == true ]]; then
        log_info "Generating SSL certificates with Certbot..."
        
        # Check if required files exist
        if [[ ! -f "certbot/gcp-key.json" ]]; then
            log_error "certbot/gcp-key.json not found. Required for DNS validation."
            exit 1
        fi

        # Run certbot service
        $CONTAINER_TOOL compose --profile ssl run --rm certbot

        # Restart nginx to load certificates
        log_info "Restarting nginx to load SSL certificates..."
        $CONTAINER_TOOL compose restart nginx

        log_success "SSL certificates generated and nginx restarted"
    fi
}

# Function: renew_certificates
# Description: Renew SSL certificates without full service restart
# Prerequisites:
#   - Environment must be already set up and running
#   - certbot/gcp-key.json must exist for Google Cloud DNS validation
#   - Nginx service must be running
# Operations:
#   - Checks if certificates exist and are due for renewal
#   - Runs certbot renewal process using DNS challenge
#   - Reloads nginx configuration to use new certificates
#   - Provides detailed logging of renewal process
# Globals:
#   CONTAINER_TOOL: Container tool to use for renewal operations
# Exit codes:
#   0: Certificate renewal successful or not needed
#   1: Required files missing, renewal failed, or nginx reload failed
renew_certificates() {
    log_info "Starting SSL certificate renewal process..."
    
    # Check if required files exist
    if [[ ! -f "certbot/gcp-key.json" ]]; then
        log_error "certbot/gcp-key.json not found. Required for DNS validation."
        exit 1
    fi

    # Check if nginx is running
    if ! $CONTAINER_TOOL compose ps nginx | grep -q "Up"; then
        log_error "Nginx service is not running. Cannot proceed with certificate renewal."
        log_info "Start the full environment first with: $0 --container-tool $CONTAINER_TOOL --ssl"
        exit 1
    fi

    # Run certbot renewal (certbot will check if renewal is needed)
    log_info "Running certbot renewal check..."
    if $CONTAINER_TOOL compose --profile ssl run --rm certbot renew --quiet; then
        log_success "Certificate renewal check completed successfully"
        
        # Reload nginx to pick up any new certificates
        log_info "Reloading nginx configuration..."
        if $CONTAINER_TOOL compose exec nginx nginx -s reload; then
            log_success "Nginx configuration reloaded successfully"
        else
            log_warning "Failed to reload nginx configuration. You may need to restart nginx manually."
            log_info "To restart nginx: $CONTAINER_TOOL compose restart nginx"
        fi
    else
        log_error "Certificate renewal failed"
        exit 1
    fi

    log_success "SSL certificate renewal process completed"
}

# Function: show_status
# Description: Display the status of all services and access URLs
# Output:
#   - Container status from docker compose ps
#   - Access URLs for frontend, API, and search interfaces
#   - HTTPS URL if SSL is enabled
#   - Commands for log monitoring
# Globals:
#   ENABLE_SSL: Determines if HTTPS URL is displayed
#   CONTAINER_TOOL: Container tool to use for status commands
# Dependencies:
#   - Reads LOCALHOST_NGINX_PORT and LOCALHOST_NGINX_SSL_PORT from .env file
show_status() {
    log_info "PGNC Environment Status:"
    echo
    
    # Show container status
    $CONTAINER_TOOL compose ps
    echo

    # Show access URLs
    log_info "Access URLs:"
    local nginx_port
    nginx_port=$(grep "LOCALHOST_NGINX_PORT" .env | cut -d'=' -f2)
    
    echo "  Frontend:     http://localhost:${nginx_port:-80}"
    echo "  API:          http://localhost:${nginx_port:-80}/api"
    echo "  Search:       http://localhost:${nginx_port:-80}/ses"
    
    if [[ "$ENABLE_SSL" == true ]]; then
        local ssl_port
        ssl_port=$(grep "LOCALHOST_NGINX_SSL_PORT" .env | cut -d'=' -f2)
        echo "  HTTPS:        https://localhost:${ssl_port:-443}"
    fi
    
    echo
    log_info "Log monitoring:"
    echo "  All services: $CONTAINER_TOOL compose logs -f"
    echo "  Specific:     $CONTAINER_TOOL compose logs -f <service_name>"
}

# Function: main
# Description: Main execution flow orchestrating the entire setup process
# Process:
#   1. Parse and validate command line arguments
#   2. Check system prerequisites and environment configuration
#   3. Execute either new environment setup or refresh workflow:
#      - New: manage_submodules -> build_services -> start_services
#      - Refresh: stop_services -> cleanup_resources -> manage_submodules -> build_services -> start_services
#   4. Wait for all services to become healthy
#   5. Generate SSL certificates if enabled
#   6. Display final status and access information
# Parameters:
#   $@: All command line arguments (passed to parse_arguments)
# Exit codes:
#   0: Environment setup completed successfully
#   1: Setup failed at any step (handled by individual functions and set -e)
main() {
    log_info "Starting PGNC Environment Setup"
    log_info "================================"

    parse_arguments "$@"
    check_prerequisites
    validate_env_file

    # Handle certificate renewal mode
    if [[ "$RENEW_CERTS" == true ]]; then
        log_info "Running SSL certificate renewal"
        renew_certificates
        log_success "SSL certificate renewal completed!"
        exit 0
    fi

    if [[ "$NEW_ENVIRONMENT" == true ]]; then
        log_info "Setting up NEW PGNC environment"
        initialize_and_update_submodules
        build_services
        start_services
    else
        log_info "REFRESHING existing PGNC environment"
        stop_services
        cleanup_resources
        initialize_and_update_submodules
        build_services
        start_services
    fi

    wait_for_services
    run_certbot
    show_status

    log_success "PGNC environment is ready!"
}

# Execute main function with all arguments only if not in testing mode
if [[ "${TESTING_MODE:-}" != "true" ]]; then
    main "$@"
fi
