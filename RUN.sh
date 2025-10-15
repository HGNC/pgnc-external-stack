#!/usr/bin/env bash
# title:       RUN.sh
# version:     1.0
# author:      PGNC Development Team
# date:        2025-10-15
# 
# Description:
# This script runs the PGNC environment using Docker Compose for a freshly
# downloaded project. It assumes no existing containers, images, or volumes
# and sets up everything from scratch.
#
# The script assumes:
# - Docker is installed and available
# - Project has been freshly downloaded/cloned
# - A valid .env file exists
# - No existing containers or volumes
#
# Dependencies:
#   - Docker with Compose plugin
#   - jq (for JSON parsing of container status)
#   - Valid .env file (copy from sample.env and configure)
#
# Exit codes:
#   0: Success
#   1: Error (missing dependencies, setup failure)
#
# Examples:
#   ./RUN.sh

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Global variables - Configuration flags
readonly CONTAINER_TOOL="docker"    # Fixed to docker

# Colors for output formatting
readonly RED='\033[0;31m'      # Error messages
readonly GREEN='\033[0;32m'    # Success messages  
readonly YELLOW='\033[1;33m'   # Warning messages
readonly BLUE='\033[0;34m'     # Info messages
readonly NC='\033[0m'          # No Color (reset)

# Function: log_info
# Description: Display an informational message with blue color formatting
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function: log_success
# Description: Display a success message with green color formatting
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function: log_warning
# Description: Display a warning message with yellow color formatting
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function: log_error
# Description: Display an error message with red color formatting to stderr
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function: show_help
# Description: Display usage information and available options
show_help() {
    cat << EOF
PGNC Environment Runner for Fresh Installation

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --help                 Show this help message

EXAMPLES:
    # Run environment for the first time
    $(basename "$0")

DESCRIPTION:
    This script sets up and runs the PGNC multi-service environment consisting of:
    - PostgreSQL database with PGNC data
    - Apache Solr search engine
    - NestJS API backend
    - Angular frontend application
    - Nginx reverse proxy

    The script is designed for fresh installations where no containers,
    images, or volumes exist yet.

REQUIREMENTS:
    - Docker with Compose plugin
    - jq (for JSON parsing of container status)
    - Valid .env file (copy from sample.env and configure)

EOF
}

# Function: parse_arguments
# Description: Parse and validate command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
}

# Function: check_prerequisites
# Description: Verify system prerequisites and dependencies
check_prerequisites() {
    log_info "Checking system prerequisites..."

    # Check if we're in the right directory
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found. Are you in the correct directory?"
        exit 1
    fi

    # Check for docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        log_error "Docker compose plugin is not available"
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

    log_success "Prerequisites check completed"
}

# Function: validate_env_file
# Description: Check .env file exists and is properly configured
validate_env_file() {
    log_info "Validating environment configuration..."

    if [[ ! -f ".env" ]]; then
        if [[ -f "sample.env" ]]; then
            log_error ".env file not found. Please copy sample.env to .env and configure it:"
            log_info "  cp sample.env .env"
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
            log_error "Required environment variable $var is not set in .env file"
            exit 1
        fi
    done

    log_success "Environment configuration validated"
}

# Function: ensure_submodules
# Description: Ensure submodules are initialized (without updating)
ensure_submodules() {
    log_info "Ensuring submodules are initialized..."
    
    # Check if this is a git repository
    if git rev-parse --git-dir &> /dev/null 2>&1; then
        # Initialize submodules if they haven't been already
        if ! git submodule update --init --recursive; then
            log_warning "Failed to initialize submodules. Continuing anyway..."
        else
            log_success "Submodules are initialized"
        fi
    else
        log_info "Not a git repository, skipping submodule check"
    fi
}

# Function: build_services
# Description: Build missing container images
build_services() {
    log_info "Building container images..."
    
    # Clean up old build cache to prevent issues
    log_info "Cleaning Docker build cache..."
    docker builder prune --filter "until=24h" -f
    
    # Check what images exist
    log_info "Checking existing images..."
    local existing_images
    existing_images=$(docker images --format "{{.Repository}}" | grep "pgnc-external-stack" || true)
    
    if [[ -n "$existing_images" ]]; then
        log_info "Found existing images:"
        echo "$existing_images"
    fi
    
    # Use working configuration: BuildKit disabled to avoid hanging issues
    log_info "Building all services using docker compose with BuildKit disabled..."
    log_info "This may take several minutes for the first time..."
    log_warning "You may see a warning about 'Bake, but buildkit isn't enabled' - this is expected and safe to ignore"
    
    # Force legacy build method to prevent hanging issues and Bake warnings
    # This completely disables BuildKit and Bake integration
    export DOCKER_BUILDKIT=0
    export COMPOSE_DOCKER_CLI_BUILD=0
    docker compose build
    
    log_success "Container images built successfully"
}

# Function: get_service_health
# Description: Get the health status of a specific service
get_service_health() {
    local service_name="$1"

    local service_info
    service_info=$(docker compose ps --format json | jq "select(.Service == \"$service_name\")" 2>/dev/null)

    if [[ -z "$service_info" ]]; then
        echo "not_found"
        return
    fi

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
start_services() {
    log_info "Starting PGNC services..."

    # Create required networks if they don't exist
    docker network create pgnc-network 2>/dev/null || true

    log_info "Starting all services for the first time..."
    docker compose --env-file .env up -d

    log_success "Services started successfully"
}

# Function: wait_for_services
# Description: Wait for all services to be healthy or in their expected final state
wait_for_services() {
    local services_to_check=("pgncdb" "api" "angular" "solr" "nginx" "solr-client")
    local start_time=$SECONDS
    local timeout=300 # 5 minutes

    log_info "Waiting for services to reach expected states..."

    while [[ ${#services_to_check[@]} -gt 0 && $SECONDS -lt $((start_time + timeout)) ]]; do
        local i=0
        while [[ $i -lt ${#services_to_check[@]} ]]; do
            local service="${services_to_check[$i]}"
            local health
            health=$(get_service_health "$service")
            
            if [[ "$health" == "healthy" || "$health" == "running" ]]; then
                log_info "$service is ready ($health)"
                unset 'services_to_check[i]'
                services_to_check=("${services_to_check[@]}")
                continue
            fi
            i=$((i + 1))
        done

        if [[ ${#services_to_check[@]} -gt 0 ]]; then
            if [[ $((SECONDS % 30)) -eq 0 ]]; then
                log_info "Still waiting for: ${services_to_check[*]}"
            fi
            sleep 5
        fi
    done

    if [[ ${#services_to_check[@]} -eq 0 ]]; then
        log_success "All services are in expected states!"
        return 0
    fi

    log_error "Services did not reach expected states within $timeout seconds"
    log_info "Final status check:"
    if [[ ${#services_to_check[@]} -gt 0 ]]; then
        for service in "${services_to_check[@]}"; do
            local health
            health=$(get_service_health "$service")
            log_info "  $service: $health"
        done
    fi
    log_info "Full container status:"
    docker compose ps --all
    return 1
}

# Function: show_status
# Description: Display the status of all services and access URLs
show_status() {
    log_info "PGNC Environment Status:"
    echo
    
    # Show container status
    docker compose ps
    echo

    # Show access URLs
    log_info "Access URLs:"
    local nginx_port
    nginx_port=$(grep "LOCALHOST_NGINX_PORT" .env | cut -d'=' -f2)
    
    echo "  Frontend:     http://localhost:${nginx_port:-80}"
    echo "  API:          http://localhost:${nginx_port:-80}/api"
    echo "  Search:       http://localhost:${nginx_port:-80}/ses"
    
    echo
    log_info "Log monitoring:"
    echo "  All services: docker compose logs -f"
    echo "  Specific:     docker compose logs -f <service_name>"
}

# Function: main
# Description: Main execution flow for fresh environment setup
main() {
    log_info "Starting PGNC Environment for Fresh Installation"
    log_info "==============================================="

    parse_arguments "$@"
    check_prerequisites
    validate_env_file
    ensure_submodules

    log_info "Setting up PGNC environment from scratch"
    build_services
    start_services
    wait_for_services
    show_status

    log_success "PGNC environment is ready!"
}

# Execute main function with all arguments only if not in testing mode
if [[ "${TESTING_MODE:-}" != "true" ]]; then
    main "$@"
fi