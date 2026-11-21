import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material 6.8
import "../utils"

Item {
    property bool showEmpty: true
    property string emptyMessage: qsTr("No items found")
    property string icon: ""

    visible: showEmpty

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
        spacing: 12

        Rectangle {
            visible: icon !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64
            radius: 32
            color: Theme.surfaceContainerHigh(Material.theme)

            Text {
                anchors.centerIn: parent
                text: icon
                font.family: Icons.familySolid
                font.weight: Font.Black
                font.pixelSize: AppScale.fs(24)
                color: Theme.onSurfaceVariant(Material.theme)
            }
        }

        Text {
            width: parent.width
            text: emptyMessage
            font.pixelSize: AppScale.fs(16)
            color: Theme.onSurfaceVariant(Material.theme)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
