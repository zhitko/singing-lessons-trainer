import QtQuick
import QtQuick.Controls.Material
import "../utils"

// One score column on the training result card: label, current value,
// trend vs. the previous attempt, and the most recent previous attempts.
Column {
    id: root

    property string label: ""
    property real value: 0
    property bool hasValue: false
    // Previous attempts, most recent first. Entries may be null (unknown).
    property var history: []
    // For error metrics a smaller number is an improvement.
    property bool lowerIsBetter: false

    readonly property bool compact: AppScale.isCompact
    readonly property color ink: Theme.onPrimaryContainer(Material.theme)
    readonly property bool hasPrevious: history.length > 0 && history[0] !== null && history[0] !== undefined
    readonly property int delta: hasPrevious ? Math.round(value) - Math.round(history[0]) : 0

    spacing: 0

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        font.pixelSize: AppScale.fs(root.compact ? 11 : 13)
        font.weight: 600
        color: root.ink
        opacity: 0.7
    }

    Text {
        id: valueText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.hasValue ? Math.round(root.value) + "%" : "—"
        font.pixelSize: AppScale.fs(root.compact ? 30 : 40)
        font.weight: 700
        color: root.ink

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: valueText; property: "scale"; from: 1.0; to: 1.12; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: valueText; property: "scale"; from: 1.12; to: 1.0; duration: 180; easing.type: Easing.OutBack }
            }
        }
    }

    // Trend vs. the most recent previous attempt
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        // Keep the row's height so both metric columns stay aligned
        opacity: root.hasValue && root.hasPrevious ? 0.85 : 0
        readonly property bool improved: root.lowerIsBetter ? root.delta < 0 : root.delta > 0
        text: root.delta > 0 ? ("▲ +" + root.delta + "%") : (root.delta < 0 ? ("▼ " + root.delta + "%") : "● 0%")
        font.pixelSize: AppScale.fs(12)
        font.weight: 600
        color: root.delta === 0 ? root.ink
               : (improved ? Theme.scoreColor(100, Material.theme) : Theme.scoreColor(1, Material.theme))
    }

    // Previous attempts: most recent first, older ones smaller and fainter
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: 2
        spacing: root.compact ? 6 : 10
        visible: root.history.length > 0

        Repeater {
            model: root.history

            Text {
                required property var modelData
                required property int index
                text: (modelData === null || modelData === undefined) ? "—" : Math.round(modelData) + "%"
                font.pixelSize: AppScale.fs(Math.max(root.compact ? 10 : 11, (root.compact ? 13 : 15) - index))
                font.weight: index === 0 ? 600 : 500
                color: root.ink
                opacity: Math.max(0.3, 0.7 - index * 0.1)
            }
        }
    }
}
