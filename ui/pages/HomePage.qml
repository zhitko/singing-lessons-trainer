import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.8
import by.intontrainer.statistics 1.0
import "../components"
import "../components/cards"
import "../utils"

Page {
    id: root
    title: qsTr("Practice studio")
    padding: 0

    readonly property var settingsApi: ApplicationWindow.window ? ApplicationWindow.window.settingsApi : null
    readonly property bool compactHome: AppScale.isCompact
    readonly property bool wideHome: AppScale.viewWidth >= 860

    property real avgResult: 0
    property int masteredCount: 0
    property int processedFiles: 0
    property int totalFiles: 0
    property real completeness: 0

    background: Rectangle {
        color: Theme.background(Material.theme)
    }

    StatisticsApi {
        id: statisticsApi
    }

    Component.onCompleted: {
        updateStatistics();
    }

    onVisibleChanged: {
        if (visible) {
            updateStatistics();
        }
    }

    function updateStatistics() {
        let stats = statisticsApi.getOverallStatistics();
        avgResult = stats.avgResult;
        masteredCount = Math.round(stats.wellTrainedFiles);
        processedFiles = Math.round(stats.processedFiles);
        totalFiles = Math.round(stats.totalFiles);
        completeness = stats.completeness;
    }

    // navigateTo() runs auto-calibration before opening the library.
    function startSinging() {
        window.navigateTo("library");
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy: (window.settingsApi && !window.settingsApi.showNavigationMenu)
                                   ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: Math.min(AppScale.maxContentWidth, scrollView.availableWidth - AppScale.pagePadding * 2)
            x: (scrollView.availableWidth - width) / 2
            y: AppScale.isCompact ? 4 : 8
            spacing: AppScale.pageSpacing

            GridLayout {
                Layout.fillWidth: true
                columns: root.wideHome ? 2 : 1
                columnSpacing: AppScale.pageSpacing
                rowSpacing: AppScale.pageSpacing

                // ── Hero ────────────────────────────────────────────────
                Rectangle {
                    id: hero
                    Layout.row: 0
                    Layout.column: 0
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.wideHome ? 3 : 1
                    Layout.preferredHeight: heroLayout.implicitHeight + (root.compactHome ? 40 : 56)
                    Layout.fillHeight: root.wideHome
                    radius: 28
                    clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.heroStart(Material.theme) }
                        GradientStop { position: 1.0; color: Theme.heroEnd(Material.theme) }
                    }

                    MusicStaff {
                        // Bottom-right, beside the start button, clear of the headline.
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.compactHome ? 12 : 20
                        width: parent.width * 0.42
                        height: root.compactHome ? 72 : 96
                        notes: [1, 3, 2, 4, 3]
                        ink: Theme.onHero(Material.theme)
                        lineOpacity: 0.16
                        noteOpacity: 0.24
                    }

                    ColumnLayout {
                        id: heroLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: root.compactHome ? 20 : 28
                        spacing: 8

                        Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: languageRow.implicitWidth + 24
                            radius: 14
                            color: Qt.alpha(Theme.onHero(Material.theme), 0.16)
                            visible: settingsApi && settingsApi.languageTitle !== ""

                            Row {
                                id: languageRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.faMusic
                                    font.family: Icons.familySolid
                                    font.weight: Font.Black
                                    font.pixelSize: AppScale.fs(11)
                                    color: Theme.onHero(Material.theme)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: settingsApi ? settingsApi.languageTitle : ""
                                    font.pixelSize: AppScale.fs(12)
                                    font.weight: Font.DemiBold
                                    color: Theme.onHero(Material.theme)
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            wrapMode: Text.Wrap
                            text: qsTr("Find your voice")
                            font.weight: Font.Bold
                            font.pixelSize: AppScale.fs(root.compactHome ? 28 : 36)
                            color: Theme.onHero(Material.theme)
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 420
                            wrapMode: Text.Wrap
                            text: qsTr("Listen closely. Sing freely. Grow with every take.")
                            font.pixelSize: AppScale.fs(root.compactHome ? 15 : 17)
                            color: Theme.onHero(Material.theme)
                            opacity: 0.9
                        }

                        StartTrainingButton {
                            Layout.topMargin: root.compactHome ? 12 : 20
                            Layout.preferredWidth: Math.min(heroLayout.width, 280)
                            text: qsTr("Start singing")
                            onClicked: root.startSinging()
                        }
                    }
                }

                Label {
                    Layout.row: 1
                    Layout.column: 0
                    Layout.columnSpan: root.wideHome ? 2 : 1
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: qsTr("Your practice")
                    font.pixelSize: AppScale.fs(18)
                    font.weight: Font.Bold
                    color: Theme.onSurface(Material.theme)
                }

                GridLayout {
                    columns: AppScale.isNarrow && AppScale.fontScale > 1.3 ? 1 : 3
                    Layout.row: 2
                    Layout.column: 0
                    Layout.columnSpan: root.wideHome ? 2 : 1
                    Layout.fillWidth: true
                    rowSpacing: root.compactHome ? 8 : 12
                    columnSpacing: rowSpacing

                    StatBox {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: Icons.faChartLine
                        title: qsTr("Melodic similarity")
                        value: Math.round(root.avgResult) + "%"
                    }

                    StatBox {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: Icons.faTrophy
                        title: qsTr("Lessons mastered")
                        value: root.masteredCount
                        tileColor: Theme.tertiaryContainer(Material.theme)
                        tileInk: Theme.onTertiaryContainer(Material.theme)
                    }

                    StatBox {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: Icons.faMusic
                        title: qsTr("Lessons explored")
                        value: root.processedFiles + " / " + root.totalFiles
                        tileColor: Theme.secondaryContainer(Material.theme)
                        tileInk: Theme.onSecondaryContainer(Material.theme)
                    }
                }

                // ── Repertoire progress ─────────────────────────────────
                SurfaceCard {
                    Layout.row: root.wideHome ? 0 : 3
                    Layout.column: root.wideHome ? 1 : 0
                    Layout.fillWidth: true
                    Layout.bottomMargin: AppScale.pagePadding
                    Layout.preferredWidth: root.wideHome ? 2 : 1
                    Layout.fillHeight: root.wideHome
                    implicitHeight: progressLayout.implicitHeight + 40
                    interactive: true
                    onClicked: window.navigateTo("library")

                    GridLayout {
                        id: progressLayout
                        anchors.fill: parent
                        anchors.margins: 20
                        columns: root.wideHome ? 1 : 2
                        columnSpacing: 20
                        rowSpacing: 16

                        CircularProgress {
                            id: overallProgressCircle
                            readonly property real ringSize: (root.compactHome ? 84 : (root.wideHome ? 132 : 100)) * Math.min(AppScale.fontScale, 1.3)
                            Layout.preferredWidth: ringSize
                            Layout.preferredHeight: ringSize
                            Layout.alignment: root.wideHome ? Qt.AlignHCenter : Qt.AlignVCenter
                            lineWidth: Math.max(8, Math.round(ringSize * 0.09))
                            progress: root.completeness / 100
                            color: Theme.primary(Material.theme)
                            backgroundColor: Theme.surfaceContainerHighest(Material.theme)

                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(root.completeness) + "%"
                                    font.pixelSize: AppScale.fs(Math.round(overallProgressCircle.ringSize * 0.22))
                                    font.bold: true
                                    color: Theme.onSurface(Material.theme)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: root.wideHome ? Text.AlignHCenter : Text.AlignLeft
                                text: qsTr("Build your repertoire")
                                font.pixelSize: AppScale.fs(17)
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                                color: Theme.onSurface(Material.theme)
                            }
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: root.wideHome ? Text.AlignHCenter : Text.AlignLeft
                                text: qsTr("Explore vocal exercises and songs, one lesson at a time.")
                                font.pixelSize: AppScale.fs(13)
                                wrapMode: Text.WordWrap
                                color: Theme.onSurfaceVariant(Material.theme)
                            }
                            Label {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                horizontalAlignment: root.wideHome ? Text.AlignHCenter : Text.AlignLeft
                                text: qsTr("Open library") + "  →"
                                font.pixelSize: AppScale.fs(14)
                                font.weight: Font.DemiBold
                                color: Theme.primary(Material.theme)
                            }
                        }
                    }
                }
            }

        }
    }
}
