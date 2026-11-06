package com.example.listenfy;

/** Center crop shared by the media artwork renderer and its geometry tests. */
public final class ArtworkCropBounds {
    private ArtworkCropBounds() {}

    public static int[] centeredSquare(int width, int height) {
        if (width <= 0 || height <= 0) {
            throw new IllegalArgumentException("Artwork dimensions must be positive");
        }
        int side = Math.min(width, height);
        int left = (width - side) / 2;
        int top = (height - side) / 2;
        return new int[] {left, top, left + side, top + side};
    }
}
