"""Exercise the actual Android artwork path policy on a JVM, without an emulator."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class ArtworkPathsTest(unittest.TestCase):
    def test_covers_are_readable_without_exposing_other_private_files(self):
        source = ROOT / "android/app/src/main/java/com/example/listenfy/ArtworkPathPolicy.java"
        with tempfile.TemporaryDirectory(prefix="listenfy-artwork-policy-") as directory:
            work = Path(directory)
            harness = work / "ArtworkPolicyTest.java"
            harness.write_text(r'''package com.example.listenfy;
import java.io.File;
import java.nio.file.Files;
public final class ArtworkPolicyTest {
  public static void main(String[] args) throws Exception {
    int[][] sizes = {{1280,720}, {720,1280}, {640,640}, {1281,720}, {1,1}};
    int[][] expected = {{280,0,1000,720}, {0,280,720,1000}, {0,0,640,640}, {280,0,1000,720}, {0,0,1,1}};
    for (int i = 0; i < sizes.length; i++) {
      int[] crop = ArtworkCropBounds.centeredSquare(sizes[i][0],sizes[i][1]);
      if (!java.util.Arrays.equals(crop, expected[i])) throw new AssertionError("crop " + i);
    }
    try {
      ArtworkCropBounds.centeredSquare(0,720);
      throw new AssertionError("invalid size accepted");
    } catch (IllegalArgumentException expectedError) {}
    File root = new File(args[0], "app"); root.mkdirs();
    File external = new File(args[0], "external"); external.mkdirs();
    File[] roots = {root, external, null};
    String[] valid = {"downloads/covers/song.jpg", "media/covers/song.png", "ListenfyCaptures/capture.jpg"};
    for (String name : valid) {
      File file = new File(root, name); file.getParentFile().mkdirs(); Files.write(file.toPath(), new byte[]{1});
      if (!ArtworkPathPolicy.isAllowed(file, roots)) throw new AssertionError(name);
    }
    String[] invalid = {"settings.json", "downloads/covers-evil/key", "media/covers/../../secret", "downloads/covers/missing.jpg"};
    for (String name : invalid) {
      File file = new File(root, name).getCanonicalFile(); file.getParentFile().mkdirs();
      if (!name.endsWith("missing.jpg")) Files.write(file.toPath(), new byte[]{1});
      if (ArtworkPathPolicy.isAllowed(file, roots)) throw new AssertionError(name);
    }
    File externalCover = new File(external, "media/covers/external.jpg"); externalCover.getParentFile().mkdirs(); Files.write(externalCover.toPath(),new byte[]{1});
    if (!ArtworkPathPolicy.isAllowed(externalCover, roots)) throw new AssertionError("external cover");
    File outside = new File(args[0], "outside.jpg"); Files.write(outside.toPath(),new byte[]{1});
    File link = new File(root,"downloads/covers/escape.jpg"); Files.createSymbolicLink(link.toPath(),outside.toPath());
    if (ArtworkPathPolicy.isAllowed(link, roots)) throw new AssertionError("symlink escape");
    File linkedRoot = new File(args[0],"linked-app"); linkedRoot.mkdirs();
    Files.createSymbolicLink(new File(linkedRoot,"ListenfyCaptures").toPath(),outside.getParentFile().toPath());
    if (ArtworkPathPolicy.isAllowed(new File(linkedRoot,"ListenfyCaptures/outside.jpg"),new File[]{linkedRoot})) throw new AssertionError("directory symlink escape");
  }
}''')
            subprocess.run(["javac", "-d", str(work), str(source), str(source.with_name("ArtworkCropBounds.java")), str(harness)], check=True)
            subprocess.run(["java", "-cp", str(work), "com.example.listenfy.ArtworkPolicyTest", str(work)], check=True)

if __name__ == "__main__":
    unittest.main()
