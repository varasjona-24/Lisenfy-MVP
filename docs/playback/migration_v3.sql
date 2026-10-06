-- Mutable catalog data is separate from immutable playback evidence.
BEGIN IMMEDIATE;
CREATE TABLE library_record (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id)>0),
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  metadata_json TEXT NOT NULL
);
CREATE TABLE library_variant (
  item_id TEXT NOT NULL REFERENCES library_record(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  kind TEXT NOT NULL CHECK(kind IN ('audio','video')),
  format TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  PRIMARY KEY(item_id,ordinal)
);
CREATE TABLE playlist_record (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id)>0),
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  metadata_json TEXT NOT NULL
);
CREATE TABLE playlist_member (
  playlist_id TEXT NOT NULL REFERENCES playlist_record(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  item_key TEXT NOT NULL,
  PRIMARY KEY(playlist_id,ordinal)
);
-- item_key may be a public alias, or refer to an absent/deleted local file.
-- Do not cascade deletion from library into playlists or playback history.
CREATE INDEX playlist_member_item ON playlist_member(item_key);
CREATE TABLE artist_record (
  artist_key TEXT PRIMARY KEY NOT NULL CHECK(length(artist_key)>0),
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  metadata_json TEXT NOT NULL
);
CREATE TABLE catalog_file_reference (
  owner_kind TEXT NOT NULL CHECK(owner_kind IN ('library','playlist','artist')),
  owner_id TEXT NOT NULL,
  slot TEXT NOT NULL,
  locator_kind TEXT NOT NULL CHECK(locator_kind IN ('local_path','http_url')),
  locator TEXT NOT NULL CHECK(length(locator)>0),
  PRIMARY KEY(owner_kind,owner_id,slot)
);
CREATE TABLE catalog_import (
  source_id TEXT PRIMARY KEY NOT NULL,
  source_hash TEXT NOT NULL,
  imported_at_utc_ms INTEGER NOT NULL
);
PRAGMA user_version=3;
COMMIT;
