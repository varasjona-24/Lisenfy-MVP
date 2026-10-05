-- Restoration is mutable operational state, not historical playback evidence.
BEGIN IMMEDIATE;
CREATE TABLE playback_restoration (
  mode TEXT PRIMARY KEY NOT NULL CHECK(mode IN ('audio','video')),
  payload_version INTEGER NOT NULL CHECK(payload_version=1),
  payload_json TEXT NOT NULL,
  updated_at_utc_ms INTEGER NOT NULL
);
CREATE TABLE playback_resume (
  mode TEXT NOT NULL CHECK(mode IN ('audio','video')),
  track_key TEXT NOT NULL CHECK(length(track_key)>0),
  position_ms INTEGER NOT NULL CHECK(position_ms>=0),
  trusted_watch_ms INTEGER CHECK(trusted_watch_ms>=0),
  PRIMARY KEY(mode,track_key)
);
CREATE TABLE restoration_import (
  source_id TEXT PRIMARY KEY NOT NULL,
  source_hash TEXT NOT NULL,
  imported_at_utc_ms INTEGER NOT NULL
);
PRAGMA user_version=2;
COMMIT;
