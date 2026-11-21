import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.8
import by.intontrainer.file 1.0
import by.intontrainer.statistics 1.0
import "../components"
import "../utils"

Page {
    id: filesPage
    title: categoryName
    padding: 0

    property string categoryPath: ""
    property string categoryName: ""
    // True when shown as the right pane of the library instead of a pushed page.
    property bool embedded: false
    property var allFiles: []
    property string currentFilter: "all" // all, noScore, above90, below90
    property string unfoldedCategory: ""
    readonly property bool searching: searchField.text !== ""

    background: Rectangle {
        color: filesPage.embedded ? "transparent" : Theme.background(Material.theme)
    }

    Component.onCompleted: {
        loadFiles();
    }

    onCategoryPathChanged: {
        if (categoryPath !== "") {
            unfoldedCategory = "";
            loadFiles();
        }
    }

    onVisibleChanged: {
        if (visible) {
            // Reload statistics when page becomes visible
            loadFiles();
            listView.forceLayout();
        }
    }

    function loadFiles() {
        if (categoryPath === "")
            return;
        // Load all files from the category and subdirectories
        let basePath = "data/patterns/" + categoryPath;
        let files = fileApi.getFilesList(basePath, ["*.wav"]);

        // Convert to array and enrich with statistics
        let loaded = files.map(function(file) {
            let filePath = basePath + "/" + file.filePath;
            let score = statisticsApi.getBestResultForFile(filePath);
            let filePathStr = String(file.filePath);
            let lastSlash = filePathStr.lastIndexOf('/');
            let dir = lastSlash > 0 ? filePathStr.substring(0, lastSlash) : qsTr("Root");
            return {
                fileName: file.fileName,
                filePath: filePath,
                fullPath: fileApi.getApplicationDirPath() + "/" + filePath,
                score: score,
                hasScore: score > 0,
                directory: dir
            };
        });

        // Sort by directory and then by natural file name order
        loaded.sort((a, b) => {
            let dirCompare = a.directory.localeCompare(b.directory);
            if (dirCompare !== 0)
                return dirCompare;
            return a.fileName.localeCompare(b.fileName, undefined, { numeric: true });
        });
        allFiles = loaded;

        // Open the first group so the pane never looks empty.
        if (unfoldedCategory === "" && allFiles.length > 0)
            unfoldedCategory = allFiles[0].directory;
    }

    function applyFilter(files) {
        return files.filter(function(file) {
            switch (currentFilter) {
                case "noScore":
                    return !file.hasScore;
                case "above90":
                    return file.hasScore && file.score >= 90;
                case "below90":
                    return file.hasScore && file.score < 90;
                default:
                    return true;
            }
        });
    }

    function groupStats(directory) {
        let total = 0, done = 0;
        for (let i = 0; i < allFiles.length; i++) {
            if (allFiles[i].directory !== directory)
                continue;
            total++;
            if (allFiles[i].hasScore)
                done++;
        }
        return { total: total, done: done };
    }

    readonly property var visibleFiles: {
        let filtered = applyFilter(allFiles);
        if (!searchField.text)
            return filtered;
        return filtered.filter(file => file.fileName.toLowerCase().includes(searchField.text.toLowerCase()));
    }

    FileApi {
        id: fileApi
    }

    StatisticsApi {
        id: statisticsApi
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: AppScale.pagePadding
        anchors.bottomMargin: 0
        spacing: AppScale.isCompact ? 10 : 14

        // Pane header (embedded only — a pushed page shows its title in the app bar)
        RowLayout {
            visible: filesPage.embedded
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: filesPage.categoryName
                font.pixelSize: AppScale.fs(22)
                font.weight: Font.Bold
                elide: Text.ElideRight
                color: Theme.onSurface(Material.theme)
            }

            Label {
                text: qsTr("%n lesson(s)", "", allFiles.length)
                font.pixelSize: AppScale.fs(13)
                color: Theme.onSurfaceVariant(Material.theme)
            }
        }

        SearchBar {
            id: searchField
            placeholderText: qsTr("Search lessons")
        }

        // Filter Chips — one horizontally scrollable row
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: chipRow.implicitHeight
            contentWidth: chipRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: chipRow
                spacing: 8

                Repeater {
                    model: [
                        { id: "all", text: qsTr("All lessons"), icon: Icons.faList },
                        { id: "noScore", text: qsTr("New"), icon: Icons.faClock },
                        { id: "below90", text: qsTr("Improve"), icon: Icons.faArrowTrendUp },
                        { id: "above90", text: qsTr("Mastered"), icon: Icons.faTrophy }
                    ]

                    Chip {
                        required property var modelData
                        text: modelData.text
                        icon: modelData.icon
                        selected: filesPage.currentFilter === modelData.id
                        onClicked: filesPage.currentFilter = modelData.id
                    }
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            cacheBuffer: 20000
            bottomMargin: AppScale.pagePadding
            ScrollBar.vertical: ScrollBar {
                policy: (window.settingsApi && !window.settingsApi.showNavigationMenu) ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }

            readonly property int contentInset: ScrollBar.vertical.visible ? 12 : 0

            model: filesPage.visibleFiles

            section.property: "directory"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                id: sectionHeader
                required property string section
                readonly property bool open: filesPage.searching || filesPage.unfoldedCategory === section
                readonly property var stats: filesPage.groupStats(section)
                width: listView.width - listView.contentInset
                height: 64
                visible: section !== ""

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    radius: Theme.shapeLarge
                    color: sectionHeader.open ? Theme.surfaceContainer(Material.theme) : (headerMouseArea.containsMouse ? Theme.surfaceContainerLow(Material.theme) : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: sectionHeader.open ? Icons.faFolderOpen : Icons.faFolder
                            font.family: Icons.familySolid
                            font.weight: Font.Black
                            font.pixelSize: AppScale.fs(16)
                            color: Theme.primary(Material.theme)
                        }

                        Text {
                            text: sectionHeader.section
                            font.pixelSize: AppScale.fs(AppScale.isCompact ? 15 : 16)
                            font.weight: Font.Bold
                            color: Theme.onSurface(Material.theme)
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: sectionHeader.stats.done + " / " + sectionHeader.stats.total
                            font.pixelSize: AppScale.fs(13)
                            color: Theme.onSurfaceVariant(Material.theme)
                        }

                        Text {
                            text: Icons.faChevronDown
                            font.family: Icons.familySolid
                            font.weight: Font.Black
                            font.pixelSize: AppScale.fs(13)
                            color: Theme.onSurfaceVariant(Material.theme)
                            rotation: sectionHeader.open ? 180 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    MouseArea {
                        id: headerMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (filesPage.searching)
                                return;
                            filesPage.unfoldedCategory = filesPage.unfoldedCategory === sectionHeader.section ? "" : sectionHeader.section;
                        }
                    }
                }
            }

            delegate: Item {
                width: listView.width - listView.contentInset
                visible: height > 0
                height: (filesPage.searching || modelData.directory === filesPage.unfoldedCategory) ? (lessonItem.height + 2) : 0
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                ListItem {
                    id: lessonItem
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: AppScale.isCompact ? 0 : 8
                    itemData: modelData.fileName.replace(/\.wav$/i, "")
                    itemIndex: index
                    icon: Icons.faFileAudio
                    filePath: modelData.fullPath
                    isFolder: false
                    onClicked: {
                        stackView.push("TrainingPage.qml", {
                            referenceFilePath: modelData.fullPath
                        });
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                showEmpty: filesPage.visibleFiles.length === 0
                icon: Icons.faMagnifyingGlass
                emptyMessage: {
                    if (allFiles.length === 0) {
                        return qsTr("No files found");
                    } else if (searchField.text) {
                        return qsTr("No files match your search");
                    } else {
                        return qsTr("No files match the current filter");
                    }
                }
            }
        }
    }
}
