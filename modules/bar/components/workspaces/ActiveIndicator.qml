pragma ComponentBehavior: Bound
import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property int groupOffset

    readonly property int wsCount: workspaces.count

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += wsCount;
        return i % wsCount;
    }
    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    property int cWs
    property int lastWs

    // Geometry tracking - horizontal layout: track X position
    property real leading: workspaces.itemAt(currentWsIdx)?.x ?? 0
    property real trailing: workspaces.itemAt(currentWsIdx)?.x ?? 0

    property real currentSize: workspaces.itemAt(currentWsIdx)?.size ?? 0
    property real offset: Math.min(leading, trailing)

    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            return ws ? Math.min(ws.x + ws.size - offset, s) : 0;
        }
        return s;
    }

    clip: true
    x: offset + mask.x
    implicitHeight: Config.bar.sizes.innerHeight - Appearance.padding.xs * 2
    implicitWidth: size
    radius: Appearance.rounding.full
    color: Colours.palette.m3primary

    anchors {
        top: parent.top
        bottom: parent.bottom
        topMargin: Appearance.padding.xs
        bottomMargin: Appearance.padding.xs
    }

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: -root.offset
        y: 0
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight
    }

    // Trail animations
    Behavior on leading {
        enabled: Config.bar.workspaces.activeTrail
        Anim {}
    }
    Behavior on trailing {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {
            duration: Appearance.anim.durations.normal * 2
        }
    }
    Behavior on currentSize {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }
    Behavior on offset {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }
    Behavior on size {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        easing.bezierCurve: Appearance.anim.curves.emphasized
    }
}
