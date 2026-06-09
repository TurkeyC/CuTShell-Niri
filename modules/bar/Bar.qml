pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int hPadding: Appearance.padding.xl

    // Handle Workspace Popouts for Niri

    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (!root.popouts.hasCurrent && root.popouts.currentName === "wsWindow") {
                Niri.wsContextAnchor = null;
            }
        }
    }

    // Handle Popouts Hover

    function checkPopout(x: real): void {
        if (Niri.wsContextType === "workspaces") {
            // Workspace context menu
            const anchor = Niri.wsContextAnchor;
            if (!anchor) {
                popouts.hasCurrent = false;
                return;
            }
            popouts.currentCenter = Qt.binding(() => Math.round(anchor.mapToItem(root, (anchor.width) / 2, anchor.height).x));
            return;
        }

        const ch = childAt(x, height / 2) as WrappedLoader;
        if (!ch?.item) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const left = ch.x;
        const item = ch.item;
        const itemWidth = item.implicitWidth;

        if (id === "statusIcons") {
            const items = item.items;
            const icon = items.childAt(mapToItem(items, x, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray") {
            const index = Math.floor(((x - left) / itemWidth) * item.items.count);
            const trayItem = item.items.itemAt(index);
            if (trayItem) {
                popouts.currentName = `traymenu${index}`;
                popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        }
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = childAt(x, height / 2) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            Niri.switchToWorkspaceUpDown(angleDelta.y > 0 ? "up" : "down");
        } else if (Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        }
    }

    spacing: Appearance.spacing.lg

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillWidth: enabled
                }
            }
            DelegateChoice {
                roleValue: "divider"
                delegate: WrappedLoader {
                    sourceComponent: Rectangle {
                        implicitWidth: 1
                        implicitHeight: Appearance.padding.md
                        color: Colours.palette.m3outlineVariant
                    }
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            // 右击 OsIcon 弹窗已停用
                        }
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {

                        property var anchorItem: Niri.wsContextAnchor && Niri.wsContextType !== "none" ? Niri.wsContextAnchor : null

                        // 右击工作区弹窗已停用
                        onRequestWindowPopout: {}
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
            // DelegateChoice {
            //     roleValue: "idleInhibitor"
            //     delegate: WrappedLoader {
            //         sourceComponent: IdleInhibitor {}
            //     }
            // }
        }
    }

    // Cached first/last enabled items — recomputed once when repeater changes
    property Item firstEnabled: null
    property Item lastEnabled: null

    function updateEnabledCache(): void {
        let first = null;
        let last = null;
        const count = repeater.count;
        for (let i = 0; i < count; i++) {
            const item = repeater.itemAt(i);
            if (item?.enabled) {
                if (!first) first = item;
                last = item;
            }
        }
        firstEnabled = first;
        lastEnabled = last;
    }

    Connections {
        target: repeater
        function onCountChanged() { root.updateEnabledCache(); }
    }

    Component.onCompleted: updateEnabledCache()

    component WrappedLoader: Loader {
        required property string id
        required property int index

        onEnabledChanged: root.updateEnabledCache()

        Layout.alignment: Qt.AlignVCenter

        Layout.leftMargin: root.firstEnabled === this ? root.hPadding : 0
        Layout.rightMargin: root.lastEnabled === this ? root.hPadding : 0

        asynchronous: true
        visible: enabled
        active: enabled
    }
}
