import QtQuick

// Pixel-art depth. The interface is boxy and pixelated, so a raised surface
// casts a hard, solid shadow: the same rectangle, dropped down and to the right
// by a whole number of pixels, in the shade colour. There is no falloff, since
// a soft edge is exactly what the pixel style leaves out.
//
// Material's level still decides how far a surface lifts. Level 0 casts
// nothing; each level above it adds depth in pixels, from 2 at level 1 to 8 at
// level 5 (Material's key shadow offsets run 1 to 4 dp across the same levels,
// and these are that scale at a pixel step).
//
// This belongs behind an opaque surface, never in front of one.
Item {
    id: shade
    objectName: "elevation"

    property int level: 0
    // Kept for callers that pass a corner. Shadows are square, so it stays 0
    // in the pixel style and is still followed when it is not.
    property real radius: 0

    readonly property int step: Math.max(0, Math.min(5, level))
    readonly property int depth: [0, 2, 3, 4, 6, 8][step]
    visible: step > 0
    z: -1

    Rectangle {
        objectName: "elevationShadow"
        x: shade.depth
        y: shade.depth
        width: shade.width
        height: shade.height
        radius: shade.radius
        color: Theme.shade
    }
}
