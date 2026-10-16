-- Contrato candidato v1 revisado; no activar cutover sin pruebas del repository.
-- Configuración WAL/synchronous pertenece al opener nativo, no a este DDL.
PRAGMA foreign_keys = ON;
BEGIN;
CREATE TABLE media_identity (
  media_id TEXT PRIMARY KEY NOT NULL,
  library_id TEXT,
  created_at_utc_ms INTEGER NOT NULL,
  retired_at_utc_ms INTEGER
);
CREATE TABLE media_alias (
  namespace TEXT NOT NULL,
  scope TEXT NOT NULL,
  value TEXT NOT NULL CHECK(length(value)>0),
  media_id TEXT NOT NULL REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  provenance TEXT NOT NULL,
  PRIMARY KEY(namespace,scope,value)
);
CREATE INDEX alias_media ON media_alias(media_id);
CREATE TABLE media_variant (
  variant_id TEXT PRIMARY KEY NOT NULL,
  media_id TEXT NOT NULL REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK(mode IN ('audio','video','unknown')),
  role TEXT NOT NULL,
  format TEXT,
  locator_kind TEXT CHECK(locator_kind IN ('local_path','file_uri','content_uri','http_url','imported_asset')),
  locator_value TEXT,
  availability TEXT NOT NULL DEFAULT 'unknown' CHECK(availability IN ('available','missing','unknown')),
  hash_algorithm TEXT,
  hash_version INTEGER,
  content_hash TEXT,
  created_at_utc_ms INTEGER NOT NULL,
  UNIQUE(variant_id,media_id,mode),
  CHECK((locator_kind IS NULL AND locator_value IS NULL) OR
    (locator_kind IS NOT NULL AND locator_value IS NOT NULL AND length(locator_value)>0)),
  CHECK((content_hash IS NULL AND hash_algorithm IS NULL AND hash_version IS NULL) OR
    (content_hash IS NOT NULL AND hash_algorithm IS NOT NULL AND hash_version IS NOT NULL
      AND hash_algorithm='sha256' AND hash_version=1))
);
CREATE INDEX variant_media ON media_variant(media_id,mode);
CREATE TABLE metadata_snapshot (
  snapshot_id TEXT PRIMARY KEY NOT NULL,
  content_hash TEXT NOT NULL,
  hash_algorithm TEXT NOT NULL CHECK(hash_algorithm='sha256'),
  canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version>0),
  title TEXT,
  artist TEXT,
  album TEXT,
  artwork_ref TEXT,
  provenance TEXT NOT NULL,
  UNIQUE(hash_algorithm,canonicalization_version,content_hash)
);
CREATE TRIGGER snapshot_no_update BEFORE UPDATE ON metadata_snapshot
BEGIN SELECT RAISE(ABORT,'historical snapshot is immutable'); END;
CREATE TABLE applied_command (
  command_id TEXT PRIMARY KEY NOT NULL,
  request_hash TEXT NOT NULL,
  hash_algorithm TEXT NOT NULL CHECK(hash_algorithm='sha256'),
  canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version>0),
  codec_version INTEGER NOT NULL CHECK(codec_version>0),
  applied_at_utc_ms INTEGER NOT NULL,
  result_json TEXT NOT NULL CHECK(length(CAST(result_json AS BLOB))<=65536)
);
CREATE TRIGGER command_no_update BEFORE UPDATE ON applied_command
BEGIN SELECT RAISE(ABORT,'applied command is immutable'); END;
CREATE TABLE playback_session (
  session_id TEXT PRIMARY KEY NOT NULL,
  media_id TEXT NOT NULL REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK(mode IN ('audio','video','unknown')),
  initial_variant_id TEXT NOT NULL,
  final_variant_id TEXT NOT NULL,
  snapshot_id TEXT NOT NULL REFERENCES metadata_snapshot(snapshot_id) ON DELETE RESTRICT,
  started_at_utc_ms INTEGER NOT NULL,
  ended_at_utc_ms INTEGER,
  timezone_id TEXT,
  timezone_quality TEXT NOT NULL DEFAULT 'unknown' CHECK(timezone_quality IN ('observed','unknown')),
  initial_position_ms INTEGER CHECK(initial_position_ms>=0),
  final_position_ms INTEGER CHECK(final_position_ms>=0),
  max_position_ms INTEGER CHECK(max_position_ms>=0),
  duration_ms INTEGER CHECK(duration_ms>0),
  initial_speed REAL CHECK(initial_speed>0),
  final_speed REAL CHECK(final_speed>0),
  resumed INTEGER CHECK(resumed IN (0,1)),
  context TEXT NOT NULL CHECK(context IN ('library','search','artist','album','playlist',
    'atlas','recommendations','mix','connect','android_auto','widget','notification',
    'manual_queue','automatic_queue','unknown')),
  source_id TEXT,
  status TEXT NOT NULL CHECK(status IN ('open','closed','interrupted','legacy')),
  termination_reason TEXT,
  valid_play INTEGER NOT NULL DEFAULT 0 CHECK(valid_play IN (0,1)),
  completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1)),
  skipped INTEGER NOT NULL DEFAULT 0 CHECK(skipped IN (0,1)),
  wall_ms INTEGER NOT NULL DEFAULT 0 CHECK(wall_ms>=0),
  media_ms INTEGER NOT NULL DEFAULT 0 CHECK(media_ms>=0),
  coverage_ms INTEGER CHECK(coverage_ms>=0),
  completion_ratio REAL CHECK(completion_ratio BETWEEN 0 AND 1),
  progress_ratio REAL CHECK(progress_ratio BETWEEN 0 AND 1),
  skip_threshold_basis_points INTEGER NOT NULL DEFAULT 9200 CHECK(skip_threshold_basis_points=9200),
  policy_version INTEGER NOT NULL CHECK(policy_version>0),
  aggregate_scope TEXT NOT NULL CHECK(aggregate_scope IN
    ('baseline_covered','post_cutover','independent','unresolved')),
  provenance TEXT NOT NULL CHECK(provenance IN ('observed','imported','estimated','unknown')),
  last_sequence INTEGER NOT NULL DEFAULT 0 CHECK(last_sequence>=0),
  UNIQUE(session_id,media_id,mode),
  CHECK((status='open' AND ended_at_utc_ms IS NULL AND termination_reason IS NULL) OR
    (status IN ('closed','interrupted') AND ended_at_utc_ms IS NOT NULL AND termination_reason IS NOT NULL) OR
    (status='legacy' AND provenance='imported')),
  CHECK(NOT(completed=1 AND skipped=1)),
  CHECK(provenance='imported' OR skipped=0 OR
    (status='closed' AND termination_reason IN ('manual_next','manual_previous','manual_selection')
     AND progress_ratio IS NOT NULL AND progress_ratio<0.92)),
  CHECK(provenance='imported' OR completed=0 OR
    (status='closed' AND (termination_reason='natural_end' OR
      (termination_reason IN ('manual_next','manual_previous','manual_selection')
        AND progress_ratio IS NOT NULL AND progress_ratio>=0.92)))),
  FOREIGN KEY(initial_variant_id,media_id,mode)
    REFERENCES media_variant(variant_id,media_id,mode) ON DELETE RESTRICT,
  FOREIGN KEY(final_variant_id,media_id,mode)
    REFERENCES media_variant(variant_id,media_id,mode) ON DELETE RESTRICT
);
CREATE INDEX session_history ON playback_session(started_at_utc_ms DESC,session_id DESC);
CREATE INDEX session_media_history ON playback_session(media_id,mode,started_at_utc_ms,session_id);
CREATE INDEX session_mode_history ON playback_session(mode,started_at_utc_ms,session_id);
CREATE TRIGGER session_transition BEFORE UPDATE OF status ON playback_session
WHEN OLD.status<>NEW.status AND NOT(OLD.status='open' AND NEW.status IN ('closed','interrupted'))
BEGIN SELECT RAISE(ABORT,'illegal session transition'); END;
CREATE TRIGGER session_terminal_immutable BEFORE UPDATE ON playback_session
WHEN OLD.status IN ('closed','interrupted','legacy')
BEGIN SELECT RAISE(ABORT,'terminal session is immutable'); END;
CREATE TABLE playback_event (
  event_id TEXT PRIMARY KEY NOT NULL,
  session_id TEXT NOT NULL REFERENCES playback_session(session_id) ON DELETE RESTRICT,
  sequence INTEGER NOT NULL CHECK(sequence>0),
  type TEXT NOT NULL CHECK(type IN ('play','pause','resume','seek','buffering_start',
    'buffering_end','speed_change','variant_change','checkpoint','complete','skip',
    'stop','error','interruption_start','interruption_end','clock_discontinuity','legacy_import')),
  occurred_at_utc_ms INTEGER NOT NULL,
  utc_offset_minutes INTEGER CHECK(utc_offset_minutes BETWEEN -840 AND 840),
  timezone_id TEXT,
  event_version INTEGER NOT NULL CHECK(event_version>0),
  codec_version INTEGER NOT NULL CHECK(codec_version>0),
  clock_epoch TEXT,
  monotonic_ms INTEGER CHECK(monotonic_ms>=0),
  position_ms INTEGER CHECK(position_ms>=0),
  payload_version INTEGER NOT NULL CHECK(payload_version>0),
  payload_json TEXT NOT NULL CHECK(length(CAST(payload_json AS BLOB))<=65536),
  command_id TEXT NOT NULL REFERENCES applied_command(command_id) ON DELETE RESTRICT,
  command_event_index INTEGER NOT NULL CHECK(command_event_index>=0),
  UNIQUE(command_id,command_event_index),
  UNIQUE(session_id,sequence)
);
CREATE INDEX event_time ON playback_event(occurred_at_utc_ms,event_id);
CREATE TRIGGER event_no_update BEFORE UPDATE ON playback_event
BEGIN SELECT RAISE(ABORT,'journal events are immutable'); END;
-- DELETE no se bloquea con trigger: privacidad/retención usan mantenimiento
-- autorizado y transaccional. La API normal no expone DELETE del journal.
CREATE TABLE playback_interval (
  interval_id TEXT PRIMARY KEY NOT NULL,
  session_id TEXT NOT NULL,
  media_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  variant_id TEXT NOT NULL,
  start_sequence INTEGER NOT NULL,
  end_sequence INTEGER NOT NULL CHECK(end_sequence>start_sequence),
  started_at_utc_ms INTEGER NOT NULL,
  ended_at_utc_ms INTEGER NOT NULL CHECK(ended_at_utc_ms>=started_at_utc_ms),
  clock_epoch TEXT NOT NULL,
  wall_ms INTEGER NOT NULL CHECK(wall_ms>=0),
  media_ms INTEGER NOT NULL CHECK(media_ms>=0),
  start_position_ms INTEGER NOT NULL CHECK(start_position_ms>=0),
  end_position_ms INTEGER NOT NULL CHECK(end_position_ms>=start_position_ms),
  speed REAL NOT NULL CHECK(speed>0),
  quality TEXT NOT NULL CHECK(quality IN ('observed','estimated','unknown')),
  UNIQUE(session_id,start_sequence,end_sequence),
  FOREIGN KEY(session_id,media_id,mode)
    REFERENCES playback_session(session_id,media_id,mode) ON DELETE RESTRICT,
  FOREIGN KEY(variant_id,media_id,mode)
    REFERENCES media_variant(variant_id,media_id,mode) ON DELETE RESTRICT,
  FOREIGN KEY(session_id,start_sequence)
    REFERENCES playback_event(session_id,sequence) ON DELETE RESTRICT,
  FOREIGN KEY(session_id,end_sequence)
    REFERENCES playback_event(session_id,sequence) ON DELETE RESTRICT
);
CREATE INDEX interval_window ON playback_interval(started_at_utc_ms,ended_at_utc_ms);
CREATE INDEX interval_mode_window ON playback_interval(mode,started_at_utc_ms);
CREATE INDEX interval_variant ON playback_interval(variant_id,started_at_utc_ms);
CREATE TABLE playback_aggregate (
  media_id TEXT NOT NULL REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK(mode IN ('audio','video','unknown')),
  session_count INTEGER NOT NULL CHECK(session_count>=0),
  play_count INTEGER NOT NULL CHECK(play_count>=0),
  completed_count INTEGER NOT NULL CHECK(completed_count>=0),
  skip_count INTEGER NOT NULL CHECK(skip_count>=0),
  wall_ms INTEGER NOT NULL CHECK(wall_ms>=0),
  media_ms INTEGER NOT NULL CHECK(media_ms>=0),
  completion_sum REAL NOT NULL CHECK(completion_sum>=0),
  completion_samples INTEGER NOT NULL CHECK(completion_samples>=0),
  first_played_at_utc_ms INTEGER,
  last_played_at_utc_ms INTEGER,
  last_completed_at_utc_ms INTEGER,
  projection_version INTEGER NOT NULL CHECK(projection_version>0),
  PRIMARY KEY(media_id,mode),
  CHECK(completion_sum<=completion_samples)
);
CREATE TABLE migration_state (
  migration_id TEXT PRIMARY KEY NOT NULL,
  source_id TEXT NOT NULL,
  source_hash TEXT NOT NULL,
  hash_algorithm TEXT NOT NULL CHECK(hash_algorithm='sha256'),
  canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version>0),
  target_schema_version INTEGER NOT NULL,
  cutover_at_utc_ms INTEGER NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('staging','failed','verified','verified_with_rejects','activated')),
  cursor TEXT,
  imported_count INTEGER NOT NULL DEFAULT 0 CHECK(imported_count>=0),
  rejected_count INTEGER NOT NULL DEFAULT 0 CHECK(rejected_count>=0),
  UNIQUE(source_id,source_hash,target_schema_version)
);
CREATE TABLE migration_reject (
  migration_id TEXT NOT NULL REFERENCES migration_state(migration_id) ON DELETE RESTRICT,
  source_ordinal INTEGER NOT NULL,
  raw_json TEXT NOT NULL,
  reason TEXT NOT NULL,
  PRIMARY KEY(migration_id,source_ordinal)
);
CREATE TABLE legacy_metrics (
  baseline_id TEXT PRIMARY KEY NOT NULL,
  media_id TEXT NOT NULL REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  mode TEXT NOT NULL CHECK(mode IN ('audio','video','unknown')),
  migration_id TEXT NOT NULL REFERENCES migration_state(migration_id) ON DELETE RESTRICT,
  source_record_id TEXT NOT NULL,
  play_count INTEGER CHECK(play_count>=0),
  skip_count INTEGER CHECK(skip_count>=0),
  completed_count INTEGER CHECK(completed_count>=0),
  avg_progress REAL CHECK(avg_progress BETWEEN 0 AND 1),
  last_played_at_utc_ms INTEGER,
  last_completed_at_utc_ms INTEGER,
  provenance TEXT NOT NULL,
  UNIQUE(migration_id,source_record_id)
);
CREATE TABLE feedback_event (
  feedback_id TEXT PRIMARY KEY NOT NULL,
  command_id TEXT NOT NULL REFERENCES applied_command(command_id) ON DELETE RESTRICT,
  command_event_index INTEGER NOT NULL CHECK(command_event_index>=0),
  event_version INTEGER NOT NULL CHECK(event_version>0),
  codec_version INTEGER NOT NULL CHECK(codec_version>0),
  media_id TEXT REFERENCES media_identity(media_id) ON DELETE RESTRICT,
  target_kind TEXT NOT NULL CHECK(target_kind IN ('media','artist','tag')),
  target_key TEXT NOT NULL CHECK(length(target_key)>0),
  action TEXT NOT NULL CHECK(action IN ('like','dislike','hide','unhide','bias','legacy_baseline')),
  value REAL,
  occurred_at_utc_ms INTEGER,
  payload_version INTEGER NOT NULL CHECK(payload_version>0),
  payload_json TEXT NOT NULL CHECK(length(CAST(payload_json AS BLOB))<=65536),
  provenance TEXT NOT NULL CHECK(provenance IN ('observed','imported')),
  UNIQUE(command_id,command_event_index),
  CHECK((target_kind='media' AND media_id IS NOT NULL AND target_key=media_id) OR
    (target_kind IN ('artist','tag') AND media_id IS NULL)),
  CHECK((action IN ('bias','legacy_baseline') AND value IS NOT NULL) OR
    (action IN ('like','dislike','hide','unhide') AND value IS NULL)),
  CHECK((action='legacy_baseline' AND occurred_at_utc_ms IS NULL AND provenance='imported') OR
    (action<>'legacy_baseline' AND occurred_at_utc_ms IS NOT NULL))
);
CREATE TRIGGER feedback_no_update BEFORE UPDATE ON feedback_event
BEGIN SELECT RAISE(ABORT,'feedback journal is immutable'); END;
CREATE INDEX feedback_target ON feedback_event(target_kind,target_key,occurred_at_utc_ms);
CREATE TABLE repository_state (
  singleton INTEGER PRIMARY KEY CHECK(singleton=1),
  revision INTEGER NOT NULL CHECK(revision>=0)
);
INSERT INTO repository_state VALUES(1,0);
PRAGMA user_version = 1;
COMMIT;
