pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Celestia
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Loader {
    active: Config.background.backdrop.enabled

    sourceComponent: Variants {
        id: root
        model: Quickshell.screens

        PanelWindow {
            id: backdropWindow
            required property var modelData

            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:Backdrop"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            color: "transparent"

            Connections {
                target: Wallpapers
                function onFrameReady(path): void {
                    if (path === Wallpapers.current) {
                        const old = bgImage.source;
                        bgImage.source = "";
                        bgImage.source = old;
                    }
                }
            }

            readonly property string wallpaperSource: {
                const path = Wallpapers.current;
                if (!path) return "";
                const source = Wallpapers.getColorSource(path);
                if (source.toString().startsWith("/")) return "file://" + source;
                return source;
            }

            Image {
                id: bgImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: {
                    const src = backdropWindow.wallpaperSource;
                    if (!src) return "";
                    if (src.startsWith("file://")) {
                        const localPath = src.substring(7);
                        if (!CUtils.exists(localPath)) return "";
                    }
                    return src;
                }

                sourceSize.width: backdropWindow.width / 4
                sourceSize.height: backdropWindow.height / 4

                asynchronous: true
                cache: true
                smooth: true

                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim {} }

                layer.enabled: status === Image.Ready && Config.background.backdrop.blurEnabled
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: Config.background.backdrop.blur
                    blurMax: 64
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: Config.background.backdrop.tintEnabled
                color: Colours.palette.m3surface
                opacity: Config.background.backdrop.tintOpacity
            }
        }
    }
}
