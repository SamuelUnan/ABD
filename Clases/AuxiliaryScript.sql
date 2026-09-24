-- Created tables
SELECT name, type_desc
FROM sys.tables
ORDER BY name;

-- Key constraints of the Cat_Model table
SELECT tc.name AS constraint_name, tc.type, col.name AS column_name
FROM sys.key_constraints tc
JOIN sys.index_columns ic ON ic.object_id = tc.parent_object_id AND ic.index_id = tc.unique_index_id
JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
WHERE tc.parent_object_id = OBJECT_ID('Cat_Model');

-- Check constraints of Cat_Vehicle
SELECT name, definition
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('Cat_Vehicle');