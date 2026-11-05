package com.example.listenfy;

import java.io.File;
import java.io.IOException;

/** Only app-owned image directories may be shared with media clients. */
public final class ArtworkPathPolicy {
    private static final String[] DIRECTORIES = {
        "downloads/covers", "media/covers", "ListenfyCaptures"
    };

    private ArtworkPathPolicy() {}

    public static boolean isAllowed(File requested, File[] roots) throws IOException {
        File file = requested.getCanonicalFile();
        if (!file.isFile()) return false;
        for (File root : roots) {
            if (root == null) continue;
            File base = root.getCanonicalFile();
            for (String relative : DIRECTORIES) {
                File images = new File(base, relative).getCanonicalFile();
                // A symlinked image directory must not escape the app's root.
                if (isInside(images, base) && isInside(file, images)) return true;
            }
        }
        return false;
    }

    private static boolean isInside(File file, File root) {
        return file.getPath().startsWith(root.getPath() + File.separator);
    }
}
