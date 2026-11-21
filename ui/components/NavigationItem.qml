import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "../utils"

// One destination in the bottom navigation bar or the side navigation rail.
AbstractButton {
    id: root

    property string iconText: ""
    property bool selected: false
    property bool compact: false

    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    implicitWidth: 80
    implicitHeight: compact ? 60 : 68

    background: null

    contentItem: Item {
        Column {
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.compact ? 56 : 64
                height: 32
                radius: 16
                color: root.selected ? Theme.primaryContainer(Material.theme)
                                     : (root.hovered || root.visualFocus ? Qt.alpha(Theme.onSurface(Material.theme), 0.08) : "transparent")
                border.width: root.visualFocus ? 2 : 0
                border.color: Theme.primary(Material.theme)

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.iconText
                    font.family: Icons.familySolid
                    font.weight: Font.Black
                    font.pixelSize: AppScale.fs(18)
                    color: root.selected ? Theme.onPrimaryContainer(Material.theme) : Theme.onSurfaceVariant(Material.theme)
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, root.width - 4)
                text: root.text
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: AppScale.fs(12)
                font.weight: root.selected ? Font.Bold : Font.Medium
                color: root.selected ? Theme.onSurface(Material.theme) : Theme.onSurfaceVariant(Material.theme)
            }
        }
    }
}
