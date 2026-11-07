import QtQuick

// A controller button drawn small, to sit next to the control it stands for.
// It shows only while `shown` is true, which the owner ties to the controller
// guide setting and to a controller being in use.
Item {
    id: glyph
    property string kind: ""
    property bool shown: false
    visible: shown && kind.length > 0
    width: 12; height: 12

    // PlayStation square: a filled block.
    Rectangle {
        visible: glyph.kind === "square"
        anchors.centerIn: parent; width: 8; height: 8; color: Theme.text
    }
    // PlayStation circle: a ring.
    Rectangle {
        visible: glyph.kind === "circle"
        anchors.centerIn: parent; width: 10; height: 10; radius: 5
        color: "transparent"; border.width: 2; border.color: Theme.text
    }
    // PlayStation triangle, pointing up.
    Icon {
        visible: glyph.kind === "triangle"
        anchors.centerIn: parent; name: "play"; size: 12; ink: Theme.text; rotation: -90
    }
    // Arrows for D-pad left and right.
    Icon {
        visible: glyph.kind === "left" || glyph.kind === "right"
        anchors.centerIn: parent; name: "back"; size: 12; ink: Theme.text
        rotation: glyph.kind === "right" ? 180 : 0
    }
    // Options, shown as three lines.
    Icon {
        visible: glyph.kind === "menu"
        anchors.centerIn: parent; name: "menu"; size: 12; ink: Theme.text
    }
    // Shoulder and stick buttons, and Select, as small labels.
    Rectangle {
        visible: glyph.kind === "SEL"
        anchors.centerIn: parent; width: 22; height: 12
        color: "transparent"; border.width: 1; border.color: Theme.text
    }
    NoirText {
        visible: ["L1", "R1", "L2", "R2", "L3", "R3", "SEL"].indexOf(glyph.kind) >= 0
        anchors.centerIn: parent; text: glyph.kind; color: Theme.text
        font.pixelSize: Theme.bodySmall
    }
}
