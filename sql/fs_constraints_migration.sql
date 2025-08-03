-- Migration script to enforce ownership and cascading deletes on files table

-- Assign default owner (id 1) where owner is missing or invalid
UPDATE files f
SET owner_user_id = 1
WHERE owner_user_id IS NULL
   OR NOT EXISTS (
       SELECT 1 FROM users u WHERE u.id = f.owner_user_id
   );

-- Remove files whose parent reference is invalid
DELETE FROM files f
WHERE parent_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM files p WHERE p.id = f.parent_id
  );

-- Drop existing foreign key constraints
ALTER TABLE files DROP CONSTRAINT IF EXISTS files_parent_id_fkey;
ALTER TABLE files DROP CONSTRAINT IF EXISTS files_owner_user_id_fkey;

-- Apply NOT NULL and cascading foreign key constraints
ALTER TABLE files
    ALTER COLUMN owner_user_id SET NOT NULL,
    ADD CONSTRAINT files_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES files(id) ON DELETE CASCADE,
    ADD CONSTRAINT files_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE;
