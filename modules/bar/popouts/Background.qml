import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper
    required property bool invertBottomRounding
    readonly property real rounding: wrapper.isDetached ? Appearance.rounding.normal : Config.border.rounding
    readonly property bool flatten: wrapper.width < rounding * 2
    readonly property real roundingX: flatten ? wrapper.width / 2 : rounding
    property real ibr: invertBottomRounding ? -1 : 1

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Horizontal bar (bar at top, popup opens downward):
    // Top edge = flat against bar (no corner arcs).
    // Bottom corners = outward (normal) or inward (inverted, when reaching screen bottom).

    // 1. Top edge: flat, straight right
    PathLine {
        relativeX: root.wrapper.width
        relativeY: 0
    }

    // 2. Right edge: down to just above bottom-right corner
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.rounding
    }

    // 3. Bottom-right corner: outward (ibr=1) or inward (ibr=-1)
    PathArc {
        relativeX: -root.roundingX
        relativeY: root.rounding * root.ibr
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: root.rounding
        direction: root.ibr < 0 ? PathArc.Counterclockwise : PathArc.Clockwise
    }

    // 4. Bottom edge: leftwards
    PathLine {
        relativeX: -(root.wrapper.width - root.roundingX * 2)
        relativeY: 0
    }

    // 5. Bottom-left corner: outward (ibr=1) or inward (ibr=-1)
    PathArc {
        relativeX: -root.roundingX
        relativeY: -root.rounding * root.ibr
        radiusX: Math.min(root.rounding, root.wrapper.width)
        radiusY: root.rounding
        direction: root.ibr < 0 ? PathArc.Counterclockwise : PathArc.Clockwise
    }

    // 6. Left edge: up back to origin (auto-closes via implicit line to start)
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.rounding)
    }

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on ibr {
        Anim {}
    }

}
