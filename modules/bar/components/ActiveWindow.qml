pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    // Column count indicator
    readonly property var activeWindows: Niri.getActiveWorkspaceWindows()
    readonly property int columnCount: {
        const cols = new Set();
        for (const w of activeWindows) {
            if (w.layout?.pos_in_scrolling_layout)
                cols.add(w.layout.pos_in_scrolling_layout[0]);
        }
        return cols.size;
    }
    readonly property int focusedColumn: {
        const fw = Niri.focusedWindow;
        if (!fw?.layout?.pos_in_scrolling_layout)
            return 0;
        const focusedX = fw.layout.pos_in_scrolling_layout[0];
        const cols = [];
        for (const w of activeWindows) {
            if (w.layout?.pos_in_scrolling_layout)
                cols.push(w.layout.pos_in_scrolling_layout[0]);
        }
        const sorted = [...new Set(cols)].sort((a, b) => a - b);
        return sorted.indexOf(focusedX) + 1;
    }

    readonly property string windowTitle: Niri.focusedWindowTitle ?? qsTr("Desktop")

    function getCompactName() {
        if (!root.windowTitle || root.windowTitle === qsTr("Desktop"))
            return qsTr("Desktop");
        const parts = root.windowTitle.split(/\s+[\-–—]\s+/);
        if (parts.length > 1)
            return parts[parts.length - 1].trim();
        return root.windowTitle;
    }

    clip: true
    implicitHeight: Config.bar.sizes.innerHeight
    implicitWidth: layout.implicitWidth

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Appearance.spacing.sm

        MaterialIcon {
            id: icon
            animate: true
            text: Icons.getAppCategoryIcon(Niri.focusedWindowClass, "desktop_windows")
            color: root.colour
        }

        StyledText {
            id: titleText
            Layout.fillWidth: true
            clip: true

            verticalAlignment: Text.AlignVCenter
            text: Config.bar.activeWindow.compact ? root.getCompactName() : root.windowTitle
            font.pointSize: Appearance.font.size.bodySmall
            font.family: Appearance.font.family.mono
            color: root.colour
        }

        StyledText {
            id: colIndicator

            visible: root.columnCount > 1
            text: `${root.focusedColumn}/${root.columnCount}`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.labelSmall
            font.family: Appearance.font.family.mono
        }
    }

    Behavior on implicitWidth {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }
}
