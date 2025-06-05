--------------
-- FILESYSTEM
--------------

-- filesystem
CREATE TABLE IF NOT EXISTS files (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES files(id),  -- Directory structure
    owner_user_id INTEGER REFERENCES users(id),
    permissions TEXT NOT NULL,  -- e.g. 'rwxr-x---'
    contents TEXT DEFAULT '',
    is_directory BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT now(),
    group_id INTEGER REFERENCES groups(id)
);

-- File locks
CREATE TABLE IF NOT EXISTS file_locks (
    file_id INTEGER REFERENCES files(id),
    locked_by_user INTEGER REFERENCES users(id),
    lock_mode TEXT CHECK (lock_mode IN('read','write')),
    PRIMARY KEY(file_id, locked_by_user)
);

-- File versions for versioning
CREATE TABLE IF NOT EXISTS file_versions (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES files(id),
    version_number INTEGER,
    contents TEXT,
    created_at TIMESTAMP DEFAULT now()
);


-- Create a file or directory
CREATE OR REPLACE FUNCTION create_file(user_id INTEGER, filename TEXT, parent_id INTEGER, is_dir BOOLEAN DEFAULT FALSE) RETURNS INTEGER AS $$
DECLARE
    new_file_id INTEGER;
BEGIN
    IF NOT check_permission(user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to create files', user_id;
    END IF;

    INSERT INTO files (name, parent_id, owner_user_id, permissions, is_directory)
    VALUES (filename, parent_id, user_id, 'rwxr-----', is_dir)
    RETURNING id INTO new_file_id;

    RETURN new_file_id;
END;
$$ LANGUAGE plpgsql;


-- Write to a file
CREATE OR REPLACE FUNCTION write_file(user_id INTEGER, file_id INTEGER, data TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.is_directory THEN
        RAISE EXCEPTION 'Cannot write to a directory';
    END IF;

    -- Check if user is owner and has write permission or user has role that grants write
    IF f.owner_user_id = user_id THEN
        -- Owner permissions are in first three chars (e.g., 'rwx')
        IF substring(f.permissions from 1 for 3) NOT LIKE '%w%' THEN
            RAISE EXCEPTION 'Owner does not have write permission on this file';
        END IF;
    ELSIF NOT check_permission(user_id, 'file', 'write') THEN
        RAISE EXCEPTION 'User % does not have permission to write files', user_id;
    END IF;

    UPDATE files SET contents = data WHERE id = file_id;
END;
$$ LANGUAGE plpgsql;


-- Read from a file
CREATE OR REPLACE FUNCTION read_file(user_id INTEGER, file_id INTEGER) RETURNS TEXT AS $$
DECLARE
    f RECORD;
    result TEXT;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.is_directory THEN
        RAISE EXCEPTION 'Cannot read from a directory, list directory instead';
    END IF;

    -- Check read permission for owner or user permission
    IF f.owner_user_id = user_id THEN
        IF substring(f.permissions from 1 for 3) NOT LIKE 'r%' THEN
            RAISE EXCEPTION 'Owner does not have read permission on this file';
        END IF;
    ELSIF NOT check_permission(user_id, 'file', 'read') THEN
        RAISE EXCEPTION 'User % does not have permission to read files', user_id;
    END IF;

    result := f.contents;
    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- Change file permissions (owner only)
CREATE OR REPLACE FUNCTION change_file_permissions(user_id INTEGER, file_id INTEGER, new_perms TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id = file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    IF f.owner_user_id != user_id THEN
        RAISE EXCEPTION 'Only the owner can change file permissions';
    END IF;

    IF length(new_perms) != 9 THEN
        RAISE EXCEPTION 'Permissions string must be 9 characters (e.g. rwxr-xr--)';
    END IF;

    UPDATE files SET permissions = new_perms WHERE id = file_id;
END;
$$ LANGUAGE plpgsql;


-- Lock a file
CREATE OR REPLACE FUNCTION lock_file(user_id INTEGER, file_id INTEGER, mode TEXT) RETURNS VOID AS $$
DECLARE
    f RECORD;
BEGIN
    SELECT * INTO f FROM files WHERE id=file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    INSERT INTO file_locks (file_id, locked_by_user, lock_mode)
    VALUES (file_id, user_id, mode);
END;
$$ LANGUAGE plpgsql;


-- Unlock a file
CREATE OR REPLACE FUNCTION unlock_file(user_id INTEGER, file_id INTEGER) RETURNS VOID AS $$
BEGIN
    DELETE FROM file_locks
        WHERE file_id = unlock_file.file_id
          AND locked_by_user = user_id;
END;
$$ LANGUAGE plpgsql;


-- Save a version of a file before write
CREATE OR REPLACE FUNCTION version_file(file_id INTEGER) RETURNS VOID AS $$
DECLARE
    f RECORD;
    max_version INTEGER;
BEGIN
    SELECT * INTO f FROM files WHERE id=file_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'File not found';
    END IF;

    SELECT COALESCE(MAX(version_number),0) INTO max_version
        FROM file_versions
        WHERE file_versions.file_id = version_file.file_id;
    INSERT INTO file_versions (file_id, version_number, contents)
        VALUES (file_id, max_version+1, f.contents);
END;
$$ LANGUAGE plpgsql;
