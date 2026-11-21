import QtQuick
import QtQuick.Controls.Material
import "../utils"

// Score in a ring, colored by Theme.scoreColor. A score of 0 means
// "not practiced yet" and shows a dash.
CircularProgress {
    id: root

    property real score: 0
    property string label: score > 0 ? Math.round(score) + "%" : "–"
    property int labelSize: Math.max(10, Math.round(width * 0.26))

    progress: Math.min(score / 100, 1.0)
    lineWidth: Math.max(4, Math.round(width * 0.09))
    color: Theme.scoreColor(score, Material.theme)
    backgroundColor: Theme.surfaceContainerHighest(Material.theme)
    implicitWidth: 48
    implicitHeight: implicitWidth

    Text {
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: AppScale.fs(root.labelSize)
        font.weight: Font.Bold
        color: root.score > 0 ? Theme.onSurface(Material.theme) : Theme.onSurfaceVariant(Material.theme)
    }
}
