BEGIN IMMEDIATE;
PRAGMA defer_foreign_keys=ON;
CREATE TABLE artist_name_alias (
 name_key TEXT NOT NULL,
 artist_id TEXT NOT NULL REFERENCES catalog_artist_identity(artist_key),
 PRIMARY KEY(name_key,artist_id)
);
CREATE TABLE artist_redirect (
 source_id TEXT PRIMARY KEY NOT NULL,
 target_id TEXT NOT NULL REFERENCES catalog_artist_identity(artist_key),
 CHECK(source_id<>target_id)
);
CREATE TEMP TABLE artist_id_upgrade (old_key TEXT PRIMARY KEY, new_id TEXT NOT NULL UNIQUE);
-- A catalog upgraded through v5 may not have materialized identities yet.
INSERT OR IGNORE INTO catalog_artist_identity
 SELECT artist_key,coalesce(json_extract(metadata_json,'$.displayName'),artist_key)
 FROM artist_record;
INSERT INTO artist_id_upgrade SELECT artist_key,'artist-'||lower(hex(randomblob(16))) FROM catalog_artist_identity;
INSERT INTO artist_name_alias SELECT old_key,new_id FROM artist_id_upgrade;
UPDATE library_artist_credit SET artist_key=(SELECT new_id FROM artist_id_upgrade WHERE old_key=artist_key);
UPDATE artist_membership SET band_key=(SELECT new_id FROM artist_id_upgrade WHERE old_key=band_key),member_key=(SELECT new_id FROM artist_id_upgrade WHERE old_key=member_key);
UPDATE artist_record SET metadata_json=json_set(metadata_json,'$.key',coalesce((SELECT new_id FROM artist_id_upgrade WHERE old_key=artist_key),artist_key),'$.memberKeys',json(coalesce((SELECT json_group_array(coalesce(m.new_id,j.value)) FROM json_each(metadata_json,'$.memberKeys') j LEFT JOIN artist_id_upgrade m ON m.old_key=j.value),'[]'))),artist_key=coalesce((SELECT new_id FROM artist_id_upgrade WHERE old_key=artist_key),artist_key);
UPDATE catalog_file_reference SET owner_id=coalesce((SELECT new_id FROM artist_id_upgrade WHERE old_key=owner_id),owner_id) WHERE owner_kind='artist';
UPDATE catalog_artist_identity SET artist_key=(SELECT new_id FROM artist_id_upgrade WHERE old_key=artist_key);
DROP TABLE artist_id_upgrade;
PRAGMA user_version=6;
COMMIT;
