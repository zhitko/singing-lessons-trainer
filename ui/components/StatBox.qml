import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import "../utils"

// Small statistic card: icon tile, big value and a caption.
SurfaceCard {
    id: root

    property string title: ""
    property string value: ""
    property string icon: ""
    property string iconFamily: Icons.familySolid
    property color tileColor: Theme.primaryContainer(Material.theme)
    property color tileInk: Theme.onPrimaryContainer(Material.theme)

    implicitWidth: 120
    implicitHeight: statLayout.implicitHeight + 32

    ColumnLayout {
        id: statLayout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 6

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.shapeMedium
            color: root.tileColor

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: root.iconFamily
                font.weight: Font.Black
                font.pixelSize: AppScale.fs(16)
                color: root.tileInk
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: root.value
            font.pixelSize: AppScale.fs(AppScale.isCompact ? 20 : 24)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
            font.weight: Font.Bold
            color: Theme.onSurface(Material.theme)
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: AppScale.fs(12)
            color: Theme.onSurfaceVariant(Material.theme)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
