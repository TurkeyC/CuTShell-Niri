pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Column {
    id: root

    required property PersistentProperties visibilities

    padding: Appearance.padding.xl

    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left

    spacing: Appearance.spacing.xxl

    SessionButton {
        id: logout

        icon: "logout"
        command: Config.session.commands.logout

        KeyNavigation.down: shutdown

        Connections {
            target: root.visibilities

            function onSessionChanged(): void {
                if (root.visibilities.session)
                    logout.focus = true;
            }

            function onLauncherChanged(): void {
                if (root.visibilities.session && !root.visibilities.launcher)
                    logout.focus = true;
            }
        }
    }

    SessionButton {
        id: shutdown

        icon: "power_settings_new"
        command: Config.session.commands.shutdown

        KeyNavigation.up: logout
        KeyNavigation.down: hibernate
    }

    AnimatedImage {
        width: Config.session.sizes.button
        height: Config.session.sizes.button
        sourceSize.width: width
        sourceSize.height: height

        playing: visible
        asynchronous: true
        speed: 0.7
        source: Paths.absolutePath(Config.paths.sessionGif)
    }

    SessionButton {
        id: hibernate

        icon: "downloading"
        command: Config.session.commands.hibernate

        KeyNavigation.up: shutdown
        KeyNavigation.down: reboot
    }

    SessionButton {
        id: reboot

        icon: "cached"
        command: Config.session.commands.reboot

        KeyNavigation.up: hibernate
    }

    component SessionButton: StyledRect {
        id: button

        required property string icon
        required property list<string> command

        // ── Long-press state ──────────────────────────────────────
        property bool isHeld: false
        property real pressProgress: 0.0

        implicitWidth: Config.session.sizes.button
        implicitHeight: Config.session.sizes.button

        radius: Appearance.rounding.large
        color: button.activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        // ── Timer fires after the hold duration ───────────────────
        Timer {
            id: holdTimer
            interval: Config.session.longPressDuration
            onTriggered: button.execute()
        }

        // ── Animate progress from 0 → 1 while held ────────────────
        NumberAnimation {
            id: progressAnim
            target: button
            property: "pressProgress"
            from: 0.0
            to: 1.0
            duration: Config.session.longPressDuration
            running: isHeld
        }

        // ── Helpers ───────────────────────────────────────────────
        function execute(): void {
            Quickshell.execDetached(button.command);
            resetHold();
        }

        function startHold(): void {
            isHeld = true;
            holdTimer.start();
        }

        function resetHold(): void {
            holdTimer.stop();
            progressAnim.stop();
            isHeld = false;
            pressProgress = 0.0;
        }

        // ── Mouse interaction (StateLayer is a MouseArea) ─────────
        StateLayer {
            id: stateLayer
            radius: parent.radius
            color: button.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            // No onClicked — execution is handled by holdTimer
        }

        Connections {
            target: stateLayer
            function onPressedChanged(): void {
                if (stateLayer.pressed)
                    button.startHold();
                else
                    button.resetHold();
            }
        }

        // ── Keyboard interaction ──────────────────────────────────
        Keys.onEnterPressed: button.startHold()
        Keys.onReturnPressed: button.startHold()
        Keys.onEscapePressed: {
            button.resetHold();
            root.visibilities.session = false;
        }

        // Cancel hold when focus moves to another widget
        onActiveFocusChanged: {
            if (!activeFocus)
                button.resetHold();
        }

        // Navigate with Ctrl+J/K and Tab/Shift+Tab
        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if (event.key === Qt.Key_K && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }

        // ── Icon ──────────────────────────────────────────────────
        MaterialIcon {
            anchors.centerIn: parent

            text: button.icon
            color: button.activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.headlineLarge
            font.weight: 500
        }

        // ── Progress ring overlay (visible during long-press) ─────
        Canvas {
            id: progressRing
            anchors.fill: parent
            visible: isHeld
            antialiasing: true

            property color ringColor: button.activeFocus
                ? Colours.palette.m3onSecondaryContainer
                : Colours.palette.m3onSurface

            onPaint: {
                var ctx = getContext("2d");
                if (!ctx) return;
                ctx.reset();

                var w = width;
                var h = height;
                var cx = w / 2;
                var cy = h / 2;
                var r = Math.min(cx, cy) - 4;
                var lw = 2.5;

                // Subtle background track
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                ctx.lineWidth = lw;
                ctx.stroke();

                if (pressProgress > 0) {
                    // Arc from the top, clockwise
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (Math.PI * 2 * pressProgress);

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, endAngle);
                    ctx.strokeStyle = progressRing.ringColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
            }

            // Repaint whenever the progress or focus-state changes
            Connections {
                target: button
                function onPressProgressChanged(): void { progressRing.requestPaint(); }
                function onActiveFocusChanged(): void { progressRing.requestPaint(); }
            }
        }
    }
}
