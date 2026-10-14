import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("generate_source", Path(__file__).parents[1] / "generate-source.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.ipa = Path(self.directory.name) / "AutoSignStore.ipa"

    def build(self, version="1.0.1", extra=None, profile=False):
        info = {
            "CFBundleIdentifier": "local.autosign.store",
            "CFBundleDisplayName": "AutoSign Store",
            "CFBundleExecutable": "AutoSignStore",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "3",
            "MinimumOSVersion": "17.0",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "AutoSignStoreClient": True,
            "NSLocalNetworkUsageDescription": "发现同一 Wi-Fi 中的 Mac。",
        }
        info.update(extra or {})
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/AutoSignStore.app/Info.plist", plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
            archive.writestr("Payload/AutoSignStore.app/AutoSignStore", b"fixture-executable")
            if profile:
                archive.writestr("Payload/AutoSignStore.app/embedded.mobileprovision", b"private")

    def generate(self, tag="v1.0.1", previous=None):
        return generator.generate_source(self.ipa, "tignioj/auto-sign-store", tag, "2026-10-14T12:00:00Z", "更新说明", previous)

    def test_metadata_matches_exact_ipa(self):
        self.build()
        catalog = self.generate()
        app = catalog["apps"][0]
        release = app["versions"][0]
        self.assertEqual(app["bundleIdentifier"], "local.autosign.store")
        self.assertEqual(app["appPermissions"]["privacy"], {"NSLocalNetworkUsageDescription": "发现同一 Wi-Fi 中的 Mac。"})
        self.assertEqual(release["size"], self.ipa.stat().st_size)
        self.assertEqual(release["minOSVersion"], "17.0")
        self.assertEqual(release["buildVersion"], "3")
        self.assertEqual(release["localizedDescription"], "更新说明")
        self.assertEqual(release["downloadURL"], "https://github.com/tignioj/auto-sign-store/releases/download/v1.0.1/AutoSignStore.ipa")

    def test_history_and_reruns_do_not_downgrade_or_duplicate(self):
        self.build("1.10.0")
        previous = self.generate("v1.10.0")
        self.build("1.9.0")
        older = self.generate("v1.9.0", previous)
        rerun = self.generate("v1.9.0", older)
        self.assertEqual([item["version"] for item in rerun["apps"][0]["versions"]], ["1.10.0", "1.9.0"])

    def test_rejects_tag_mismatch_and_prereleases(self):
        self.build()
        for tag in ("v1.0.2", "1.0.1", "v1.0.1-beta"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                self.generate(tag)

    def test_rejects_simulator_unresolved_metadata_and_wrong_app(self):
        for extra in ({"CFBundleSupportedPlatforms": ["iPhoneSimulator"]},
                      {"CFBundleVersion": "$(CURRENT_PROJECT_VERSION)"},
                      {"MinimumOSVersion": ""}, {"AutoSignStoreClient": False},
                      {"CFBundleExecutable": "Missing"}):
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                self.build(extra=extra)
                self.generate()

    def test_rejects_private_provisioning_profile(self):
        self.build(profile=True)
        with self.assertRaises(ValueError):
            self.generate()

    def test_rejects_invalid_archive(self):
        self.ipa.write_text("<html>Download failed</html>")
        with self.assertRaises(zipfile.BadZipFile):
            self.generate()

    def test_rejects_bundle_identifier_change(self):
        self.build()
        previous = self.generate()
        self.build(extra={"CFBundleIdentifier": "different.app"})
        with self.assertRaises(ValueError):
            self.generate(previous=previous)


if __name__ == "__main__":
    unittest.main()
