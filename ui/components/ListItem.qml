import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.8
import by.intontrainer.statistics 1.0
import "../utils"

// Lesson or lesson-category row: tinted icon tile, title, status line and a
// score ring on the right.
Item {
    id: root

    property string itemData: ""
    property int itemIndex: 0
    property string icon: Icons.faBook
    property string filePath: ""
    property bool isFolder: false
    property bool selected: false
    property real avgScore: 0
    property string statusText: ""
    // Folder progress, 0..1
    property real completeness: 0

    signal clicked

    StatisticsApi {
        id: statisticsApi
    }

    Component.onCompleted: updateStatistics()

    onVisibleChanged: {
        if (visible) {
            // Reload statistics when component becomes visible (e.g., when going back)
            updateStatistics();
        }
    }

    function updateStatistics() {
        if (root.isFolder) {
            let folderStats = statisticsApi.getAvgResultForFolder(root.filePath);
            root.avgScore = folderStats.avgBestResult;
            root.completeness = folderStats.totalFiles > 0 ? folderStats.processedFiles / folderStats.totalFiles : 0;
            root.statusText = qsTr("%1 of %2 lessons practiced").arg(Math.round(folderStats.processedFiles)).arg(Math.round(folderStats.totalFiles));
            return;
        }

        let score = statisticsApi.getBestResultForFile(root.filePath);
        root.avgScore = score;
        if (score >= 90)
            root.statusText = qsTr("Excellent");
        else if (score >= 70)
            root.statusText = qsTr("Good");
        else if (score >= 40)
            root.statusText = qsTr("Medium");
        else if (score >= 20)
            root.statusText = qsTr("Bad");
        else if (score > 0)
            root.statusText = qsTr("Failure");
        else
            root.statusText = qsTr("Not practiced yet");
    }

    readonly property var tileColors: [
        [Theme.primaryContainer(Material.theme), Theme.onPrimaryContainer(Material.theme)],
        [Theme.tertiaryContainer(Material.theme), Theme.onTertiaryContainer(Material.theme)],
        [Theme.secondaryContainer(Material.theme), Theme.onSecondaryContainer(Material.theme)]
    ]
    readonly property var tile: tileColors[root.itemIndex % tileColors.length]

    width: ListView.view ? ListView.view.width : 0
    height: Math.max(AppScale.listItemHeight, contentRow.implicitHeight + 30)

    SurfaceCard {
        id: card
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        interactive: true
        selected: root.selected
        baseColor: Theme.surfaceContainerLow(Material.theme)
        onClicked: root.clicked()
        Accessible.role: Accessible.Button
        Accessible.name: root.itemData

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: AppScale.isCompact ? 12 : 16
            anchors.rightMargin: AppScale.isCompact ? 12 : 16
            spacing: AppScale.isCompact ? 12 : 16

            Rectangle {
                Layout.preferredWidth: AppScale.isCompact ? 44 : 52
                Layout.preferredHeight: Layout.preferredWidth
                radius: Theme.shapeMedium + 2
                color: root.tile[0]

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    font.family: Icons.familySolid
                    font.weight: Font.Black
                    font.pixelSize: AppScale.fs(AppScale.isCompact ? 17 : 20)
                    color: root.tile[1]
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.itemData
                    font.pixelSize: AppScale.fs(AppScale.isCompact ? 15 : 16)
                    font.weight: Font.DemiBold
                    color: root.selected ? Theme.onSecondaryContainer(Material.theme) : Theme.onSurface(Material.theme)
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                }

                Text {
                    Layout.fillWidth: true
                    text: root.statusText
                    color: root.avgScore > 0 && !root.isFolder ? Theme.scoreColor(root.avgScore, Material.theme) : Theme.onSurfaceVariant(Material.theme)
                    font.pixelSize: AppScale.fs(13)
                    font.weight: root.avgScore > 0 && !root.isFolder ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                // Folder progress bar
                Rectangle {
                    visible: root.isFolder
                    Layout.fillWidth: true
                    Layout.maximumWidth: 240
                    Layout.topMargin: 2
                    implicitHeight: 4
                    radius: 2
                    color: Theme.surfaceContainerHighest(Material.theme)

                    Rectangle {
                        width: parent.width * Math.min(1, root.completeness)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary(Material.theme)

                        Behavior on width {
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            ScoreRing {
                Layout.preferredWidth: AppScale.isCompact ? 46 : 54
                Layout.preferredHeight: Layout.preferredWidth
                score: root.avgScore
            }
        }
    }
}
