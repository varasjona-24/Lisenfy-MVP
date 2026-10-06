"""Validate Flutter discovery and alias-only launchers after manifest merging."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ANDROID = "{http://schemas.android.com/apk/res/android}"


def is_launcher(intent):
    return (
        any(a.get(ANDROID + "name") == "android.intent.action.MAIN"
            for a in intent.findall("action"))
        and any(c.get(ANDROID + "name") == "android.intent.category.LAUNCHER"
                for c in intent.findall("category"))
    )


class LauncherManifestTest(unittest.TestCase):
    def test_restore_sandbox_labels_and_provider_are_package_scoped(self):
        source = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
        app = source.find("application")
        self.assertEqual(app.get(ANDROID + "label"), "${listenfyAppLabel}")
        for alias in app.findall("activity-alias"):
            self.assertEqual(alias.get(ANDROID + "label"), "${listenfyAppLabel}")
        provider = app.find("provider")
        self.assertEqual(provider.get(ANDROID + "authorities"), "${applicationId}.android_auto_artwork")

    def test_flutter_source_discovery(self):
        source = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
        main = source.find("application/activity")
        self.assertEqual(main.get(ANDROID + "name"), ".MainActivity")
        self.assertTrue(any(map(is_launcher, main.findall("intent-filter"))))

    def test_merged_builds_keep_aliases_without_duplicate_launcher(self):
        for mode in ("debug", "profile", "release"):
            with self.subTest(mode=mode):
                path = ROOT / "build/app/intermediates/merged_manifest" / mode
                path /= f"process{mode.capitalize()}MainManifest/AndroidManifest.xml"
                if not path.exists():
                    self.skipTest(f"Run :app:process{mode.capitalize()}MainManifest first")
                app = ET.parse(path).find("application")
                main = next(a for a in app.findall("activity")
                            if a.get(ANDROID + "name").endswith(".MainActivity"))
                self.assertFalse(any(map(is_launcher, main.findall("intent-filter"))))
                self.assertEqual(len(main.findall("intent-filter")), 6)
                aliases = [a for a in app.findall("activity-alias")
                           if a.get(ANDROID + "enabled") != "false"
                           and any(map(is_launcher, a.findall("intent-filter")))]
                self.assertEqual(len(aliases), 1)
                self.assertTrue(aliases[0].get(ANDROID + "name").endswith(".LauncherOriginal"))


if __name__ == "__main__":
    unittest.main()
