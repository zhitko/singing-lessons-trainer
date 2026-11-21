pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Material
import "../utils"

// Decorative notation, deliberately static so it cannot be mistaken for live pitch.
Item {
    id: root
    property color ink: Theme.primary(Material.theme)
    property real lineOpacity: 0.16
    property real noteOpacity: 0.45
    property var notes: [0, 1, 3, 2, 4, 3, 1, 2]
    readonly property real staffSpacing: Math.min(16, height / 8)
    Accessible.ignored: true

    Repeater {
        model: 5
        Rectangle {
            required property int index
            x: 0
            y: root.height / 2 + (index - 2) * root.staffSpacing
            width: root.width
            height: 1
            color: root.ink
            opacity: root.lineOpacity
        }
    }

    Repeater {
        model: root.notes
        Item {
            id: note
            required property int index
            required property int modelData
            x: root.width * (index + 0.5) / root.notes.length
            y: root.height / 2 + (2 - modelData) * root.staffSpacing / 2
            opacity: root.noteOpacity

            Rectangle {
                width: root.staffSpacing * 0.95
                height: root.staffSpacing * 0.65
                anchors.centerIn: parent
                rotation: -25
                radius: height / 2
                color: root.ink
            }
            Rectangle {
                x: root.staffSpacing * 0.4
                y: -root.staffSpacing * 2.5
                width: 2
                height: root.staffSpacing * 2.5
                color: root.ink
            }
        }
    }
}
