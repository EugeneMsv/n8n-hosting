-- Repeatable migration: Grant DML-only privileges to n8n_execution user
-- This runs on every Flyway execution to ensure privileges are current

-- Switch to n8n_execution database context
-- Note: Flyway will be configured to run this against n8n_execution database

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";

-- Grant DML privileges on all existing tables (no DDL rights)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";

-- Grant sequence usage
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";

-- Set default privileges for future tables created by postgres superuser
-- This ensures any tables created by migrations will automatically grant DML to the user
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${POSTGRES_N8N_EXECUTION_USER}";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO "${POSTGRES_N8N_EXECUTION_USER}";