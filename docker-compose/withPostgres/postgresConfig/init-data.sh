#!/bin/bash
set -e;


if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER "${POSTGRES_NON_ROOT_USER}" WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO "${POSTGRES_NON_ROOT_USER}";
		GRANT CREATE ON SCHEMA public TO "${POSTGRES_NON_ROOT_USER}";
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi

# Create N8N_EXECUTION database with restricted user
if [ -n "${POSTGRES_N8N_EXECUTION_USER:-}" ] && [ -n "${POSTGRES_N8N_EXECUTION_PASSWORD:-}" ]; then
	echo "SETUP INFO: Creating N8N_EXECUTION database and restricted user..."

	# Create database and user
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE DATABASE n8n_execution;
		CREATE USER "${POSTGRES_N8N_EXECUTION_USER}" WITH PASSWORD '${POSTGRES_N8N_EXECUTION_PASSWORD}';
		GRANT CONNECT ON DATABASE n8n_execution TO "${POSTGRES_N8N_EXECUTION_USER}";
	EOSQL

	# Execute schema creation script if it exists
	SCHEMA_SCRIPT="/docker-entrypoint-initdb.d/n8n_execution_schema.sql"
	if [ -f "$SCHEMA_SCRIPT" ]; then
		echo "SETUP INFO: Executing schema creation script..."
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "n8n_execution" -f "$SCHEMA_SCRIPT"
	else
		echo "SETUP INFO: Schema script not found at $SCHEMA_SCRIPT, skipping..."
	fi

	# Grant DML-only privileges (no DDL rights)
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "n8n_execution" <<-EOSQL
		GRANT USAGE ON SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";
		GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";
		GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "${POSTGRES_N8N_EXECUTION_USER}";

		-- Set default privileges for future tables (DML only)
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${POSTGRES_N8N_EXECUTION_USER}";
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO "${POSTGRES_N8N_EXECUTION_USER}";
	EOSQL

	echo "SETUP INFO: N8N_EXECUTION database setup complete."
else
	echo "SETUP INFO: POSTGRES_N8N_EXECUTION_USER or POSTGRES_N8N_EXECUTION_PASSWORD not set, skipping N8N_EXECUTION database creation."
fi
