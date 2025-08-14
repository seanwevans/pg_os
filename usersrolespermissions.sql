-----------------------------
-- USER, ROLES & PERMISSIONS
-----------------------------



-- users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    role_name TEXT UNIQUE NOT NULL
);

-- user roles
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id),
    role_id INTEGER NOT NULL REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

-- permissions
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    resource_type TEXT NOT NULL CHECK (resource_type IN ('process', 'file', 'resource', 'memory')),
    action TEXT NOT NULL CHECK (action IN ('read','write','execute','allocate','delete'))
);

-- groups
CREATE TABLE IF NOT EXISTS groups (
    id SERIAL PRIMARY KEY,
    group_name TEXT UNIQUE NOT NULL
);

-- user groups
CREATE TABLE IF NOT EXISTS user_groups (
    user_id INTEGER REFERENCES users(id),
    group_id INTEGER REFERENCES groups(id),
    PRIMARY KEY(user_id, group_id)
);

-- group permissions
CREATE TABLE IF NOT EXISTS group_permissions (
    id SERIAL PRIMARY KEY,
    group_id INTEGER REFERENCES groups(id),
    resource_type TEXT NOT NULL CHECK (resource_type IN ('process', 'file', 'resource', 'memory')),
    action TEXT NOT NULL CHECK (action IN ('read','write','execute','allocate','delete'))
);



-- create a user
CREATE OR REPLACE FUNCTION create_user(name TEXT) RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    IF name IS NULL OR btrim(name) = '' THEN
        RAISE EXCEPTION 'username cannot be empty';
    END IF;
    INSERT INTO users (username) VALUES (name) RETURNING id INTO new_user_id;
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;

-- create a role
CREATE OR REPLACE FUNCTION create_role(role_name TEXT) RETURNS INTEGER AS $$
DECLARE
    new_role_id INTEGER;
BEGIN
    INSERT INTO roles (role_name) VALUES (role_name) RETURNING id INTO new_role_id;
    RETURN new_role_id;
END;
$$ LANGUAGE plpgsql;

-- Assign a role to a user
CREATE OR REPLACE FUNCTION assign_role_to_user(user_id INTEGER, role_id INTEGER) RETURNS VOID AS $$
BEGIN
    INSERT INTO user_roles (user_id, role_id) VALUES (user_id, role_id);
END;
$$ LANGUAGE plpgsql;

-- Grant permission to a role
CREATE OR REPLACE FUNCTION grant_permission_to_role(role_id INTEGER, resource_type TEXT, action TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO permissions (role_id, resource_type, action) VALUES (role_id, resource_type, action);
END;
$$ LANGUAGE plpgsql;

-- check permissions
CREATE OR REPLACE FUNCTION check_permission(p_user_id INTEGER, p_resource_type TEXT, p_action TEXT) RETURNS BOOLEAN AS $$
DECLARE
    allowed BOOLEAN;
BEGIN
    -- First check user roles
    SELECT TRUE INTO allowed
    FROM user_roles ur
    JOIN permissions p ON ur.role_id = p.role_id
    WHERE ur.user_id = p_user_id
      AND p.resource_type = p_resource_type
      AND p.action = p_action
    LIMIT 1;

    IF allowed THEN
        RETURN TRUE;
    END IF;

    -- If not allowed by user roles, check group permissions
    SELECT TRUE INTO allowed
    FROM user_groups ug
    JOIN group_permissions gp ON ug.group_id = gp.group_id
    WHERE ug.user_id = p_user_id
      AND gp.resource_type = p_resource_type
      AND gp.action = p_action
    LIMIT 1;

    RETURN COALESCE(allowed, FALSE);
END;
$$ LANGUAGE plpgsql;
