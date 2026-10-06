BEGIN IMMEDIATE;
CREATE TABLE catalog_artist_identity (artist_key TEXT PRIMARY KEY NOT NULL, display_name TEXT NOT NULL);
CREATE TABLE library_credit_state (
 item_id TEXT PRIMARY KEY NOT NULL REFERENCES library_record(id) ON DELETE CASCADE,
 raw_credit TEXT NOT NULL,
 interpretation TEXT NOT NULL CHECK(interpretation IN ('legacy_parsed','ambiguous','empty'))
);
CREATE TABLE library_artist_credit (
 item_id TEXT NOT NULL REFERENCES library_record(id) ON DELETE CASCADE,
 artist_key TEXT NOT NULL REFERENCES catalog_artist_identity(artist_key),
 ordinal INTEGER NOT NULL CHECK(ordinal>=0),
 role TEXT NOT NULL CHECK(role IN ('primary','featured')),
 provenance TEXT NOT NULL,
 PRIMARY KEY(item_id,artist_key), UNIQUE(item_id,ordinal)
);
CREATE TABLE artist_membership (
 band_key TEXT NOT NULL REFERENCES catalog_artist_identity(artist_key),
 member_key TEXT NOT NULL REFERENCES catalog_artist_identity(artist_key),
 ordinal INTEGER NOT NULL CHECK(ordinal>=0), provenance TEXT NOT NULL,
 PRIMARY KEY(band_key,member_key), CHECK(band_key<>member_key)
);
PRAGMA user_version=5;
COMMIT;
