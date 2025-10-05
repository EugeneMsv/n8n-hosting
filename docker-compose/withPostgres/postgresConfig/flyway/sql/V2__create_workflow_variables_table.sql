-- Create workflow_variables table
-- This migration creates a table to store workflow-scoped variables
-- Composite primary key ensures uniqueness per workflow, scope, and variable name

CREATE TABLE IF NOT EXISTS workflow_variables (
    workflow_id VARCHAR(64) NOT NULL,
    scope VARCHAR(64) NOT NULL,
    variable_name VARCHAR(64) NOT NULL,
    value VARCHAR(2048),
    PRIMARY KEY (workflow_id, scope, variable_name)
);

-- Add index for common query patterns
CREATE INDEX IF NOT EXISTS idx_workflow_variables_workflow_id_and_scope ON workflow_variables(workflow_id,scope);
