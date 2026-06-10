pragma ComponentBehavior: Bound

import qs.services
import qs.components
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var workspace
    property bool popupActive: (Niri.wsContextAnchor === root) || (Niri.wsContextAnchor === workspace) || (Niri.wsContextType === "workspaces")

    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
    Layout.preferredWidth: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2
    Layout.preferredHeight: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2

    implicitHeight: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2 + (popupActive ? Config.bar.workspaces.windowContextWidth : 0)
    implicitWidth: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2
    Behavior on implicitHeight {
        Anim {
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    z: popupActive ? 90 : 0

    ColumnLayout {
        id: content
        anchors.top: parent.top
        spacing: Appearance.padding.xs

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2
            Layout.preferredWidth: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2

            StyledText {
                id: indicator
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                animate: true
                font.family: Appearance.font.family.mono
                text: {
                    const wsName = Niri.getWorkspaceNameByIndex(root.workspace.index);
                    // workspace 有自定义名称时直接显示
                    if (wsName && wsName !== "") {
                        return wsName;
                    }
                    const label = Config.bar.workspaces.label || root.workspace.ws;
                    const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                    const activeLabel = Config.bar.workspaces.activeLabel || (root.workspace.isOccupied ? occupiedLabel : label);
                    return root.workspace.activeWsId === root.workspace.ws ? activeLabel
                         : root.workspace.isOccupied ? occupiedLabel : label;
                }

                color: Config.bar.workspaces.occupiedBg || root.workspace.isOccupied || root.workspace.activeWsId === root.workspace.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                opacity: root.workspace.isOccupied || root.workspace.activeWsId === root.workspace.ws ? 1.0 : 0.35
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Loader {
            active: root.popupActive
            sourceComponent: StyledText {
                color: Config.bar.workspaces.occupiedBg || root.workspace.isOccupied || root.workspace.activeWsId === root.workspace.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                font.family: Appearance.font.family.mono
                text: Niri.getWorkspaceNameByIndex(root.workspace.index) || "Workspace " + (root.workspace.index + 1)
            }
        }
        z: 1
    }

    Interaction {
        id: interactionArea
    }

    component Interaction: StateLayer {
        id: mouseArea
        anchors.fill: root
        acceptedButtons: Qt.LeftButton
        cursorShape: (Qt.PointingHandCursor)
        pressAndHoldInterval: Appearance.anim.durations.small

        radius: Appearance.rounding.small

        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                const wsArrayIndex = root.workspace.index + root.workspace.groupOffset;
                if (Niri.focusedWorkspaceIndex !== wsArrayIndex)
                    Niri.switchToWorkspaceByIndex(wsArrayIndex);
                return;
            }
        }
    }
}
