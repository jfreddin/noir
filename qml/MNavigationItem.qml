import QtQuick
import QtQuick.Controls

AbstractButton {
    id: control
    property string symbol: ""
    // Secondary destinations are collections, so they identify themselves by cover.
    property string artUrl: ""
    property bool selected: false
    property bool expanded: false
    // A pinned playlist shows its cover at this size, instead of an icon.
    property int artSize: 24
    // The sidebar's icons are 10% larger than the app's 24dp ones.
    readonly property int iconSize: 26
    // A pinned playlist shows only its cover when collapsed; its name is for the expanded sidebar.
    property bool showCollapsedLabel: true
    // Pending work in this destination. A count draws Material's large badge,
    // `badged` alone draws the dot.
    property bool badged: false
    property int badgeCount: -1
    // Where the glyph leads the label, a rail's item keeps 20dp between its
    // leading edge and the indicator (WNRItemHorizontalPadding); a drawer's
    // item is its indicator and keeps none. NavigationItem.kt makes the
    // whole item selectable and shows the ripple on the indicator alone, so
    // the padding still takes the click but never shows a state.
    property real itemPadding: 0
    // The same margin after the indicator. A rail item spans the whole rail
    // and keeps the inset at both ends, so its indicator is whatever lies
    // between them: the 56dp square at the collapsed 96dp, the full row once
    // open (WideNavigationRail.kt:380 and :1387).
    property real trailingPadding: 0
    implicitWidth: expanded ? 220 : 80
    // Material's rail item container is 64dp tall.
    implicitHeight: expanded ? 56 : 64
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected
    // Clipped to the item, so a highlight or its hover never spills into a neighbour.
    background: Item {
        clip: true
        Rectangle {
            id: pill
            objectName: "navigationIndicator"
            // M3 lets the expanded indicator fill its container rather than hug
            // the label; the target area spans the full rail either way.
            // The indicator is the space between the two paddings in both
            // forms, so its size comes from the rail's own width as it
            // animates and needs no spring of its own. A spring here chased a
            // target that moved every frame and trailed the rail and its FAB.
            x: control.itemPadding
            // Material wraps the glyph in the indicator with (32-24)/2 either
            // side of it, so the two share a centre. Stacked, that puts the
            // indicator 4dp down from the top of the container.
            y: control.expanded ? 0 : 4
            // Material's active indicator is 56 by 32 where the destination is
            // stacked, and fills its container where it is laid out in a row.
            // Stacked, the highlight is the same 56dp square as the rail's FAB,
            // centred in the item, with the label inside it: the owner's
            // paddings leave 56dp between them there.
            width: parent.width-control.itemPadding-control.trailingPadding
            // The expanded highlight stops 3dp short, the depth of its shadow, so the
            // shadow stays inside the item.
            height: control.expanded ? parent.height-3 : 56
            // The indicator's shape is full; pressing squares it towards the
            // large step, which is the app's own interaction feel rather than
            // anything Material asks for.
            radius: control.down ? Theme.shapeLarge : Theme.shapeFull(height)
            // Material's navigation colours are the secondary pair. The
            // indicator is the secondary container, its content the ink that
            // belongs on it, and the label the secondary role itself.
            //
            // The rectangle itself is the item's hover and press area; the
            // indicator is the fill inside it. NavigationItem.kt:1226-1230 and
            // 692 grow its width out from the centre by a progress that runs
            // on DefaultSpatial, and 1251 fades it by the same progress, so it
            // arrives as a shape rather than a colour.
            color: "transparent"
            // The 4dp drop and the height change have fixed ends, so they run
            // on the rail's own spring and land with it.
            Behavior on y { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
            Behavior on height { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
            Behavior on radius { enabled: app.motion; NumberAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } }
            property real progress: control.selected ? 1 : 0
            Behavior on progress { enabled: app.motion; NumberAnimation { objectName: "navigationIndicatorGrowth"; duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
            Rectangle {
                objectName: "navigationIndicatorFill"
                width: parent.width*Math.max(0, parent.progress); height: parent.height
                x: (parent.width-width)/2
                radius: parent.radius
                color: Theme.secondaryContainer
                opacity: Math.min(1, Math.max(0, parent.progress))
                visible: parent.progress > 0
                // The same pixel depth as the rail's FAB (level 3), in both
                // forms. It belongs to the fill, so it grows, fades and leaves
                // with the selection, and an unselected item casts none.
                MElevation { anchors.fill: parent; radius: parent.radius; level: 3 }
            }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                color: Theme.secondaryContainerText
                opacity: control.down || control.visualFocus ? Theme.pressedOpacity : control.hovered ? Theme.hoverOpacity : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.fastEffectsCurve } }
            }
        }
        Rectangle {
            objectName: "navigationFocusRing"
            anchors.fill: parent; anchors.margins: 2; radius: Theme.shapeLarge
            // Expanded, 2dp inside the indicator. Collapsed, 2dp inside the
            // 80dp item Material stacks the destination in, centred.
            anchors.leftMargin: control.expanded ? control.itemPadding+2 : (control.width-80)/2+2
            anchors.rightMargin: control.expanded ? control.trailingPadding+2 : (control.width-80)/2+2
            color: "transparent"; border.color: Theme.focusRing; border.width: Theme.focusRingWidth
            visible: control.visualFocus
        }
    }
    contentItem: Item {
        Item {
            objectName: "navigationStack"
            anchors.fill: parent
            visible: opacity>0; opacity: control.expanded ? 0 : 1
            // The two forms cross on DefaultEffects, the effects partner of the
            // rail's DefaultSpatial: opacity takes an effects spring so it
            // cannot overshoot, and the default one rather than the fast one so
            // the words do not arrive long before the row has room for them.
            Behavior on opacity { NumberAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } }
            Artwork { objectName: "navigationStackArt"; visible: !!control.artUrl; anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: control.artSize; height: control.artSize; radius: 0; pixels: 160; url: control.artUrl }
            Icon { id: stackGlyph; visible: !control.artUrl; size: control.iconSize; anchors.horizontalCenter: parent.horizontalCenter; y: 8; name: control.symbol; fill: control.selected ? 1 : 0; ink: control.selected ? Theme.secondaryContainerText : Theme.muted; Accessible.ignored: true; Behavior on ink { ColorAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } } }
            MBadge {
                objectName: "navigationBadge"
                present: control.badged || control.badgeCount >= 0
                count: control.badgeCount; subject: control.text
                x: stackGlyph.x+stackGlyph.width-inset; y: stackGlyph.y-height+lift
            }
            NoirText {
                objectName: "navigationLabel"
                // The stacked item is 4dp, a 32dp indicator, 4dp, a 20dp label
                // and 4dp again, which is the 64dp container Material gives it.
                y: 36; width: parent.width; height: 20
                text: control.text; horizontalAlignment: Text.AlignHCenter
                visible: control.showCollapsedLabel
                font.pixelSize: Theme.labelMedium
                // NavigationRailVerticalItemTokens.LabelTextFont stays LabelMedium
                // for both states; the indicator and ink show selection.
                labelRole: true; typeRole: "labelMedium"
                color: control.selected ? Theme.secondary : Theme.muted
                // NavigationItem.kt:1212 crosses the label on DefaultEffects.
                Behavior on color { ColorAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } }
                Accessible.ignored: true
            }
        }
        Row {
            objectName: "navigationRow"
            // Material's horizontal rail item: 16dp inside the indicator either
            // side of the row, and 8dp between the glyph and the words.
            anchors.fill: parent; anchors.leftMargin: control.itemPadding+16; anchors.rightMargin: control.trailingPadding+16
            spacing: 8
            visible: opacity>0; opacity: control.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } }
            Item {
                width: control.artSize; height: control.artSize; anchors.verticalCenter: parent.verticalCenter
                // No art and no symbol means nothing to draw, so the slot is not reserved.
                visible: !!control.artUrl || !!control.symbol
                Icon { anchors.centerIn: parent; size: control.iconSize; visible: !control.artUrl; name: control.symbol; fill: control.selected ? 1 : 0; ink: control.selected ? Theme.secondaryContainerText : Theme.muted; Accessible.ignored: true; Behavior on ink { ColorAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } } }
                Artwork { anchors.centerIn: parent; visible: !!control.artUrl; width: control.artSize; height: control.artSize; radius: 0; pixels: 160; url: control.artUrl }
                MBadge {
                    objectName: "navigationWideBadge"
                    present: control.badged || control.badgeCount >= 0
                    count: control.badgeCount; subject: control.text
                    x: parent.width-inset; y: -height+lift
                }
            }
            NoirText {
                objectName: "navigationWideLabel"
                width: parent.width-32; height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: control.text; elide: Text.ElideRight
                font.pixelSize: Math.round(Theme.labelLarge*1.1)
                // NavigationRailHorizontalItemTokens.LabelTextFont stays LabelLarge.
                labelRole: true; typeRole: "labelLarge"
                // Where the glyph leads and the label sits inside the
                // indicator, the label is on the container and takes its ink.
                // Stacked, the label is below the indicator and on the surface,
                // so it takes the secondary role instead.
                color: control.selected ? Theme.secondaryContainerText : Theme.muted
                // NavigationItem.kt:1212 crosses the label on DefaultEffects.
                Behavior on color { ColorAnimation { duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects } }
                Accessible.ignored: true
            }
        }
    }
}
