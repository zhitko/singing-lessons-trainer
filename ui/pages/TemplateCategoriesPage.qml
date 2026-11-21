import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.8
import by.intontrainer.file 1.0
import by.intontrainer.statistics 1.0
import "../components"
import "../utils"

Page {
    id: categoriesPage
    title: qsTr("Lesson library")
    readonly property string navId: "library"
    padding: 0

    property string path: "data/patterns"
    property var allFolders: []
    // Category shown in the right pane on wide windows.
    property string selectedCategory: ""
    readonly property bool twoPane: AppScale.useTwoPane

    background: Rectangle {
        color: Theme.background(Material.theme)
    }

    Component.onCompleted: {
        allFolders = fileApi.getFolders(categoriesPage.path);
        if (allFolders.length > 0)
            selectedCategory = allFolders[0];
    }

    onVisibleChanged: {
        if (visible) {
            // Reload when page becomes visible
            listView.forceLayout();
        }
    }

    function openCategory(name) {
        if (twoPane) {
            selectedCategory = name;
        } else {
            stackView.push("TemplateFilesPage.qml", {
                categoryPath: name,
                categoryName: name
            });
        }
    }

    FileApi {
        id: fileApi
    }

    StatisticsApi {
        id: statisticsApi
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Categories ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: !categoriesPage.twoPane
            Layout.preferredWidth: categoriesPage.twoPane ? Math.min(420, categoriesPage.width * 0.4) : -1
            Layout.maximumWidth: categoriesPage.twoPane ? 420 : 760
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: AppScale.pagePadding
            Layout.bottomMargin: 0
            spacing: AppScale.isCompact ? 12 : 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    Layout.fillWidth: true
                    text: qsTr("What will you sing today?")
                    font.pixelSize: AppScale.fs(AppScale.isCompact ? 22 : 26)
                    font.weight: Font.Bold
                    color: Theme.onSurface(Material.theme)
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Choose a vocal exercise or a song to begin.")
                    font.pixelSize: AppScale.fs(14)
                    color: Theme.onSurfaceVariant(Material.theme)
                    wrapMode: Text.WordWrap
                }
            }

            SearchBar {
                id: searchField
                placeholderText: qsTr("Search categories")
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: AppScale.listSpacing
                bottomMargin: AppScale.pagePadding
                ScrollBar.vertical: ScrollBar {
                    policy: (window.settingsApi && !window.settingsApi.showNavigationMenu) ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }

                model: {
                    if (!searchField.text)
                        return allFolders;
                    return allFolders.filter(folder => folder.toLowerCase().includes(searchField.text.toLowerCase()));
                }

                delegate: ListItem {
                    width: ListView.view.width - (ListView.view.ScrollBar.vertical.visible ? 12 : 0)
                    itemData: modelData
                    itemIndex: index
                    icon: [Icons.faMusic, Icons.faMicrophoneLines, Icons.faGuitar][index % 3]
                    filePath: fileApi.getApplicationDirPath() + "/" + categoriesPage.path + "/" + modelData
                    isFolder: true
                    selected: categoriesPage.twoPane && categoriesPage.selectedCategory === modelData
                    onClicked: categoriesPage.openCategory(modelData)
                }

                EmptyState {
                    anchors.fill: parent
                    showEmpty: listView.count === 0
                    icon: Icons.faMusic
                    emptyMessage: allFolders.length === 0 ? qsTr("No categories found") : qsTr("No categories match your search")
                }
            }
        }

        // ── Lessons of the selected category (wide windows) ──────────────
        Rectangle {
            visible: categoriesPage.twoPane
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: AppScale.pagePadding
            Layout.rightMargin: AppScale.pagePadding
            Layout.bottomMargin: AppScale.pagePadding
            radius: 28
            color: Theme.surfaceContainerLowest(Material.theme)
            border.width: 1
            border.color: Qt.alpha(Theme.outlineVariant(Material.theme), 0.6)
            clip: true

            Loader {
                id: filesLoader
                anchors.fill: parent
                active: categoriesPage.twoPane && categoriesPage.selectedCategory !== ""
                source: "TemplateFilesPage.qml"
                onLoaded: {
                    item.embedded = true;
                    item.categoryName = Qt.binding(() => categoriesPage.selectedCategory);
                    item.categoryPath = Qt.binding(() => categoriesPage.selectedCategory);
                }
            }

            EmptyState {
                anchors.fill: parent
                showEmpty: !filesLoader.active
                icon: Icons.faMusic
                emptyMessage: qsTr("Choose a category to see its lessons")
            }
        }
    }
}
