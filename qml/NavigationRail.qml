import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Material 3 navigation rail.
//
// Noir's own navigation is the bar in the top bar. This is the arrangement it
// replaced, kept behind a setting for anyone who had learned it: the rail down
// the leading edge, which opens from a menu icon into Material's expanded form
// and shows pinned collections as secondary destinations while it is open.
//
// It owns no state of its own. The preference, the destinations it marks and
// the window actions at its foot all come from the window, so the two
// arrangements cannot drift into disagreeing about where you are.
ColumnLayout {
    id: rail
    objectName: "navigationRail"
    Accessible.role: Accessible.Pane
    Accessible.name: "Navigation"

    // Whether the person has asked for the wide form, and whether the window
    // can give it to them. Material places the expanded rail beside body
    // content, so it only opens where there is room for it.
    property bool expandedPreference: false
    property bool roomToExpand: false
    readonly property bool expanded: expandedPreference && roomToExpand
    property string current: ""
    // Secondary destinations, which only the expanded rail has room to show.
    property var pins: []
    // Pins show in both forms: as covers when collapsed, and with their names when expanded.
    readonly property var shownPins: pins
    property bool libraryPending: false
    // The surface's primary action lives in the window; the rail keeps a slot
    // the right size for it at its head.
    property bool fabApplies: false
    property real fabWidth: 0
    property real fabHeight: 0
    readonly property alias fabSlot: railFabSlot
    readonly property alias miniHost: railMiniHost
    readonly property alias settingsHost: railSettingsHost
    signal toggleRequested()
    signal chosen(string key)
    signal pinChosen(var item)
    // Right-click on a pin, in either form of the rail.
    signal pinMenuRequested(var item)

    // Material's expanded rail runs from 220dp to 360dp; it takes more of that
    // range as the window has room to give.
    // The extended FAB has to fit inside the expanded rail. Its label is set in
    // the pixel face, which is wider than Material's type, so the rail grows to
    // hold the FAB's width plus the item inset on each side, up to Material's 360dp.
    // Expanded, the rail is as wide as its largest element: the FAB, or the
    // widest label with its icon, plus the item inset on each side. Collapsed it
    // is the 96dp rail.
    readonly property real widestLabel: {
        let widest = 0
        for (let i = 0; i < labelMeasures.count; ++i) {
            const measured = labelMeasures.itemAt(i)
            if (measured) widest = Math.max(widest, measured.advanceWidth)
        }
        return widest
    }
    readonly property real elementWidth: Math.max(fabWidth, 24 + 12 + widestLabel + 16)
    property real shownWidth: expanded ? elementWidth + 2*itemInset : 96
    Repeater {
        id: labelMeasures
        model: ["Home", "Search", "Mini player", "Settings"]
        TextMetrics {
            required property string modelData
            text: modelData
            font.family: Theme.fontFamily
            font.pixelSize: Theme.labelLarge
            font.weight: Theme.weightFor(false, true, Theme.labelLarge, "labelLarge")
        }
    }
    // The rail is an overlay. The window lays out the page beside it as if the
    // rail were always 96dp, so this width can animate without reflowing the page.
    Behavior on shownWidth { NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
    width: shownWidth
    // Material's collapsed rail is 96dp wide and sets 4dp between its
    // destinations; the header above them keeps 8dp of its own.
    spacing: 8
    // WideNavigationRail.kt:1387 sets WNRItemHorizontalPadding, 20dp between
    // the rail's edge and an item's indicator: what 96dp leaves either side
    // of the collapsed 56dp indicator, so the indicator keeps its leading
    // edge as the rail opens. The rail keeps the same 20dp after its widest
    // item (:380). The glyph sits 16dp inside the indicator, at 36dp in both
    // forms, and the rest of the expanded rail lines up on those two edges.
    readonly property real itemInset: 20

    MButton {
        objectName: "navigationMenuButton"
        symbol: rail.expanded ? "menu_open" : "menu"
        tip: rail.expanded ? "Collapse navigation" : "Expand navigation"
        enabled: rail.roomToExpand
        Layout.alignment: rail.expanded ? Qt.AlignLeft : Qt.AlignHCenter
        // NavigationRailSamples.kt pads the header's icon button 24dp from the
        // start, which keeps its glyph on the destinations' 36dp keyline.
        Layout.leftMargin: rail.expanded ? 24 : 0
        onClicked: rail.toggleRequested()
    }
    // Material's rail carries the surface's primary action above its
    // destinations, as a FAB while the rail is collapsed and as an extended
    // FAB once it has opened and there is room for the words.
    Item {
        id: railFabSlot
        objectName: "railFabSlot"
        visible: rail.fabApplies
        // Expanded, the slot takes the FAB's natural width; collapsed, it is the 56dp square.
        Layout.preferredWidth: visible ? (rail.expanded ? rail.fabWidth : rail.fabHeight) : 0
        Layout.preferredHeight: visible ? rail.fabHeight : 0
        Layout.alignment: rail.expanded ? Qt.AlignLeft : Qt.AlignHCenter
        Layout.leftMargin: rail.expanded ? rail.itemInset : 0
        Layout.topMargin: 4; Layout.bottomMargin: 4
    }
    Repeater {
        // A constant list: a Repeater rebuilds every delegate when its model
        // changes, so pending state is a binding on the delegate rather than a
        // field in here.
        model: [{key:"library",icon:"home",label:"Home"},{key:"search",icon:"search",label:"Search"}]
        MNavigationItem {
            required property var modelData
            objectName: "nav_"+modelData.key
            expanded: rail.expanded
            // The item spans the rail in both forms and keeps the inset at
            // each end, so its indicator is 56dp at 96dp and follows the
            // rail's width exactly while it opens and closes.
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: rail.shownWidth
            itemPadding: rail.itemInset; trailingPadding: rail.itemInset
            Layout.preferredHeight: 56
            symbol: modelData.icon; text: modelData.label; selected: rail.current===modelData.key
            // Importing is pending work inside the library, so the destination
            // says so while it runs.
            badged: modelData.key==="library" && rail.libraryPending
            onClicked: rail.chosen(modelData.key)
        }
    }
    MDivider { objectName: "navigationDivider"; visible: rail.expanded && rail.shownPins.length>0; Layout.preferredWidth: rail.shownWidth-2*rail.itemInset; Layout.alignment: Qt.AlignLeft; Layout.leftMargin: rail.itemInset; Layout.topMargin: 4 }
    NoirText { objectName: "navigationPinnedLabel"; visible: rail.expanded && rail.shownPins.length>0; text: "Pinned"; color: Theme.muted; font.pixelSize: Math.round(Theme.titleSmall*1.1); typeRole: "titleSmall"; Layout.leftMargin: rail.itemInset+16; Layout.alignment: Qt.AlignLeft }
    // Pinned items scroll in the space the rail has left, so a long list never
    // pushes the window actions off the bottom. Each row elides its name to the
    // width it has.
    ListView {
        id: pinList
        objectName: "navigationPinList"
        visible: rail.shownPins.length>0
        // Spans the rail like the destinations above, for the same reason.
        Layout.preferredWidth: rail.shownWidth
        Layout.alignment: Qt.AlignLeft
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: rail.shownPins
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: MScrollBar {}
        delegate: MNavigationItem {
            required property var modelData
            required property int index
            objectName: "navPin_"+index
            width: pinList.width
            height: rail.expanded ? 56 : 64
            expanded: rail.expanded
            itemPadding: rail.itemInset; trailingPadding: rail.itemInset
            artSize: rail.expanded ? 48 : 52
            // A pin with no cover falls back to the playlist glyph.
            symbol: "queue"
            showCollapsedLabel: false
            artUrl: modelData.art || ""; text: modelData.title || ""
            selected: rail.current==="library" && !!modelData.id && rail.pinSelected(modelData)
            onClicked: rail.pinChosen(modelData)
            MouseArea {
                objectName: "navPinMenuArea"
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: rail.pinMenuRequested(modelData)
            }
        }
    }
    // Which pin, if any, is the collection on screen. The window knows; the
    // rail only draws the answer.
    property var pinSelected: function(item) { return false }
    // Takes the spare height when there are no pins, so the window actions sit at the foot.
    Item { Layout.fillHeight: !pinList.visible }
    // The window's actions sit at the foot of the rail in this arrangement and
    // in the top bar in the other one. They are one button either way, moved
    // between the two slots, so there is only ever one of each in the window.
    Item {
        id: railMiniHost
        Layout.preferredWidth: rail.expanded ? rail.shownWidth-2*rail.itemInset : 48
        Layout.preferredHeight: 48
        Layout.alignment: rail.expanded ? Qt.AlignLeft : Qt.AlignHCenter
        Layout.leftMargin: rail.expanded ? rail.itemInset : 0
    }
    Item {
        id: railSettingsHost
        Layout.preferredWidth: rail.expanded ? rail.shownWidth-2*rail.itemInset : 48
        Layout.preferredHeight: 48
        Layout.alignment: rail.expanded ? Qt.AlignLeft : Qt.AlignHCenter
        Layout.leftMargin: rail.expanded ? rail.itemInset : 0
        Layout.bottomMargin: 20
    }
}
