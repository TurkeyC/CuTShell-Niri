pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services
import qs.config
import qs.modules.bar
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: bar
        }

        StyledWindow {
            id: win

            screen: scope.modelData
            name: "drawers"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session || visibilities.keybinds || visibilities.editingWeatherLocation || visibilities.dashboard || visibilities.manga || visibilities.novel || panels.popouts.isDetached ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region {
                readonly property bool extended: visibilities.session && Config.session.enabled
                readonly property bool captureOnClick: visibilities.launcher || visibilities.dashboard

                x: extended || captureOnClick ? 0 : Config.border.thickness
                y: extended || captureOnClick ? 0 : bar.implicitHeight
                width: extended || captureOnClick ? win.width : win.width - Config.border.thickness * 2
                height: extended || captureOnClick ? win.height : win.height - bar.implicitHeight - Config.border.thickness
                intersection: extended || captureOnClick ? Intersection.Combine : Intersection.Xor

                regions: regions.instances
            }

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Variants {
                id: regions

                model: panels.children

                Region {
                    required property Item modelData
                    readonly property bool _extd: visibilities.session && Config.session.enabled
                    readonly property bool _capture: visibilities.launcher || visibilities.dashboard

                    x: modelData.x + Config.border.thickness
                    y: modelData.y + bar.implicitHeight
                    width: modelData.width
                    height: modelData.height
                    // extended/capture 时用 Combine（面板保持可点），否则用 Subtract（从穿透区域挖出面板）
                    intersection: _extd || _capture ? Intersection.Combine : Intersection.Subtract
                }
            }

            // TODO: Implement focus grab for Niri when available

            StyledRect {
                anchors.fill: parent
                opacity: visibilities.session && Config.session.enabled || visibilities.launcher || visibilities.dashboard ? 0.5 : 0
                color: Colours.palette.m3scrim

                Behavior on opacity {
                    Anim {}
                }
            }

            Item {
                anchors.fill: parent
                opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 15
                    shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
                }

                Border {
                    bar: bar
                }

                Backgrounds {
                    panels: panels
                    bar: bar
                }
            }

            PersistentProperties {
                id: visibilities

                property bool bar
                property bool osd
                property bool session
                property bool launcher
                property bool dashboard
                property bool utilities
                property bool clipboardRequested
                property bool quicktoggles
                property bool keybinds
                property bool editingWeatherLocation
                property bool notifsExpanded
                property bool manga
                property bool novel

                Component.onCompleted: Visibilities.screens[scope.modelData.name] = this
            }

            Interactions {
                screen: scope.modelData
                popouts: panels.popouts
                visibilities: visibilities
                panels: panels
                bar: bar
                clickEffects: clickEffects

                Panels {
                    id: panels

                    screen: scope.modelData
                    visibilities: visibilities
                    bar: bar
                }

                BarWrapper {
                    id: bar

                    anchors.left: parent.left
                    anchors.right: parent.right

                    screen: scope.modelData
                    visibilities: visibilities
                    popouts: panels.popouts

                    Component.onCompleted: Visibilities.bars.set(scope.modelData, this)
                }

                ClickEffects {
                    id: clickEffects
                }
            }
        }
    }

}
