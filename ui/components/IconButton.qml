import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "../utils"

// Round icon-only button with a Material 3 state layer and a tooltip.
ToolButton {
    id: root

    property string iconText: ""
    property string toolTipText: ""
    property color iconColor: Theme.onSurfaceVariant(Material.theme)
    property color containerColor: "transparent"

    text: iconText
    font.family: Icons.familySolid
    font.weight: Font.Black
    font.pixelSize: AppScale.fs(18)
    hoverEnabled: true
    Accessible.name: toolTipText
    ToolTip.visible: toolTipText !== "" && hovered && !AppScale.isMobile
    ToolTip.delay: 600
    ToolTip.text: toolTipText

    contentItem: Text {
        text: root.text
        font: root.font
        color: root.iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: 44
        implicitHeight: 44
        radius: width / 2
        color: root.containerColor

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.onSurface(Material.theme)
            opacity: root.pressed ? 0.12 : (root.hovered || root.visualFocus ? 0.08 : 0)

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }
}
