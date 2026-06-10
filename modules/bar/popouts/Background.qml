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
    property real ibr: invertBottomRounding ? 1 : -1

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Dashboard 风格弹窗：顶部外扩圆角（贴着 bar 的边向外凸出），底部内收圆角

    // 0. 起点：从 (roundingX, 0) 开始（为顶部左角留空间）
    PathMove { x: root.roundingX; y: 0 }

    // 1. 顶部直线：right
    PathLine { relativeX: root.wrapper.width - root.roundingX * 2; relativeY: 0 }

    // 2. 顶部右角：外扩，顺时针
    PathArc {
        relativeX: root.roundingX
        relativeY: root.rounding
        radiusX: root.roundingX
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    // 3. 右侧直线：down
    PathLine { relativeX: 0; relativeY: root.wrapper.height - root.rounding * 2 }

    // 4. 底部右角：内收(ibr=-1, CCW) 或 外扩(ibr=1, CW)
    PathArc {
        relativeX: -root.roundingX
        relativeY: root.rounding * root.ibr
        radiusX: root.roundingX
        radiusY: root.rounding
        direction: root.ibr < 0 ? PathArc.Counterclockwise : PathArc.Clockwise
    }

    // 5. 底部直线：left
    PathLine { relativeX: -(root.wrapper.width - root.roundingX * 2); relativeY: 0 }

    // 6. 底部左角：内收 或 外扩
    PathArc {
        relativeX: -root.roundingX
        relativeY: -root.rounding * root.ibr
        radiusX: root.roundingX
        radiusY: root.rounding
        direction: root.ibr < 0 ? PathArc.Counterclockwise : PathArc.Clockwise
    }

    // 7. 左侧直线：up
    PathLine { relativeX: 0; relativeY: -(root.wrapper.height - root.rounding * 2) }

    // 8. 顶部左角：外扩，顺时针
    PathArc {
        relativeX: root.roundingX
        relativeY: -root.rounding
        radiusX: root.roundingX
        radiusY: root.rounding
        direction: PathArc.Clockwise
    }

    Behavior on fillColor {
        CAnim {}
    }

    Behavior on ibr {
        Anim {}
    }

}
