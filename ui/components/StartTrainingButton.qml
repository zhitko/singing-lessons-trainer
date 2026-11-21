import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../utils"

// Primary call to action on the hero card: a large pill with a microphone.
Button {
    id: root

    property color containerColor: Theme.surfaceContainerLowest(Material.theme)
    property color contentColor: Theme.primary(Material.theme)

    hoverEnabled: true
    Accessible.name: text
    leftPadding: 12
    rightPadding: 28
    topPadding: 10
    bottomPadding: 10

    background: Rectangle {
        implicitHeight: 60
        radius: height / 2
        color: root.containerColor
        border.width: root.visualFocus ? 3 : 0
        border.color: Theme.onHero(Material.theme)
        scale: root.down ? 0.97 : (root.hovered ? 1.02 : 1)

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.contentColor
            opacity: root.down ? 0.12 : (root.hovered ? 0.06 : 0)
        }
    }

    contentItem: RowLayout {
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: root.contentColor

            Text {
                anchors.centerIn: parent
                text: Icons.faMicrophoneLines
                font.family: Icons.familySolid
                font.weight: Font.Black
                font.pixelSize: AppScale.fs(18)
                color: root.containerColor
                Accessible.ignored: true
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.text
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: AppScale.fs(17)
            color: root.contentColor
        }
    }
}
