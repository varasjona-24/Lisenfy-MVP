BEGIN IMMEDIATE;
-- Per-record compatibility persistence for durable modules; not a GetStorage blob.
CREATE TABLE app_domain_state (
  namespace TEXT PRIMARY KEY NOT NULL,
  shape TEXT NOT NULL CHECK(shape IN ('list','map'))
);
CREATE TABLE app_domain_record (
  namespace TEXT NOT NULL REFERENCES app_domain_state(namespace) ON DELETE CASCADE,
  record_key TEXT NOT NULL,
  ordinal INTEGER NOT NULL CHECK(ordinal>=0),
  parent_key TEXT,
  payload_json TEXT NOT NULL,
  PRIMARY KEY(namespace,record_key)
);
CREATE INDEX app_domain_parent ON app_domain_record(namespace,parent_key);
CREATE TABLE app_domain_file (
  namespace TEXT NOT NULL,
  record_key TEXT NOT NULL,
  slot TEXT NOT NULL,
  locator TEXT NOT NULL CHECK(length(locator)>0),
  PRIMARY KEY(namespace,record_key,slot),
  FOREIGN KEY(namespace,record_key) REFERENCES app_domain_record(namespace,record_key) ON DELETE CASCADE
);
CREATE TABLE app_domain_import (
  source_id TEXT PRIMARY KEY NOT NULL,
  source_hash TEXT NOT NULL,
  imported_at_utc_ms INTEGER NOT NULL
);
PRAGMA user_version=4;
COMMIT;
