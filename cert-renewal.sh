#!/usr/bin/env bash
# title:       cert-renewal.sh
# version:     1.0
# author:      PGNC Development Team
# date:        2025-08-05
# 
# Description:
# This script is designed to be run via cron for automatic SSL certificate renewal.
# It runs the certificate renewal process and logs the output for monitoring.
#
# Usage:
#   ./cert-renewal.sh [docker|podman]
#
# Cron example (run twice daily at 2:30 AM and 2:30 PM):
#   30 2,14 * * * cd /path/to/pgnc-external-stack && ./cert-renewal.sh docker >> /var/log/pgnc-cert-renewal.log 2>&1

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONTAINER_TOOL="${1:-docker}"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Colors for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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

main() {
    log_info "Starting automated SSL certificate renewal"
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    # Validate container tool
    if [[ "$CONTAINER_TOOL" != "docker" && "$CONTAINER_TOOL" != "podman" ]]; then
        log_error "Container tool must be either 'docker' or 'podman'. Got: $CONTAINER_TOOL"
        exit 1
    fi
    
    # Check if container tool is available
    if ! command -v "$CONTAINER_TOOL" &> /dev/null; then
        log_error "$CONTAINER_TOOL is not installed or not in PATH"
        exit 1
    fi
    
    # Run the renewal process
    if ./total-refresh.sh --container-tool "$CONTAINER_TOOL" --renew-certs; then
        log_success "SSL certificate renewal completed successfully"
    else
        log_error "SSL certificate renewal failed"
        exit 1
    fi
}

main "$@"
