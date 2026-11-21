import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material 6.8
import "../utils"

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: AppScale.searchBarHeight
    radius: AppScale.searchBarHeight / 2
    color: Theme.surfaceContainerHigh(Material.theme)
    border.width: searchInputField.activeFocus ? 2 : 0
    border.color: Theme.primary(Material.theme)

    property alias text: searchInputField.text
    property alias placeholderText: searchInputField.placeholderText

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 18
        anchors.rightMargin: 8
        spacing: 12

        Text {
            text: Icons.faMagnifyingGlass
            font.family: Icons.familySolid
            font.weight: Font.Black
            font.pixelSize: AppScale.fs(16)
            color: Theme.onSurfaceVariant(Material.theme)
            Layout.alignment: Qt.AlignVCenter
        }

        TextField {
            id: searchInputField
            Layout.fillWidth: true
            placeholderText: qsTr("Search")
            background: null
            leftPadding: 0
            font.pixelSize: AppScale.fs(15)
            color: Theme.onSurface(Material.theme)
            placeholderTextColor: Theme.onSurfaceVariant(Material.theme)
        }

        IconButton {
            visible: searchInputField.text !== ""
            iconText: Icons.faXmark
            onClicked: searchInputField.text = ""
        }
    }
}
