#!/usr/bin/env bash
# title:       cert-renewal.sh
# version:     2.0
# author:      PGNC Development Team
# date:        2025-10-17
# 
# Description:
# Modern SSL certificate renewal script using Docker Compose profiles.
# Replaces deprecated total-refresh.sh with modern Certbot workflow.
#
# Usage:
#   ./cert-renewal.sh [OPTIONS]
#
# Options:
#   --container-tool TOOL    Container tool (docker or podman, default: auto-detect)
#   --dry-run               Perform a dry run without making changes
#   --restart-nginx         Restart nginx after successful renewal (default: true)
#   --no-restart            Skip nginx restart
#   --help                  Show this help message
#
# Environment Variables:
#   CONTAINER_TOOL         Override container tool detection
#   RESTART_NGINX          Set to 'false' to skip nginx restart
#   DRY_RUN               Set to 'true' for dry run mode
#
# Cron examples:
#   # Run twice daily with automatic nginx restart
#   30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1
#   
#   # Run weekly with dry run first, then actual renewal
#   0 3 * * 0 cd /path/to/pgnc-external-stack && ./cert-renewal.sh --dry-run >> /var/log/pgnc-cert-renewal.log 2>&1
#   30 3 * * 0 cd /path/to/pgnc-external-stack && ./cert-renewal.sh >> /var/log/pgnc-cert-renewal.log 2>&1

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Default settings (can be overridden by environment variables or arguments)
CONTAINER_TOOL="${CONTAINER_TOOL:-}"
RESTART_NGINX="${RESTART_NGINX:-true}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${LOG_PREFIX} ${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${LOG_PREFIX} ${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${LOG_PREFIX} ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${LOG_PREFIX} ${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    echo -e "${LOG_PREFIX} ${CYAN}[DEBUG]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
Modern SSL Certificate Renewal Script v2.0

Usage: $0 [OPTIONS]

Options:
  --container-tool TOOL    Container tool (docker or podman, default: auto-detect)
  --dry-run               Perform a dry run without making changes
  --restart-nginx         Restart nginx after successful renewal (default: true)
  --no-restart            Skip nginx restart
  --help                  Show this help message

Environment Variables:
  CONTAINER_TOOL         Override container tool detection
  RESTART_NGINX          Set to 'false' to skip nginx restart
  DRY_RUN               Set to 'true' for dry run mode

Examples:
  $0                              # Standard renewal with auto-detection
  $0 --dry-run                    # Test renewal without making changes
  $0 --container-tool podman      # Use podman instead of docker
  $0 --no-restart                 # Renew without restarting nginx

Cron Examples:
  # Twice daily renewal with nginx restart
  30 2,14 * * * cd /path/to/pgnc-external-stack && $0 >> /var/log/pgnc-cert-renewal.log 2>&1
  
  # Weekly dry run followed by actual renewal
  0 3 * * 0 cd /path/to/pgnc-external-stack && $0 --dry-run >> /var/log/pgnc-cert-renewal.log 2>&1
  30 3 * * 0 cd /path/to/pgnc-external-stack && $0 >> /var/log/pgnc-cert-renewal.log 2>&1
EOF
}

# Container tool detection
detect_container_tool() {
    if [ -n "$CONTAINER_TOOL" ]; then
        log_debug "Using container tool from configuration: $CONTAINER_TOOL"
        return 0
    fi
    
    log_info "Auto-detecting container tool..."
    
    if command -v docker >/dev/null 2>&1; then
        # Check if Docker is actually running
        if docker info >/dev/null 2>&1; then
            CONTAINER_TOOL="docker"
            log_info "Detected and verified: docker"
            return 0
        else
            log_warning "Docker is installed but not running"
        fi
    fi
    
    if command -v podman >/dev/null 2>&1; then
        CONTAINER_TOOL="podman"
        log_info "Detected: podman"
        return 0
    fi
    
    log_error "No container tool found. Please install docker or podman."
    return 1
}

# Validate container tool
validate_container_tool() {
    if [[ "$CONTAINER_TOOL" != "docker" && "$CONTAINER_TOOL" != "podman" ]]; then
        log_error "Container tool must be either 'docker' or 'podman'. Got: $CONTAINER_TOOL"
        return 1
    fi
    
    if ! command -v "$CONTAINER_TOOL" >/dev/null 2>&1; then
        log_error "$CONTAINER_TOOL is not installed or not in PATH"
        return 1
    fi
    
    # Additional validation for Docker
    if [ "$CONTAINER_TOOL" = "docker" ]; then
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker is installed but not running or accessible"
            log_info "Try: sudo systemctl start docker"
            return 1
        fi
    fi
    
    log_debug "Container tool validation passed: $CONTAINER_TOOL"
    return 0
}

# Check if nginx service is running
is_nginx_running() {
    log_debug "Checking if nginx service is running..."
    
    if [ "$CONTAINER_TOOL" = "docker" ]; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="podman-compose"
    fi
    
    # Check if nginx service is defined and running
    if $COMPOSE_CMD ps nginx >/dev/null 2>&1; then
        # Check if it's actually running (not just defined)
        NGINX_STATUS=$($COMPOSE_CMD ps nginx --format "{{.State}}" 2>/dev/null || echo "unknown")
        if [ "$NGINX_STATUS" = "running" ] || [ "$NGINX_STATUS" = "Up" ]; then
            log_debug "Nginx service is running"
            return 0
        else
            log_debug "Nginx service is defined but not running (state: $NGINX_STATUS)"
            return 1
        fi
    else
        log_debug "Nginx service is not running or not defined"
        return 1
    fi
}

# Restart nginx service
restart_nginx() {
    log_info "Restarting nginx service..."
    
    if [ "$CONTAINER_TOOL" = "docker" ]; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="podman-compose"
    fi
    
    if $COMPOSE_CMD restart nginx; then
        log_success "Nginx service restarted successfully"
        return 0
    else
        log_error "Failed to restart nginx service"
        return 1
    fi
}

# Run certificate renewal
run_renewal() {
    log_info "Starting SSL certificate renewal process..."
    
    if [ "$CONTAINER_TOOL" = "docker" ]; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="podman-compose"
    fi
    
    # Build the renewal command
    RENEWAL_CMD="$COMPOSE_CMD --profile ssl run --rm certbot renew"
    
    if [ "$DRY_RUN" = "true" ]; then
        RENEWAL_CMD="$RENEWAL_CMD --dry-run"
        log_info "Running in DRY RUN mode - no actual changes will be made"
    fi
    
    log_info "Executing: $RENEWAL_CMD"
    
    # Run the renewal command
    if eval "$RENEWAL_CMD"; then
        if [ "$DRY_RUN" = "true" ]; then
            log_success "Certificate renewal dry run completed successfully"
        else
            log_success "Certificate renewal completed successfully"
        fi
        return 0
    else
        if [ "$DRY_RUN" = "true" ]; then
            log_error "Certificate renewal dry run failed"
        else
            log_error "Certificate renewal failed"
        fi
        return 1
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --container-tool)
                CONTAINER_TOOL="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --restart-nginx)
                RESTART_NGINX="true"
                shift
                ;;
            --no-restart)
                RESTART_NGINX="false"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    log_info "Starting modern SSL certificate renewal process"
    log_info "Script version: 2.0 (replaces deprecated total-refresh.sh)"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    log_debug "Working directory: $SCRIPT_DIR"
    
    # Detect and validate container tool
    if ! detect_container_tool; then
        exit 1
    fi
    
    if ! validate_container_tool; then
        exit 1
    fi
    
    log_info "Using container tool: $CONTAINER_TOOL"
    log_info "Dry run mode: $DRY_RUN"
    log_info "Restart nginx: $RESTART_NGINX"
    
    # Run certificate renewal
    if ! run_renewal; then
        exit 1
    fi
    
    # Restart nginx if requested and not in dry run mode
    if [ "$RESTART_NGINX" = "true" ] && [ "$DRY_RUN" != "true" ]; then
        if is_nginx_running; then
            if ! restart_nginx; then
                log_warning "Certificate renewal succeeded but nginx restart failed"
                exit 1
            fi
        else
            log_warning "Nginx service is not running, skipping restart"
        fi
    else
        if [ "$DRY_RUN" = "true" ]; then
            log_info "Skipping nginx restart (dry run mode)"
        else
            log_info "Skipping nginx restart (disabled via configuration)"
        fi
    fi
    
    log_success "SSL certificate renewal process completed successfully"
}

main "$@"
