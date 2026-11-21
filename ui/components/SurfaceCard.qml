import QtQuick
import QtQuick.Controls.Material
import "../utils"

// Flat Material 3 card. Set `interactive` to get hover/press state layers
// and the `clicked` signal.
Rectangle {
    id: root

    property bool interactive: false
    property bool selected: false
    property color baseColor: Theme.surfaceContainerLow(Material.theme)
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed
    signal clicked

    radius: Theme.shapeLarge + 4
    color: selected ? Theme.secondaryContainer(Material.theme) : baseColor
    border.width: selected ? 0 : 1
    border.color: Qt.alpha(Theme.outlineVariant(Material.theme), 0.6)

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.onSurface(Material.theme)
        opacity: !root.interactive ? 0 : (mouseArea.pressed ? 0.10 : (mouseArea.containsMouse ? 0.05 : 0))
        z: 1

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
        z: 2
    }
}
