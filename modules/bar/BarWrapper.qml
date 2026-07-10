pragma ComponentBehavior: Bound

import qs.components
import qs.config
import "popouts" as BarPopouts
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts

    readonly property int padding: Math.max(Appearance.padding.sm, Config.border.thickness)
    readonly property int contentHeight: Config.bar.sizes.innerHeight + padding * 2
    readonly property int exclusiveZone: Config.bar.persistent || visibilities.bar ? contentHeight : Config.border.thickness
    readonly property bool shouldBeVisible: Config.bar.persistent || visibilities.bar || isHovered
    property bool isHovered

    property alias content: content

    function checkPopout(x, button = Qt.LeftButton): void {
        content.item?.checkPopout(x, button);
    }

    function handleWheel(x: real, angleDelta: point): void {
        content.item?.handleWheel(x, angleDelta);
    }

    visible: height > Config.border.thickness
    implicitHeight: Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitHeight: root.contentHeight
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitHeight"
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitHeight"
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.emphasizedAccel
            }
        }
    ]

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        active: root.shouldBeVisible || root.visible

        sourceComponent: Bar {
            width: parent.width
            height: root.contentHeight
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }
}
