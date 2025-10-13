-- name: InsertTask :one
INSERT INTO tasks
	(id, organization_id, owner_id, name, workspace_id, template_version_id, template_parameters, prompt, created_at)
VALUES
	(gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: UpdateTaskWorkspaceID :one
UPDATE tasks
SET workspace_id = $2
FROM
	workspaces w,
	template_versions tv
WHERE tasks.id = $1
	-- Protect against updates that break the data integrity.
	AND tasks.workspace_id IS NULL
	AND w.id = $2
	AND tv.id = tasks.template_version_id
	AND w.template_id = tv.template_id
RETURNING tasks.*;

-- name: UpsertTaskWorkspaceApp :one
INSERT INTO task_workspace_apps
	(task_id, workspace_build_number, workspace_agent_id, workspace_app_id)
VALUES
	($1, $2, $3, $4)
ON CONFLICT (task_id, workspace_build_number)
DO UPDATE SET
	workspace_agent_id = EXCLUDED.workspace_agent_id,
	workspace_app_id = EXCLUDED.workspace_app_id
RETURNING *;

-- name: GetTaskByID :one
SELECT * FROM tasks_with_status WHERE id = @id::uuid;

-- name: GetTaskByWorkspaceID :one
SELECT * FROM tasks_with_status WHERE workspace_id = @workspace_id::uuid;
