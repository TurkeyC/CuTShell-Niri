import qs.components.controls
import qs.services
import qs.config
import qs.modules.bar.popouts as BarPopouts
import qs.modules.osd as Osd
import Quickshell
import QtQuick

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property PersistentProperties visibilities
    required property Panels panels
    required property Item bar

    property bool osdHovered
    property point dragStart
    // Unified panel state: tracks which panel was opened via shortcut
    // Only one shortcut-activated panel at a time; empty string means idle
    property string shortcutPanel: ""

    function isShortcutActive(panel: string): bool {
        return shortcutPanel === panel;
    }

    function setShortcutPanel(panel: string): void {
        shortcutPanel = panel;
    }

    function clearShortcutPanel(panel: string): void {
        if (shortcutPanel === panel)
            shortcutPanel = "";
    }

    property bool draggingBar: false

    cursorShape: draggingBar && pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = bar.implicitHeight + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + panel.height + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = Config.border.thickness + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + panel.width + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < Config.border.thickness + panel.x + panel.width && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Config.border.thickness + panel.x && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        return y < bar.implicitHeight + panel.y + panel.height && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real): bool {
        return y > root.height - Config.border.thickness - panel.height - Config.border.rounding && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (event.y < bar.implicitHeight) {
            bar.handleWheel(event.x, event.angleDelta);
        }
    }

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: event => {
        dragStart = Qt.point(event.x, event.y);
        draggingBar = dragStart.y < bar.implicitHeight;

        if (event.y >= bar.implicitHeight)
            return;

        if (event.button === Qt.RightButton) {
            // 右键：非 tray/statusIcons/workspaces 区域 → 切换 dashboard
            const id = bar.content.item?.childAt(event.x, bar.content.item.height / 2)?.id;
            if (id === "tray" || id === "statusIcons") {
                bar.checkPopout(event.x, event.button);
            } else if (id !== "workspaces") {
                visibilities.dashboard = !visibilities.dashboard;
            }
        } else if (event.button === Qt.LeftButton) {
            // 左键：触发弹窗（checkPopout 内部按组件类型处理）
            bar.checkPopout(event.x, event.button);
        }
    }

    onReleased: event => {
        draggingBar = false;
    }

    onClicked: event => {
        if (event.button !== Qt.LeftButton || event.y <= bar.implicitHeight)
            return;

        // 点击在 bar 外 → 关闭弹窗
        if (popouts.currentName !== "wirelesspassword"
            && !inLeftPanel(panels.popouts, event.x, event.y)) {
            popouts.hasCurrent = false;
        }
    }

    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide panels not activated by shortcut
            if (!isShortcutActive("osd")) {
                visibilities.osd = false;
                osdHovered = false;
            }

            if (!isShortcutActive("dashboard"))
                visibilities.dashboard = false;

            if (!isShortcutActive("utilities"))
                visibilities.utilities = false;

            if (!isShortcutActive("quicktoggles"))
                visibilities.quicktoggles = false;

            if (popouts.currentName !== "wirelesspassword")
                popouts.hasCurrent = false;

            if (Config.bar.showOnHover)
                bar.isHovered = false;
            console.log("Bar hidden");
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;

        // Show bar in non-exclusive mode on hover
        if (!visibilities.bar && Config.bar.showOnHover && y < bar.implicitHeight)
            bar.isHovered = true;
        // console.log("Bar hovered!")

        // Show/hide bar on drag
        if (pressed && dragStart.y < bar.implicitHeight) {
            const dragY = y - dragStart.y;
            if (dragY > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragY < -Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        // Show osd on hover
        const showOsd = inRightPanel(panels.osd, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!isShortcutActive("osd")) {
            visibilities.osd = showOsd;
            osdHovered = showOsd;
        } else if (showOsd) {
            // If hovering over OSD area while in shortcut mode, transition to hover control
            clearShortcutPanel("osd");
            osdHovered = true;
        }

        // Show/hide session on drag
        if (pressed && inRightPanel(panels.session, dragStart.x, dragStart.y) && withinPanelHeight(panels.session, x, y)) {
            const dragX = x - dragStart.x;
            if (dragX < -Config.session.dragThreshold)
                visibilities.session = true;
            else if (dragX > Config.session.dragThreshold)
                visibilities.session = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            visibilities.launcher = inBottomPanel(panels.launcher, x, y);
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            const dragY = y - dragStart.y;
            if (dragY < -Config.launcher.dragThreshold)
                visibilities.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                visibilities.launcher = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            const dragY = y - dragStart.y;
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.dashboard = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!isShortcutActive("utilities")) {
            visibilities.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            clearShortcutPanel("utilities");
        }

        // Show quicktoggles on hover (bottom-right area)
        const showQuicktoggles = inBottomPanel(panels.quicktoggles, x, y) && inRightPanel(panels.quicktoggles, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!isShortcutActive("quicktoggles")) {
            visibilities.quicktoggles = showQuicktoggles;
        } else if (showQuicktoggles) {
            // If hovering over quicktoggles area while in shortcut mode, transition to hover control
            clearShortcutPanel("quicktoggles");
        }

    }

    // Monitor individual visibility changes
    Connections {
        target: root.visibilities

        function onLauncherChanged() {
            // Launcher doesn't cascade to other panels — each panel manages itself
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                // Dashboard became visible, check if this should be shortcut mode
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.setShortcutPanel("dashboard");
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.clearShortcutPanel("dashboard");
            }
        }

        function onOsdChanged() {
            if (root.visibilities.osd) {
                // OSD became visible, check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osd, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.setShortcutPanel("osd");
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.clearShortcutPanel("osd");
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                // Utilities became visible, check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.setShortcutPanel("utilities");
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.clearShortcutPanel("utilities");
            }
        }

        function onQuicktogglesChanged() {
            if (root.visibilities.quicktoggles) {
                // Quicktoggles became visible, check if this should be shortcut mode
                const inQuicktogglesArea = root.inBottomPanel(root.panels.quicktoggles, root.mouseX, root.mouseY) && root.inRightPanel(root.panels.quicktoggles, root.mouseX, root.mouseY);
                if (!inQuicktogglesArea) {
                    root.setShortcutPanel("quicktoggles");
                }
            } else {
                // Quicktoggles hidden, clear shortcut flag
                root.clearShortcutPanel("quicktoggles");
            }
        }
    }

    Osd.Interactions {
        screen: root.screen
        visibilities: root.visibilities
        hovered: root.osdHovered
    }
}
