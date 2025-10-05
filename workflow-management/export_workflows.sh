#!/bin/bash

################################################################################
# n8n Workflow Export Script
#
# This script exports all workflows from a self-hosted n8n instance using the
# n8n REST API. Each workflow is saved as a separate JSON file.
#
# Requirements:
#   - curl
#   - jq (JSON processor)
#
# Configuration:
#   Set environment variables in .env or pass them directly:
#   - N8N_API_URL: Base URL of your n8n instance (default: https://n8n.emoiseev.work)
#   - N8N_API_KEY: Your n8n API key (required)
#   - EXPORT_DIR: Directory to export workflows (default: ./exported_workflows)
#
# Usage:
#   ./export_workflows.sh
#
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output helper functions
print_error() {
    echo -e "${RED}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env file
load_environment() {
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        print_info "Loading configuration from .env"
        # shellcheck disable=SC1091
        source "${SCRIPT_DIR}/.env"
    fi
}

# Setup configuration with defaults
setup_configuration() {
    N8N_API_URL="${N8N_API_URL:-https://n8n.emoiseev.work}"
    N8N_API_KEY="${N8N_API_KEY:-}"
    EXPORT_DIR="${EXPORT_DIR:-${SCRIPT_DIR}/exported_workflows}"
    API_VERSION="v1"
    PAGE_LIMIT=250
}

# Validate dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

# Validate configuration
validate_config() {
    if [ -z "$N8N_API_KEY" ]; then
        print_error "Error: N8N_API_KEY is not set"
        echo "Please set it in .env or as an environment variable."
        echo ""
        echo "To generate an API key:"
        echo "  1. Login to your n8n instance"
        echo "  2. Go to Settings > API"
        echo "  3. Create a new API key"
        exit 1
    fi
}

# Make API call to n8n
api_call() {
    local url="$1"
    local response

    response=$(curl -s -f -X GET "$url" \
        -H "Accept: application/json" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" 2>&1) || {
        return 1
    }

    # Validate JSON response
    if ! echo "$response" | jq empty 2>/dev/null; then
        return 2
    fi

    echo "$response"
    return 0
}

# Sanitize filename by removing/replacing invalid characters
sanitize_filename() {
    local filename="$1"
    # Replace spaces with underscores, remove special chars except dash, underscore, and dot
    echo "$filename" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9._-]//g'
}

# Generate workflow filename
generate_workflow_filename() {
    local workflow_name="$1"
    local workflow_id="$2"
    local sanitized_name

    sanitized_name=$(sanitize_filename "$workflow_name")
    echo "${sanitized_name}_${workflow_id}.json"
}

# Extract workflow JSON from API response
extract_workflow_json() {
    local workflow_data="$1"

    # Extract workflow data if wrapped in 'data' property, otherwise use as-is
    if echo "$workflow_data" | jq -e '.data' >/dev/null 2>&1; then
        echo "$workflow_data" | jq '.data'
    else
        echo "$workflow_data"
    fi
}

# Build paginated URL for workflows
build_workflows_url() {
    local cursor="$1"
    local url="${N8N_API_URL}/api/${API_VERSION}/workflows?limit=${PAGE_LIMIT}"

    if [ -n "$cursor" ]; then
        url="${url}&cursor=${cursor}"
    fi

    echo "$url"
}

# Get next cursor from API response
get_next_cursor() {
    local response="$1"
    echo "$response" | jq -r '.nextCursor // ""'
}

# Check if there are more pages
has_more_pages() {
    local cursor="$1"
    [ -n "$cursor" ] && [ "$cursor" != "null" ]
}

# Initialize export statistics
init_stats() {
    STATS_SUCCESS=0
    STATS_FAIL=0
    STATS_SKIP=0
}

# Update statistics based on export result
update_stats() {
    local result="$1"

    if [ "$result" -eq 0 ]; then
        STATS_SUCCESS=$((STATS_SUCCESS + 1))
    elif [ "$result" -eq 2 ]; then
        STATS_SKIP=$((STATS_SKIP + 1))
    else
        STATS_FAIL=$((STATS_FAIL + 1))
    fi
}

# Print export statistics summary
print_stats() {
    echo ""
    print_info "========================================"
    print_success "Export completed!"
    print_success "Successfully exported: ${STATS_SUCCESS}"
    if [ "$STATS_SKIP" -gt 0 ]; then
        print_warning "Skipped (archived): ${STATS_SKIP}"
    fi
    if [ "$STATS_FAIL" -gt 0 ]; then
        print_error "Failed: ${STATS_FAIL}"
    fi
    print_info "Location: ${EXPORT_DIR}"
    print_info "========================================"
}

# Fetch and export workflows with pagination
fetch_and_export_workflows() {
    local cursor=""
    local page=0

    # Initialize statistics
    init_stats

    print_info "Fetching workflows from n8n..."
    echo ""

    while true; do
        local url
        url=$(build_workflows_url "$cursor")

        print_warning "Fetching page ${page}..."

        local response
        if ! response=$(api_call "$url"); then
            print_error "Error: Failed to fetch workflows"
            echo "URL: $url"
            echo ""
            echo "Possible causes:"
            echo "  - Invalid API URL (check N8N_API_URL)"
            echo "  - Invalid API key (check N8N_API_KEY)"
            echo "  - n8n API is not enabled"
            exit 1
        fi

        # Get workflow count on this page
        local count
        count=$(echo "$response" | jq '.data | length')
        print_success "Found ${count} workflows on page ${page}"

        # Export each workflow from this page
        for ((i=0; i<count; i++)); do
            local workflow
            workflow=$(echo "$response" | jq -c ".data[$i]")

            local id
            local name
            id=$(echo "$workflow" | jq -r '.id')
            name=$(echo "$workflow" | jq -r '.name // "unnamed"')

            # Call export_workflow and capture return code
            # Use || true to prevent set -e from exiting on non-zero return
            local result=0
            export_workflow "$id" "$name" || result=$?

            # Update statistics based on result
            update_stats "$result"
        done

        # Get next cursor and check if there are more pages
        cursor=$(get_next_cursor "$response")

        if ! has_more_pages "$cursor"; then
            break
        fi

        ((page++))
        echo ""
    done

    # Print statistics summary
    print_stats
}

# Export individual workflow
export_workflow() {
    local workflow_id="$1"
    local workflow_name="$2"

    print_warning "Exporting: ${workflow_name} (ID: ${workflow_id})"

    local url="${N8N_API_URL}/api/${API_VERSION}/workflows/${workflow_id}"

    local workflow_data
    if ! workflow_data=$(api_call "$url"); then
        print_error "Error: Failed to fetch workflow ${workflow_id}"
        return 1
    fi

    # Extract workflow JSON from response
    local workflow_json
    workflow_json=$(extract_workflow_json "$workflow_data")

    # Check if workflow is archived
    local is_archived
    is_archived=$(echo "$workflow_json" | jq -r '.isArchived // false')
    if [ "$is_archived" = "true" ]; then
        print_warning "⊘ Skipped (archived): ${workflow_name} (ID: ${workflow_id})"
        return 2
    fi

    # Generate filename and path
    local filename
    filename=$(generate_workflow_filename "$workflow_name" "$workflow_id")
    local filepath="${EXPORT_DIR}/${filename}"

    # Save workflow to file (pretty printed)
    echo "$workflow_json" | jq '.' > "$filepath"

    print_success "✓ Saved to: ${filename}"
    return 0
}

# Main execution
main() {
    print_info "========================================"
    print_info "n8n Workflow Export Script"
    print_info "========================================"
    echo ""

    # Load environment and setup configuration
    load_environment
    setup_configuration

    # Check dependencies
    check_dependencies

    # Validate configuration
    validate_config

    # Create export directory if it doesn't exist
    mkdir -p "$EXPORT_DIR"

    echo "Configuration:"
    echo "  API URL: ${N8N_API_URL}"
    echo "  Export Directory: ${EXPORT_DIR}"
    echo ""

    # Fetch and export all workflows
    fetch_and_export_workflows
}

# Run main function
main "$@"
