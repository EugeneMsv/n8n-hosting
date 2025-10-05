# n8n-hosting

Self-hosted n8n workflow automation platform with PostgreSQL backend.

## Overview

This repository contains Docker Compose configurations for running n8n with:
- PostgreSQL database for persistence
- Cloudflare tunnel for secure external access
- Flyway for database migrations

## Workflow Management

### Exporting Workflows

The `workflow-management/` directory contains scripts for managing n8n workflows via the REST API.

#### Prerequisites

- `curl` - HTTP client
- `jq` - JSON processor (`sudo apt install jq` on Ubuntu/Debian)
- n8n API key (see configuration below)

#### Configuration

1. **Generate an n8n API Key**:
   - Login to your n8n instance at https://n8n.emoiseev.work
   - Go to **Settings** → **API**
   - Click **Create API Key**
   - Copy the generated key

2. **Configure the export script**:
   ```bash
   cd workflow-management
   cp .env.export.example .env.export
   # Edit .env.export and add your API key
   nano .env.export
   ```

3. **Set your API key** in `.env.export`:
   ```bash
   N8N_API_KEY=your_actual_api_key_here
   ```

#### Usage

Export all workflows from your n8n instance:

```bash
cd workflow-management
./export_workflows.sh
```

The script will:
- Fetch all workflows using pagination (handles large workflow collections)
- Export each workflow as a separate JSON file
- Save files to `exported_workflows/` directory
- Overwrite existing files if they already exist
- Display progress and summary

#### Output Structure

```
workflow-management/
└── exported_workflows/
    ├── 1_customer_onboarding.json
    ├── 2_daily_reports.json
    ├── 3_slack_notifications.json
    └── ...
```

Each JSON file contains the complete workflow definition including:
- Workflow nodes and their configurations
- Node connections
- Workflow settings
- Metadata (created/updated timestamps)

#### Troubleshooting

**Error: Missing required dependencies**
```bash
sudo apt update
sudo apt install curl jq
```

**Error: N8N_API_KEY is not set**
- Make sure you've created `.env.export` from the template
- Verify the API key is correctly set in the file

**Error: Failed to fetch workflows**
- Check that your n8n instance is running
- Verify the API URL is correct in `.env.export`
- Ensure your API key is valid and has not been deleted