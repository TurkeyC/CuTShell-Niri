pragma ComponentBehavior: Bound

import qs.services
import qs.config
import qs.components
import QtQuick
import QtQuick.Layouts

import "context"

StyledRect {
    id: root

    // required property ShellScreen screen

    readonly property int activeWsId: Niri.focusedWorkspaceIndex + 1
    readonly property var occupied: Niri.workspaceHasWindows
    readonly property int dynamicWsCount: Math.min(Niri.currentOutputWorkspaces.length + 1, 10)
    readonly property int groupOffset: 0  // 动态显示全部 workspace，无分页

    readonly property int focusedWindowId: Niri.focusedWindow?.id ?? -1

    implicitWidth: layout.implicitWidth + Appearance.padding.xs * 2
    implicitHeight: Config.bar.sizes.innerHeight

    color: Colours.tPalette.m3surfaceContainer
    radius: Appearance.rounding.full

    signal requestWindowPopout

    Connections {
        target: Niri
        function onWsContextTypeChanged() {
            if (Niri.wsContextType === "workspaces") {
                Niri.wsContextAnchor = root;
            }
        }
    }

    Loader {
        active: Config.bar.workspaces.occupiedBg
        asynchronous: true
        anchors.fill: parent
        anchors.margins: Appearance.padding.xs
        sourceComponent: OccupiedBg {
            workspaces: workspaces
            occupied: Object.assign({}, root.occupied, {[root.activeWsId]: true})
            groupOffset: root.groupOffset
        }
    }

    Loader {
        active: Config.bar.workspaces.windowRighClickContext && Niri.wsContextType === "workspaces"
        asynchronous: true
        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.xs
        z: Niri.wsContextType === "workspaces" ? -10 : 0
        sourceComponent: ContextBg {
            groupOffset: root.groupOffset
            wsOffset: root.x
            anchorWs: Niri.wsContextAnchor
            wsCount: workspaces.count
        }
    }

    RowLayout {
        id: layout
        z: 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Appearance.padding.xs
        spacing: Math.floor(Appearance.spacing.sm / 2)

        Repeater {
            id: workspaces
            model: Math.max(1, root.dynamicWsCount)

            Workspace {
                activeWsId: root.activeWsId
                occupied: root.occupied
                groupOffset: root.groupOffset
                focusedWindowId: root.focusedWindowId
                windowPopoutSignal: root
            }
        }
    }

    Loader {
        z: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        active: Config.bar.workspaces.activeIndicator
        asynchronous: true
        sourceComponent: ActiveIndicator {
            activeWsId: root.activeWsId
            workspaces: workspaces
            mask: layout
            groupOffset: root.groupOffset
        }
    }
}
