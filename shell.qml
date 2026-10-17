import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool barVisible: false
    property var barData: ({})

    Process {
        id: collector
        command: ["bash", Quickshell.shellPath("collector.sh")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.barData = JSON.parse(line)
                } catch (e) {}
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            barVisible = !barVisible
        }
    }

    component InfoBox: Rectangle {
        property string label: ""
        color: "#000000"
        implicitWidth: infoLbl.implicitWidth + 8
        implicitHeight: 16
        Text {
            id: infoLbl
            anchors.centerIn: parent
            text: parent.label
            color: "#ffffff"
            font.pixelSize: 9
            font.family: "monospace"
        }
    }

    component StatBar: Item {
        id: statBar
        property real value: 0
        property string label: ""
        implicitWidth: Math.max(64, lbl.implicitWidth + 12)
        implicitHeight: 18

        Rectangle {
            anchors.fill: parent
            color: "#111111"
        }

        Item {
            id: clipper
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(100, statBar.value)) / 100
            clip: true

            Rectangle {
                width: statBar.width
                height: clipper.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ff0000" }
                    GradientStop { position: 0.2; color: "#ff9900" }
                    GradientStop { position: 0.4; color: "#ffee00" }
                    GradientStop { position: 0.6; color: "#33ff00" }
                    GradientStop { position: 0.8; color: "#00ccff" }
                    GradientStop { position: 1.0; color: "#6600ff" }
                }
            }
        }

        Rectangle {
            id: labelBg
            anchors.centerIn: parent
            color: "#000000"
            width: lbl.implicitWidth + 6
            height: lbl.implicitHeight + 2

            Text {
                id: lbl
                anchors.centerIn: parent
                text: statBar.label
                color: "#ffffff"
                font.pixelSize: 9
                font.family: "monospace"
            }
        }
    }

    PanelWindow {
        visible: barVisible
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 24
        color: "#000000"
        exclusiveZone: barVisible ? implicitHeight : 0

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            StatBar { value: barData.cpu_pct ?? 0; label: barData.cpu_label ?? "" }
            StatBar { value: barData.cpu_temp_pct ?? 0; label: barData.cpu_temp_label ?? "" }
            StatBar { value: barData.gpu_pct ?? 0; label: barData.gpu_label ?? "" }
            StatBar { value: barData.gpu_temp_pct ?? 0; label: barData.gpu_temp_label ?? "" }
            StatBar { value: barData.ram_pct ?? 0; label: barData.ram_label ?? "" }
            StatBar { value: barData.swap_pct ?? 0; label: barData.swap_label ?? "" }
            StatBar { value: barData.disk_pct ?? 0; label: barData.disk_label ?? "" }
            StatBar { value: barData.net_bar ?? 0; label: barData.net_label ?? "" }
        }

        Row {
            id: centerRow
            anchors.centerIn: parent
            spacing: 4
            StatBar { value: barData.year_pct ?? 0; label: barData.year_num ?? "" }
            StatBar { value: barData.month_pct ?? 0; label: barData.month_num ?? "" }
            StatBar { value: barData.day_pct ?? 0; label: barData.day_num ?? "" }
            StatBar { value: barData.hour_pct ?? 0; label: barData.hour_num ?? "" }
            StatBar { value: barData.minute_pct ?? 0; label: barData.minute_num ?? "" }
            InfoBox { label: barData.month_name ?? "" }
            InfoBox { label: barData.day_name ?? "" }
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            StatBar { value: barData.bright_pct ?? 0; label: barData.bright_label ?? "" }
            StatBar { value: barData.vol_pct ?? 0; label: barData.vol_label ?? "" }
            StatBar { value: barData.mic_pct ?? 0; label: barData.mic_label ?? "" }
            InfoBox { label: barData.layout ?? "" }
        }
    }
}
