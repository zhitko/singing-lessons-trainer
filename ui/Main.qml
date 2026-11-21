import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 6.8
import QtQuick.Window

import by.intontrainer.settings 1.0
import "utils"
import "components"

ApplicationWindow {
    id: window
    // Window is sized to the scaled dimensions so it fits any screen.
    width: AppScale.designWidth * AppScale.factor
    height: AppScale.designHeight * AppScale.factor
    visible: true
    title: qsTr("Singing Lessons Trainer")

    // Android 15+ / gesture navigation draw the window under the system bars.
    // Keep chrome edge-to-edge, but inset interactive content with SafeArea.
    // Do not assign flags on desktop — that would replace the default decorations.
    Binding on flags {
        when: Qt.platform.os === "android"
        value: Qt.Window | Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint
    }
    topPadding: 0
    leftPadding: 0
    rightPadding: 0
    bottomPadding: 0

    // SafeArea is in window pixels; scaledRoot works in design-space pixels.
    readonly property real safeTop: SafeArea.margins.top / AppScale.factor
    readonly property real safeBottom: SafeArea.margins.bottom / AppScale.factor
    readonly property real safeLeft: SafeArea.margins.left / AppScale.factor
    readonly property real safeRight: SafeArea.margins.right / AppScale.factor

    SettingsApi {
        id: settingsApi
        onThemeChanged: {
            window.theme = getTheme();
        }
    }

    property alias settingsApi: settingsApi

    readonly property bool trainingPageActive: stackView.currentItem && stackView.currentItem.isTrainingPage === true

    function getTheme() {
        return settingsApi.theme === "dark" ? Material.Dark : (settingsApi.theme === "light" ? Material.Light : Material.System);
    }

    property var theme: getTheme()

    Binding {
        target: Theme
        property: "primaryColorName"
        value: settingsApi.primaryColor
    }

    Binding {
        target: AppScale
        property: "fontScale"
        value: settingsApi ? settingsApi.fontSizeMultiplier : 1
    }

    Binding {
        target: AppScale
        property: "viewWidth"
        value: stackView.width
    }

    Binding {
        target: AppScale
        property: "viewHeight"
        value: stackView.height
    }

    Component.onCompleted: {
        Logger.info("Main window initialized");
        Logger.debug("Initial theme: " + window.theme);
        Logger.debug("Screen: " + AppScale.screenWidth + "x" + AppScale.screenHeight + "  scaleFactor: " + AppScale.factor.toFixed(3));
        Logger.debug("SafeArea: top=" + window.safeTop + " bottom=" + window.safeBottom
                     + " left=" + window.safeLeft + " right=" + window.safeRight);
    }

    Material.theme: window.theme
    Material.primary: Theme.primary(window.theme)
    Material.accent: Theme.accent(window.theme)
    Material.background: Theme.background(window.theme)

    Binding {
        target: AppScale
        property: "windowWidth"
        value: scaledRoot.width
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    // Top-level destinations. Each one is a tab: selecting it resets the stack
    // to Home + that page, so Back always returns to Home.
    readonly property var destinations: [
        { id: "home", text: qsTr("Home"), icon: Icons.faHouse, page: "" },
        { id: "library", text: qsTr("Library"), icon: Icons.faMusic, page: "pages/TemplateCategoriesPage.qml" },
        { id: "records", text: qsTr("Recordings"), icon: Icons.faMicrophoneLines, page: "pages/RecordsPage.qml" },
        { id: "settings", text: qsTr("Settings"), icon: Icons.faGear, page: "pages/SettingsPage.qml" }
    ]

    // Section of the current page, taken from the page right above Home.
    readonly property string currentSection: {
        const depth = stackView.depth;
        void stackView.currentItem;
        if (depth <= 1)
            return "home";
        const page = stackView.get(1, StackView.DontLoad);
        return page && page.navId ? page.navId : "";
    }

    property string pendingDestination: ""

    function navigateTo(destinationId) {
        drawer.close();
        // Entering the library leads to training, so calibrate first when enabled.
        if (destinationId === "library" && destinationId !== currentSection
                && settingsApi.autoCalibrate) {
            if (!vadCalibrationDialog.visible) {
                pendingDestination = destinationId;
                vadCalibrationDialog.open();
            }
            return;
        }
        showDestination(destinationId);
    }

    function showDestination(destinationId) {
        if (destinationId === currentSection) {
            // Re-selecting a tab returns to its first page.
            const target = stackView.get(Math.min(1, stackView.depth - 1), StackView.DontLoad);
            if (target && stackView.currentItem !== target)
                stackView.pop(target);
            return;
        }
        const dest = destinations.find(d => d.id === destinationId);
        if (!dest)
            return;
        if (stackView.depth > 1)
            stackView.pop(stackView.get(0, StackView.DontLoad), StackView.Immediate);
        if (dest.page !== "")
            stackView.push(dest.page);
    }

    function openPage(page) {
        drawer.close();
        stackView.push(page);
    }

    function openAdvanced() {
        drawer.close();
        const page = stackView.currentItem;
        if (page && page.openAdvancedTemplatePage)
            page.openAdvancedTemplatePage();
    }

    readonly property bool showBottomBar: !AppScale.useNavigationRail && settingsApi.showNavigationMenu

    // ── Scaled root ───────────────────────────────────────────────────────────
    Item {
        id: scaledRoot
        width: window.width / AppScale.factor
        height: window.height / AppScale.factor
        transformOrigin: Item.TopLeft
        transform: Scale {
            xScale: AppScale.factor
            yScale: AppScale.factor
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background(Material.theme)
        }

        // ── Navigation rail (wide windows) ────────────────────────────────────
        Rectangle {
            id: navigationRail
            visible: AppScale.useNavigationRail
            width: visible ? 88 : 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: window.safeTop
            anchors.bottomMargin: window.safeBottom
            anchors.leftMargin: window.safeLeft
            color: Theme.surfaceContainerLow(Material.theme)

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: 16
                spacing: 4

                IconButton {
                    Layout.alignment: Qt.AlignHCenter
                    iconText: Icons.faBars
                    toolTipText: qsTr("Menu")
                    onClicked: drawer.open()
                }

                // App mark
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 16
                    width: 48
                    height: 48
                    radius: 16
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.heroStart(Material.theme) }
                        GradientStop { position: 1; color: Theme.heroEnd(Material.theme) }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.faMicrophoneLines
                        font.family: Icons.familySolid
                        font.weight: Font.Black
                        font.pixelSize: AppScale.fs(20)
                        color: Theme.onHero(Material.theme)
                    }
                }

                Repeater {
                    model: window.destinations

                    NavigationItem {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        text: modelData.text
                        iconText: modelData.icon
                        selected: window.currentSection === modelData.id
                        onClicked: window.navigateTo(modelData.id)
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                IconButton {
                    Layout.alignment: Qt.AlignHCenter
                    iconText: window.theme === Material.Dark ? Icons.faSun : Icons.faMoon
                    toolTipText: window.theme === Material.Dark ? qsTr("Light theme") : qsTr("Dark theme")
                    onClicked: {
                        settingsApi.theme = window.theme === Material.Dark ? "light" : "dark";
                        settingsApi.save();
                    }
                }
            }
        }

        // ── Top app bar ───────────────────────────────────────────────────────
        ToolBar {
            id: toolbar
            anchors.top: parent.top
            anchors.left: navigationRail.right
            anchors.right: parent.right
            contentHeight: AppScale.isCompact ? 56 : 64
            topPadding: window.safeTop
            leftPadding: AppScale.useNavigationRail ? 0 : window.safeLeft
            rightPadding: window.safeRight

            background: Rectangle {
                color: Theme.background(Material.theme)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                // Back replaces the menu button on inner pages (leading position).
                IconButton {
                    id: backButton
                    visible: stackView.depth > 1
                    iconText: Icons.faArrowLeft
                    iconColor: Theme.onSurface(Material.theme)
                    toolTipText: qsTr("Back")
                    onClicked: stackView.pop()
                }

                IconButton {
                    visible: !backButton.visible && !AppScale.useNavigationRail
                    iconText: Icons.faBars
                    iconColor: Theme.onSurface(Material.theme)
                    toolTipText: qsTr("Menu")
                    onClicked: drawer.open()
                }

                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    text: (stackView.currentItem && stackView.currentItem.title) ? stackView.currentItem.title : qsTr("Singing Lessons Trainer")
                    font.pixelSize: AppScale.fs(AppScale.isCompact ? 18 : 20)
                    font.weight: Font.DemiBold
                    elide: Label.ElideRight
                    color: Theme.onSurface(Material.theme)
                }

                IconButton {
                    visible: window.trainingPageActive
                    iconText: Icons.faSliders
                    iconColor: Theme.onSurface(Material.theme)
                    toolTipText: qsTr("Advanced")
                    onClicked: window.openAdvanced()
                }
            }
        }

        // ── Bottom navigation bar (phones and narrow windows) ─────────────────
        // Sit above the system inset (gesture pill or 3-button). Do not add
        // SafeArea to height: that paints our bar behind a transparent 3-button
        // nav and makes the tabs look like one oversized control.
        Rectangle {
            id: navigationBar
            visible: window.showBottomBar
            height: AppScale.isCompact ? 72 : 80
            anchors.bottom: parent.bottom
            anchors.bottomMargin: window.safeBottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: window.safeLeft
            anchors.rightMargin: window.safeRight
            color: Theme.surfaceContainer(Material.theme)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 0

                Repeater {
                    model: window.destinations

                    NavigationItem {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        compact: AppScale.isCompact
                        text: modelData.text
                        iconText: modelData.icon
                        selected: window.currentSection === modelData.id
                        onClicked: window.navigateTo(modelData.id)
                    }
                }
            }
        }

        // ── Page content ──────────────────────────────────────────────────────
        StackView {
            id: stackView
            anchors {
                top: toolbar.bottom
                bottom: window.showBottomBar ? navigationBar.top : parent.bottom
                bottomMargin: window.showBottomBar ? 0 : window.safeBottom
                left: navigationRail.right
                right: parent.right
                leftMargin: AppScale.useNavigationRail ? 0 : window.safeLeft
                rightMargin: window.safeRight
            }

            initialItem: "pages/HomePage.qml"
        }
    }

    VadCalibrationDialog {
        id: vadCalibrationDialog
        onCalibrationDone: {
            const destinationId = window.pendingDestination;
            window.pendingDestination = "";
            if (destinationId !== "")
                window.showDestination(destinationId);
        }
    }

    // ── Side drawer ───────────────────────────────────────────────────────
    Drawer {
        id: drawer
        width: Math.min(window.width * 0.85, 320 * AppScale.factor)
        height: window.height
        z: 2

        background: Rectangle {
            color: Theme.surfaceContainerLow(Material.theme)
        }

        Flickable {
            anchors.fill: parent
            anchors.topMargin: window.SafeArea.margins.top
            anchors.bottomMargin: window.SafeArea.margins.bottom
            anchors.leftMargin: window.SafeArea.margins.left
            contentHeight: (drawerLayout.implicitHeight + 24) * AppScale.factor
            clip: true
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: drawerLayout
                width: (drawer.width - 24 * AppScale.factor) / AppScale.factor
                x: 12 * AppScale.factor
                y: 12 * AppScale.factor
                spacing: 2
                transformOrigin: Item.TopLeft

                transform: Scale {
                    xScale: AppScale.factor
                    yScale: AppScale.factor
                }

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    Layout.bottomMargin: 16
                    spacing: 12

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 14
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.heroStart(Material.theme) }
                            GradientStop { position: 1; color: Theme.heroEnd(Material.theme) }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.faMicrophoneLines
                            font.family: Icons.familySolid
                            font.weight: Font.Black
                            font.pixelSize: AppScale.fs(18)
                            color: Theme.onHero(Material.theme)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Singing Lessons Trainer")
                            font.pixelSize: AppScale.fs(16)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            color: Theme.onSurface(Material.theme)
                        }
                        Label {
                            text: qsTr("Version %1").arg(Qt.application.version)
                            font.pixelSize: AppScale.fs(12)
                            color: Theme.onSurfaceVariant(Material.theme)
                        }
                    }
                }

                Repeater {
                    model: window.destinations

                    delegate: DrawerItem {
                        required property var modelData
                        text: modelData.text
                        iconText: modelData.icon
                        highlighted: window.currentSection === modelData.id
                        onClicked: window.navigateTo(modelData.id)
                    }
                }

                DrawerItem {
                    visible: window.trainingPageActive
                    text: qsTr("Advanced")
                    iconText: Icons.faSliders
                    onClicked: window.openAdvanced()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 1
                    color: Theme.outlineVariant(Material.theme)
                }

                DrawerItem {
                    text: qsTr("User Guide")
                    iconText: Icons.faBookOpen
                    highlighted: stackView.currentItem && stackView.currentItem.title === text
                    onClicked: window.openPage("pages/UserGuidePage.qml")
                }
                DrawerItem {
                    text: qsTr("Privacy Policy")
                    iconText: Icons.faShieldHalved
                    highlighted: stackView.currentItem && stackView.currentItem.title === text
                    onClicked: window.openPage("pages/PrivacyPolicyPage.qml")
                }
                DrawerItem {
                    text: qsTr("Open-source licences")
                    iconText: Icons.faScaleBalanced
                    highlighted: stackView.currentItem && stackView.currentItem.title === text
                    onClicked: window.openPage("pages/LicensesPage.qml")
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 1
                    color: Theme.outlineVariant(Material.theme)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 8
                    spacing: 12

                    Text {
                        text: Icons.faMoon
                        font.family: Icons.familySolid
                        font.weight: Font.Black
                        font.pixelSize: AppScale.fs(18)
                        color: Theme.onSurfaceVariant(Material.theme)
                    }
                    Label {
                        text: qsTr("Dark Mode")
                        Layout.fillWidth: true
                        font.pixelSize: AppScale.fs(14)
                        color: Theme.onSurface(Material.theme)
                    }
                    Switch {
                        checked: window.theme === Material.Dark
                        onToggled: {
                            settingsApi.theme = checked ? "dark" : "light";
                            settingsApi.save();
                        }
                    }
                }
            }
        }
    }

    component DrawerItem: ItemDelegate {
        id: drawerItem
        property string iconText: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 52

        contentItem: RowLayout {
            spacing: 16
            Text {
                Layout.leftMargin: 4
                Layout.preferredWidth: 24
                horizontalAlignment: Text.AlignHCenter
                text: drawerItem.iconText
                font.family: Icons.familySolid
                font.weight: Font.Black
                font.pixelSize: AppScale.fs(18)
                color: drawerItem.highlighted ? Theme.onSecondaryContainer(Material.theme) : Theme.onSurfaceVariant(Material.theme)
            }
            Label {
                Layout.fillWidth: true
                text: drawerItem.text
                elide: Text.ElideRight
                font.pixelSize: AppScale.fs(14)
                font.weight: drawerItem.highlighted ? Font.Bold : Font.Medium
                color: drawerItem.highlighted ? Theme.onSecondaryContainer(Material.theme) : Theme.onSurface(Material.theme)
            }
        }

        background: Rectangle {
            radius: height / 2
            color: drawerItem.highlighted ? Theme.secondaryContainer(Material.theme)
                                          : (drawerItem.hovered ? Qt.alpha(Theme.onSurface(Material.theme), 0.08) : "transparent")
        }
    }
}
