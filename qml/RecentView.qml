import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Recently played: the last songs on the left and the last playlists on the
// right, each column its own grid that scrolls on its own. Tiles fill their
// column evenly. The white outline frames the cover only; the title and count
// sit below it unframed.
Item {
    id: recent
    objectName: "recentView"

    // The smallest a tile may be. Each grid fits as many as its column allows,
    // and stretches them so the row has no leftover gap.
    readonly property int minTile: 150
    readonly property int textHeight: 56
    readonly property int gutter: 16

    RowLayout {
        anchors.fill: parent
        spacing: 0

        RecentColumn {
            objectName: "recentSongsColumn"
            title: "Songs"
            model: app.recentTracks
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
            emptyText: "Nothing played yet"
            onActivated: (item) => app.open(item)
            subtitle: (item) => item.artist || ""
        }
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.outlineVariant
        }
        RecentColumn {
            objectName: "recentPlaylistsColumn"
            title: "Playlists"
            model: app.recentPlaylists
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
            emptyText: "No playlists opened yet"
            onActivated: (item) => app.openPlaylist(item.id)
            subtitle: (item) => item.count >= 0 ? item.count + " tracks" : ""
        }
    }

    component RecentColumn: ColumnLayout {
        id: column
        property string title
        property var model
        property string emptyText
        property var subtitle
        signal activated(var item)
        spacing: 8

        NoirText {
            text: column.title; typeRole: "titleSmall"; font.pixelSize: Theme.titleSmall; color: Theme.text
            Layout.leftMargin: recent.gutter
        }
        GridView {
            id: grid
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; reuseItems: true
            // The A button on a highlighted tile plays it, as a click on the tile does.
            Keys.onReturnPressed: { if (grid.currentItem) column.activated(grid.currentItem.modelData) }
            model: column.model
            // Whole tiles per row, stretched to the column's width.
            readonly property int perRow: Math.max(1, Math.floor((width - recent.gutter) / recent.minTile))
            cellWidth: Math.floor((width - recent.gutter) / perRow)
            cellHeight: cellWidth + recent.textHeight
            leftMargin: recent.gutter / 2
            ScrollBar.vertical: MScrollBar {}
            MSmoothWheel { flick: grid }
            delegate: Item {
                id: tile
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                Item {
                    id: frame
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: recent.gutter / 2
                    height: width
                    Artwork {
                        anchors.fill: parent
                        radius: 0; pixels: 160
                        url: tile.modelData.art || ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1; border.color: Theme.text
                    }
                }
                NoirText {
                    anchors.left: frame.left; anchors.right: frame.right
                    anchors.top: frame.bottom; anchors.topMargin: 8
                    text: tile.modelData.title || ""; elide: Text.ElideRight
                    typeRole: "bodyLarge"; font.pixelSize: Theme.bodyLarge; color: Theme.text
                }
                NoirText {
                    anchors.left: frame.left; anchors.right: frame.right
                    anchors.top: frame.bottom; anchors.topMargin: 8 + Theme.bodyLarge + 4
                    text: column.subtitle(tile.modelData); elide: Text.ElideRight
                    font.pixelSize: Theme.bodySmall; color: Theme.muted
                    visible: text.length > 0
                }
                MouseArea {
                    anchors.fill: frame
                    onClicked: column.activated(tile.modelData)
                }
            }
            NoirText { anchors.centerIn: parent; visible: grid.count === 0; text: column.emptyText; color: Theme.muted }
        }
    }
}
