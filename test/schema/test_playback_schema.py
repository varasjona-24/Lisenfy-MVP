"""DDL invariant tests, independent of Flutter; run with python3 -m unittest discover -s test/schema."""
import pathlib
import sqlite3
import unittest

SCHEMA = pathlib.Path(__file__).resolve().parents[2] / 'docs/playback/schema_v1.sql'


class PlaybackSchemaTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.executescript(SCHEMA.read_text())
        self.db.execute("INSERT INTO media_identity VALUES('m',NULL,0,NULL)")
        self.db.execute("INSERT INTO media_variant(variant_id,media_id,mode,role,created_at_utc_ms) VALUES('v','m','audio','normal',0)")
        self.db.execute("INSERT INTO metadata_snapshot(snapshot_id,content_hash,hash_algorithm,canonicalization_version,provenance) VALUES('snap','hash','sha256',1,'observed')")
        self.db.execute("INSERT INTO applied_command VALUES('cmd','hash','sha256',1,1,0,'{}')")
        self.db.execute("INSERT INTO playback_session(session_id,media_id,mode,initial_variant_id,final_variant_id,snapshot_id,started_at_utc_ms,context,status,policy_version,aggregate_scope,provenance) VALUES('s','m','audio','v','v','snap',0,'library','open',1,'post_cutover','observed')")

    def tearDown(self):
        self.db.close()

    def reject(self, sql, args=()):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute(sql, args)

    def event(self, event_id, sequence, index):
        self.db.execute("INSERT INTO playback_event(event_id,session_id,sequence,type,occurred_at_utc_ms,event_version,codec_version,payload_version,payload_json,command_id,command_event_index) VALUES(?, 's',?,'checkpoint',0,1,1,1,'{}','cmd',?)", (event_id, sequence, index))

    def feedback(self, **overrides):
        values = dict(feedback_id='f',command_id='cmd',command_event_index=0,event_version=1,codec_version=1,media_id='m',target_kind='media',target_key='m',action='like',value=None,occurred_at_utc_ms=0,payload_version=1,payload_json='{}',provenance='observed')
        values.update(overrides)
        keys = ','.join(values)
        return f"INSERT INTO feedback_event({keys}) VALUES({','.join('?' for _ in values)})", tuple(values.values())

    def test_alias_unique_and_fk(self):
        sql = "INSERT INTO media_alias VALUES('local','install','id','m','observed')"
        self.db.execute(sql)
        self.reject(sql)
        self.reject("INSERT INTO media_alias VALUES('local','install','other','missing','observed')")

    def test_command_multiple_events_and_duplicate_index(self):
        self.event('e1',1,0)
        self.event('e2',2,1)
        self.reject("INSERT INTO applied_command VALUES('cmd','different','sha256',1,1,0,'{}')")
        self.reject("UPDATE applied_command SET request_hash='changed'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.event('e3',3,1)

    def test_journal_immutable_and_sequence_unique(self):
        self.event('e1',1,0)
        self.reject("UPDATE playback_event SET payload_json='changed'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.event('e2',1,1)

    def test_feedback_combinations(self):
        for invalid in ({'media_id':None}, {'target_key':'different'}, {'target_kind':'artist'}, {'action':'bias'}, {'value':1}, {'occurred_at_utc_ms':None}):
            self.reject(*self.feedback(**invalid))
        self.db.execute(*self.feedback())
        self.reject("UPDATE feedback_event SET action='hide'")

    def test_legacy_feedback_only_unknown_timestamp(self):
        self.db.execute(*self.feedback(action='legacy_baseline',value=0.5,occurred_at_utc_ms=None,provenance='imported'))

    def test_session_transition_and_terminal_immutable(self):
        self.reject("UPDATE playback_session SET status='closed'")
        self.db.execute("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='explicit_stop'")
        self.reject("UPDATE playback_session SET wall_ms=999")
        self.reject("UPDATE playback_session SET status='open',ended_at_utc_ms=NULL,termination_reason=NULL")

    def test_skip_below_92(self):
        self.db.execute("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='manual_next',progress_ratio=0.9199,skipped=1")

    def test_skip_at_92_rejected_and_completed_allowed(self):
        self.reject("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='manual_next',progress_ratio=0.92,skipped=1")
        self.db.execute("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='manual_next',progress_ratio=0.92,completed=1")

    def test_pause_and_unknown_duration_not_skip(self):
        self.reject("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='explicit_stop',progress_ratio=0.2,skipped=1")
        self.reject("UPDATE playback_session SET status='closed',ended_at_utc_ms=100,termination_reason='manual_next',skipped=1")

    def test_interval_regression_and_cross_mode(self):
        self.event('e1',1,0)
        self.event('e2',2,1)
        sql = "INSERT INTO playback_interval VALUES('interval','s','m',?,'v',1,2,0,100,'epoch',100,100,?, ?,1,'observed')"
        self.reject(sql,('audio',100,0))
        self.reject(sql,('video',0,100))
        self.db.execute(sql,('audio',0,100))
        self.reject("DELETE FROM playback_event")
        self.db.execute("DELETE FROM playback_interval")
        self.db.execute("DELETE FROM playback_event")
        self.db.execute("DELETE FROM playback_session")

    def test_snapshot_immutable_locator_pair(self):
        self.reject("UPDATE metadata_snapshot SET title='new'")
        self.reject("UPDATE media_variant SET locator_kind='local_path'")
        self.db.execute("UPDATE media_variant SET locator_kind='local_path',locator_value='/new/path'")

    def test_integrity_and_atomic_rollback(self):
        self.db.commit()
        self.db.execute('BEGIN')
        self.event('e1',1,0)
        self.db.rollback()
        self.assertEqual(self.db.execute('SELECT count(*) FROM playback_event').fetchone()[0],0)
        self.assertEqual(self.db.execute('PRAGMA integrity_check').fetchone()[0],'ok')
        self.assertEqual(self.db.execute('PRAGMA foreign_key_check').fetchall(),[])


if __name__ == '__main__':
    unittest.main()
