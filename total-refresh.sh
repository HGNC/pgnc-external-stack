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

# Function: manage_submodules
# Description: Initialize and update git submodules
# Behavior:
#   - NEW_ENVIRONMENT=true: Initialize submodules from scratch
#   - NEW_ENVIRONMENT=false: Update existing submodules with fallback strategies
# Globals:
#   NEW_ENVIRONMENT: Determines initialization vs update behavior
# Exit codes:
#   0: Submodules successfully managed
#   1: Submodule operations failed or submodules not properly initialized
manage_submodules() {
    if [[ "$NEW_ENVIRONMENT" == true ]]; then
        log_info "Initializing git submodules..."
        git submodule update --init --recursive
    else
        log_info "Updating git submodules..."
        
        # First, ensure all submodules have proper remote HEAD references
        git submodule foreach 'git remote set-head origin -a 2>/dev/null || true'
        
        # Try different update strategies with fallbacks
        if ! git submodule update --recursive --remote 2>/dev/null; then
            log_warning "Remote update failed, trying standard update..."
            if ! git submodule update --recursive 2>/dev/null; then
                log_warning "Standard update failed, trying manual approach..."
                
                # Manual update approach - fetch and reset to configured branch
                git submodule foreach '
                    echo "Updating submodule: $name"
                    git fetch origin || true
                    branch=$(git config -f $toplevel/.gitmodules submodule.$name.branch || echo "main")
                    if git show-ref --verify --quiet refs/remotes/origin/$branch; then
                        git reset --hard origin/$branch
                    elif git show-ref --verify --quiet refs/remotes/origin/main; then
                        git reset --hard origin/main
                    elif git show-ref --verify --quiet refs/remotes/origin/master; then
                        git reset --hard origin/master
                    else
                        echo "Warning: Could not find suitable branch for $name"
                    fi
                '
            fi
        fi
    fi

    # Verify submodules are properly initialized
    if ! git submodule status | grep -v '^-' > /dev/null; then
        log_warning "Some submodules may not be properly initialized, attempting to fix..."
        
        # Force reinitialize if needed
        git submodule deinit --all -f 2>/dev/null || true
        git submodule update --init --recursive
        
        # Final verification
        if ! git submodule status | grep -v '^-' > /dev/null; then
            log_error "Unable to properly initialize all submodules"
            log_info "Manual intervention may be required:"
            log_info "  git submodule status"
            log_info "  git submodule deinit --all -f"
            log_info "  git submodule update --init --recursive"
            exit 1
        fi
    fi

    log_success "Git submodules updated successfully"
}

# Function: stop_services
# Description: Stop all running containers gracefully
# Behavior:
#   - Stops containers defined in docker-compose.yml
#   - Uses SSL profile if ENABLE_SSL is true
#   - Removes orphaned containers
# Globals:
#   ENABLE_SSL: Determines if SSL profile should be used
#   CONTAINER_TOOL: Container tool to use (docker/podman)
# Exit codes:
#   0: Services stopped successfully
#   1: Failed to stop services (handled by set -e)
stop_services() {
    log_info "Stopping existing services..."
    
    if [[ "$ENABLE_SSL" == true ]]; then
        $CONTAINER_TOOL compose --profile ssl down --remove-orphans
    else
        $CONTAINER_TOOL compose down --remove-orphans
    fi

    log_success "Services stopped successfully"
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
#     * Long-running services (pgncdb, api, angular, solr, solr-client): Must be "healthy"
#     * Task services (python): Must be "exited" with exit code 0
#     * Nginx: Allowed to be "unhealthy" initially (may need SSL setup)
#   - Waits up to 10 minutes (600 seconds) for all services to reach expected states
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
    log_info "Waiting for services to reach expected states..."
    
    local max_wait=600  # 10 minutes
    local wait_time=0
    
    # Define services and their expected states (service:expected_state)
    local service_list=()
    service_list+=("pgncdb:healthy")
    service_list+=("api:healthy")
    service_list+=("angular:healthy")
    service_list+=("solr:healthy")
    
    # Add solr-client only if SSL is disabled (when SSL is enabled, it may not be started)
    if [[ "$ENABLE_SSL" == false ]]; then
        service_list+=("solr-client:healthy")
    fi
    
    # Python service should exit successfully after data loading
    service_list+=("python:exited")
    
    # Nginx health depends on SSL configuration
    if [[ "$ENABLE_SSL" == true ]]; then
        # When SSL is enabled, nginx might be unhealthy until certificates are loaded
        service_list+=("nginx:running")  # Just check it's running, not necessarily healthy
    else
        service_list+=("nginx:healthy")
    fi

    while [[ $wait_time -lt $max_wait ]]; do
        local all_ready=true
        local status_report=""
        
        for service_entry in "${service_list[@]}"; do
            IFS=':' read -r service expected_state <<< "$service_entry"
            local current_state="unknown"
            local current_health="unknown"
            
            # Get service info - check both running and all containers
            local service_info
            service_info=$($CONTAINER_TOOL compose ps --all --format json | jq -r "select(.Service == \"$service\") | \"\(.State)|\(.Health // \"none\")|\(.ExitCode // \"N/A\")\"" 2>/dev/null)
            
            if [[ -n "$service_info" && "$service_info" != "null" ]]; then
                IFS='|' read -r current_state current_health exit_code <<< "$service_info"
                
                local service_ready=false
                case "$expected_state" in
                    "healthy")
                        [[ "$current_health" == "healthy" ]] && service_ready=true
                        ;;
                    "running")
                        [[ "$current_state" == "running" ]] && service_ready=true
                        ;;
                    "exited")
                        [[ "$current_state" == "exited" && "$exit_code" == "0" ]] && service_ready=true
                        ;;
                esac
                
                if [[ "$service_ready" == false ]]; then
                    all_ready=false
                    status_report+="  $service: $current_state"
                    [[ "$current_health" != "none" ]] && status_report+=" ($current_health)"
                    [[ "$current_state" == "exited" ]] && status_report+=" [exit: $exit_code]"
                    status_report+=" (expected: $expected_state)\n"
                fi
            else
                all_ready=false
                status_report+="  $service: not found (expected: $expected_state)\n"
            fi
        done

        if [[ "$all_ready" == true ]]; then
            log_success "All services are in expected states!"
            return 0
        fi

        if [[ $((wait_time % 30)) -eq 0 ]]; then
            log_info "Still waiting for services... (${wait_time}s elapsed)"
            if [[ "$VERBOSE" == true || $wait_time -gt 120 ]]; then
                echo -e "Current status:\n$status_report"
            fi
        fi

        sleep 5
        wait_time=$((wait_time + 5))
    done

    log_error "Services did not reach expected states within $max_wait seconds"
    log_info "Final status check:"
    echo -e "$status_report"
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
        manage_submodules
        build_services
        start_services
    else
        log_info "REFRESHING existing PGNC environment"
        stop_services
        cleanup_resources
        manage_submodules
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
