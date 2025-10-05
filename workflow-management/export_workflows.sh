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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env if it exists
if [ -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${BLUE}Loading configuration from .env${NC}"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
fi

# Configuration with defaults
N8N_API_URL="${N8N_API_URL:-https://n8n.emoiseev.work}"
N8N_API_KEY="${N8N_API_KEY:-}"
EXPORT_DIR="${EXPORT_DIR:-${SCRIPT_DIR}/exported_workflows}"
API_VERSION="v1"
PAGE_LIMIT=250

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
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo "Please install them and try again."
        exit 1
    fi
}

# Validate configuration
validate_config() {
    if [ -z "$N8N_API_KEY" ]; then
        echo -e "${RED}Error: N8N_API_KEY is not set${NC}"
        echo "Please set it in .env or as an environment variable."
        echo ""
        echo "To generate an API key:"
        echo "  1. Login to your n8n instance"
        echo "  2. Go to Settings > API"
        echo "  3. Create a new API key"
        exit 1
    fi
}

# Sanitize filename by removing/replacing invalid characters
sanitize_filename() {
    local filename="$1"
    # Replace spaces with underscores, remove special chars except dash, underscore, and dot
    echo "$filename" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9._-]//g'
}

# Fetch and export workflows with pagination
fetch_and_export_workflows() {
    local cursor=""
    local page=0
    local total_success=0
    local total_fail=0
    local total_skip=0

    echo -e "${BLUE}Fetching workflows from n8n...${NC}"
    echo ""

    while true; do
        local url="${N8N_API_URL}/api/${API_VERSION}/workflows?limit=${PAGE_LIMIT}"

        if [ -n "$cursor" ]; then
            url="${url}&cursor=${cursor}"
        fi

        echo -e "${YELLOW}Fetching page ${page}...${NC}"

        local response
        response=$(curl -s -f -X GET "$url" \
            -H "Accept: application/json" \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" 2>&1) || {
            echo -e "${RED}Error: Failed to fetch workflows${NC}"
            echo "Response: $response"
            echo "URL: $url"
            exit 1
        }

        # Validate JSON response
        if ! echo "$response" | jq empty 2>/dev/null; then
            echo -e "${RED}Error: Invalid JSON response from API${NC}"
            echo "Response: $response"
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
        echo -e "${GREEN}Found ${count} workflows on page ${page}${NC}"

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
            export_workflow "$id" "$name" || result=$?

            if [ ${result:-0} -eq 0 ]; then
                total_success=$((total_success + 1))
            elif [ ${result:-0} -eq 2 ]; then
                total_skip=$((total_skip + 1))
            else
                total_fail=$((total_fail + 1))
            fi

            # Reset result for next iteration
            result=0
        done

        # Get next cursor
        local next_cursor
        next_cursor=$(echo "$response" | jq -r '.nextCursor // ""')

        if [ -z "$next_cursor" ] || [ "$next_cursor" == "null" ]; then
            break
        fi

        cursor="$next_cursor"
        ((page++))
        echo ""
    done

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Export completed!${NC}"
    echo -e "${GREEN}Successfully exported: ${total_success}${NC}"
    if [ "$total_skip" -gt 0 ]; then
        echo -e "${YELLOW}Skipped (archived): ${total_skip}${NC}"
    fi
    if [ "$total_fail" -gt 0 ]; then
        echo -e "${RED}Failed: ${total_fail}${NC}"
    fi
    echo -e "${BLUE}Location: ${EXPORT_DIR}${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Export individual workflow
export_workflow() {
    local workflow_id="$1"
    local workflow_name="$2"

    echo -e "${YELLOW}Exporting: ${workflow_name} (ID: ${workflow_id})${NC}"

    local url="${N8N_API_URL}/api/${API_VERSION}/workflows/${workflow_id}"

    local workflow_data
    workflow_data=$(curl -s -f -X GET "$url" \
        -H "Accept: application/json" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" 2>&1) || {
        echo -e "${RED}Error: Failed to fetch workflow ${workflow_id}${NC}"
        return 1
    }

    # Validate JSON response
    if ! echo "$workflow_data" | jq empty 2>/dev/null; then
        echo -e "${RED}Error: Invalid JSON response for workflow ${workflow_id}${NC}"
        return 1
    fi

    # Extract workflow data if wrapped in 'data' property, otherwise use as-is
    local workflow_json
    if echo "$workflow_data" | jq -e '.data' >/dev/null 2>&1; then
        workflow_json=$(echo "$workflow_data" | jq '.data')
    else
        workflow_json="$workflow_data"
    fi

    # Check if workflow is archived
    local is_archived
    is_archived=$(echo "$workflow_json" | jq -r '.isArchived // false')
    if [ "$is_archived" = "true" ]; then
        echo -e "${YELLOW}⊘ Skipped (archived): ${workflow_name} (ID: ${workflow_id})${NC}"
        return 2
    fi

    # Sanitize workflow name for filename
    local sanitized_name
    sanitized_name=$(sanitize_filename "$workflow_name")

    # Create filename: {id}_{name}.json
    local filename="${sanitized_name}_${workflow_id}.json"
    local filepath="${EXPORT_DIR}/${filename}"

    # Save workflow to file (pretty printed)
    echo "$workflow_json" | jq '.' > "$filepath"

    echo -e "${GREEN}✓ Saved to: ${filename}${NC}"
    return 0
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}n8n Workflow Export Script${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

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
