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
    readonly property bool flattenW: wrapper.width < rounding * 2
    readonly property bool flattenH: wrapper.height < rounding * 2
    readonly property real capRoundingW: flattenW ? Math.max(1, wrapper.width / 2) : rounding
    readonly property real capRoundingH: flattenH ? Math.max(1, wrapper.height / 2) : rounding
    // Widen shape by rounding on each side so the straight edges align with content padding
    readonly property real shapeWidth: wrapper.width + (wrapper.isDetached ? 0 : rounding * 2)
    property real ibr: invertBottomRounding ? -1 : 1

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Shape within wrapper bounds. Path order (counterclockwise):
    //   Arc(tl) → Line(left) → Arc(bl) → Line(bottom) →
    //   Arc(br) → Line(right) → Arc(tr) → [implicit close = top edge]
    //
    // Top corners: Clockwise = outward convex (always).
    // Bottom corners: ibr=1 → Counterclockwise = outward,
    //                 ibr=-1 → Clockwise = inward.

    // 1. Top-left corner: outward convex.
    //    Arc from (0, 0) curving RIGHT and DOWN into the wrapper.
    //    Fill to LEFT of the directed edge bulges OUTSIDE (up and left).
    PathArc {
        relativeX: root.capRoundingW
        relativeY: root.capRoundingH
        radiusX: root.capRoundingW
        radiusY: root.capRoundingH
        direction: PathArc.Clockwise
    }

    // 2. Left edge: down
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.capRoundingH * 2
    }

    // 3. Bottom-left corner
    PathArc {
        relativeX: root.capRoundingW
        relativeY: root.capRoundingH
        radiusX: root.capRoundingW
        radiusY: root.capRoundingH
        direction: root.ibr < 0 ? PathArc.Clockwise : PathArc.Counterclockwise
    }

    // 4. Bottom edge: right (both ibr directions use same endpoint)
    PathLine {
        relativeX: Math.max(0, root.shapeWidth - root.capRoundingW * 4)
        relativeY: 0
    }

    // 5. Bottom-right corner
    PathArc {
        relativeX: root.capRoundingW
        relativeY: -root.capRoundingH
        radiusX: root.capRoundingW
        radiusY: root.capRoundingH
        direction: root.ibr < 0 ? PathArc.Clockwise : PathArc.Counterclockwise
    }

    // 6. Right edge: up
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.capRoundingH * 2)
    }

    // 7. Top-right corner: outward convex.
    //    Arc from (W-r, r) curving RIGHT and UP to (W, 0).
    PathArc {
        relativeX: root.capRoundingW
        relativeY: -root.capRoundingH
        radiusX: root.capRoundingW
        radiusY: root.capRoundingH
        direction: PathArc.Clockwise
    }

    // [Implicit close: top edge from (W, 0) left back to (0, 0)]

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on ibr {
        Anim {}
    }

}
