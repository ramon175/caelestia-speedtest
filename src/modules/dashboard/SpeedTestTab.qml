pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    function formatTime(time: date): string {
        return Qt.formatTime(time, Units.twelveHourClock ? "h:mm a" : "hh:mm");
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            Dial {
                icon: "download"
                label: Tr.tr("Download")
                value: SpeedTest.downloadMbps
                measuring: SpeedTest.phase === "down"
                accent: Colours.palette.m3primary
            }

            Dial {
                icon: "upload"
                label: Tr.tr("Upload")
                value: SpeedTest.uploadMbps
                measuring: SpeedTest.phase === "up"
                accent: Colours.palette.m3secondary
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: statusRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: SpeedTest.error ? "error" : "network_check"
                    color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (SpeedTest.error)
                                return SpeedTest.error;
                            if (SpeedTest.phase === "down")
                                return Tr.tr("Measuring download…");
                            if (SpeedTest.phase === "up")
                                return Tr.tr("Measuring upload…");
                            if (SpeedTest.history.length > 0)
                                // TRANSLATORS: %1 = a clock time, e.g. 14:30
                                return Tr.tr("Last run at %1").arg(root.formatTime(SpeedTest.lastRun));
                            return Tr.tr("Ready to test");
                        }
                        color: SpeedTest.error ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        // TRANSLATORS: %1 = a network interface name, e.g. enp5s0
                        text: SpeedTest.iface ? Tr.tr("Fast.com via %1").arg(SpeedTest.iface) : Tr.tr("Fast.com")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                IconTextButton {
                    isRound: true
                    horizontalPadding: Tokens.padding.large
                    verticalPadding: Tokens.padding.small
                    inactiveColour: SpeedTest.running ? Colours.palette.m3errorContainer : Colours.palette.m3primary
                    inactiveOnColour: SpeedTest.running ? Colours.palette.m3onErrorContainer : Colours.palette.m3onPrimary
                    icon: SpeedTest.running ? "stop" : (SpeedTest.history.length > 0 ? "replay" : "play_arrow")
                    text: SpeedTest.running ? Tr.tr("Stop") : (SpeedTest.history.length > 0 ? Tr.tr("Run again") : Tr.tr("Run test"))
                    onClicked: SpeedTest.running ? SpeedTest.stop() : SpeedTest.start()
                }
            }
        }

        Repeater {
            model: SpeedTest.history.slice(1)

            delegate: RowLayout {
                id: entry

                required property var modelData

                Layout.leftMargin: Tokens.padding.large
                Layout.rightMargin: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.formatTime(entry.modelData.time)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    text: "download"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.down)
                    font: Tokens.font.body.small
                }

                MaterialIcon {
                    Layout.leftMargin: Tokens.spacing.small
                    text: "upload"
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.small
                }

                StyledText {
                    text: SpeedTest.formatMbps(entry.modelData.up)
                    font: Tokens.font.body.small
                }

                StyledText {
                    text: "Mbps"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }
    }

    component Dial: StyledRect {
        id: dial

        required property string icon
        required property string label
        required property real value
        required property bool measuring
        required property color accent

        implicitWidth: 260
        implicitHeight: dialLayout.implicitHeight + Tokens.padding.large * 2

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            id: dialLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: dial.icon
                    color: dial.accent
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    text: dial.label
                    color: dial.accent
                    font: Tokens.font.title.medium
                }
            }

            CircularProgress {
                id: gauge

                Layout.alignment: Qt.AlignHCenter
                implicitSize: 190

                // A 270° dial with the gap at the bottom
                startAngle: 135
                sweepAngle: 270
                strokeWidth: Tokens.padding.small
                fgColour: dial.accent
                value: isNaN(dial.value) ? 0 : dial.value / SpeedTest.fullScale
                wavy: dial.measuring

                Behavior on clampedVal {
                    Anim {}
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: SpeedTest.formatMbps(dial.value)
                        color: dial.measuring || !isNaN(dial.value) ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.headline.builders.large.scale(1.5).width(80).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Mbps"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    // TRANSLATORS: %1 = the dial's full-scale speed, e.g. 500
                    text: Tr.tr("max %1").arg(SpeedTest.fullScale)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
