pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: root

    required property SystemTrayItem modelData

    implicitWidth: Appearance.font.size.small * 2
    implicitHeight: Appearance.font.size.small * 2

    // 悬停/点击反馈背景层（不拦截鼠标事件）
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Colours.palette.m3onSurface,
            feedbackArea.pressed ? 0.12 : feedbackArea.containsMouse ? 0.08 : 0)

        Behavior on color { CAnim {} }
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon, Config.bar.tray.iconSubs)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }

    // 仅用于视觉反馈的 MouseArea——所有按钮事件直接放过
    MouseArea {
        id: feedbackArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}