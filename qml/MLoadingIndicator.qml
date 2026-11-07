import QtQuick

// Pixel-style loading indicator: one square that turns on its centre.
//
// It replaces Material's morphing loading shape (LoadingIndicator.kt), which
// the pixel style does not use. The turn keeps Material's 4666 ms period for
// the continuous rotation, so the rhythm stays where it was. The determinate
// form fills the square from the bottom as progress runs from nought to one,
// the same way the old circle grew into the burst.
Item {
    id: indicator

    property bool running: false
    property color ink: Theme.primary
    // Filling the container gives a contained square; leaving it clear gives
    // the uncontained one, which is the default.
    property color trackColor: "transparent"
    property string label: "Loading"
    // Nought to one fills the square; below nought it turns instead.
    property real progress: -1
    readonly property bool determinate: progress >= 0

    readonly property bool animating: running && !determinate && visible && app.motion
        && Window.window !== null && Window.window.visible
        && Window.window.visibility !== Window.Minimized

    // Material's container is 48dp with a 38dp active indicator inside it.
    implicitWidth: 48
    implicitHeight: 48
    visible: running
    Accessible.role: Accessible.Indicator
    Accessible.name: label
    Accessible.ignored: !visible

    property real spin: 0

    Rectangle {
        anchors.fill: parent
        color: indicator.trackColor
    }

    Item {
        id: square
        objectName: "loadingSquare"
        anchors.centerIn: parent
        width: Math.min(indicator.width, indicator.height) * 38 / 48
        height: width
        rotation: indicator.determinate ? 0 : indicator.spin

        // Outline of the square, drawn in the ink colour.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(2, Math.round(square.width / 8))
            border.color: indicator.ink
        }
        // Determinate fill, rising from the bottom edge.
        Rectangle {
            objectName: "loadingSquareFill"
            visible: indicator.determinate
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: parent.height * Math.max(0, Math.min(1, indicator.progress))
            color: indicator.ink
        }
    }

    NumberAnimation {
        target: indicator; property: "spin"; from: 0; to: 360
        duration: 4666; loops: Animation.Infinite; running: indicator.animating
    }
}
