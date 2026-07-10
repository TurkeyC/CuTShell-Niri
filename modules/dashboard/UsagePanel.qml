import qs.components
import qs.components.effects
import qs.components.misc
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Celestia.Services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: 720
    implicitHeight: 500

    // ── State ──

    property string activeTab: "today"
    property var usageData: []
    property bool loading: false

    // Session detail expand state
    property string expandedAppId: ""
    property var sessionData: []

    // Timeline (all sessions for active period)
    property var periodSessions: []
    property real periodTotalMs: 0

    // ── Initialization ──

    Component.onCompleted: {
        // Force initial load — default to "today" as requested
        activeTab = "today";
        refreshData();
    }

    // Retry when UsageTracker becomes ready (defensive; normally ready at init)
    Connections {
        target: AppUsage
        function onReadyChanged() {
            if (AppUsage.ready) refreshData();
        }
    }

    // Periodic refresh timer (runs while panel exists)
    Timer {
        id: refreshTimer
        interval: 10000  // refresh every 10 seconds
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshData()
    }

    function refreshData() {
        if (AppUsage.ready) {
            loading = true;
            switch (activeTab) {
                case "today":  usageData = AppUsage.getTodayUsage(); break;
                case "week":   usageData = AppUsage.getWeekUsage(); break;
                case "month":  usageData = AppUsage.getMonthUsage(); break;
                case "total":  usageData = AppUsage.getTotalUsage(); break;
            }

            // Fetch all sessions for the timeline
            periodSessions = AppUsage.getPeriodSessions(activeTab);

            // Calculate total ms for the period
            var total = 0;
            var data = usageData;
            for (var i = 0; i < data.length; i++) total += data[i].total_ms;
            periodTotalMs = total;

            loading = false;

            // Also refresh expanded session if any app is expanded
            if (expandedAppId) {
                sessionData = AppUsage.getSessionHistory(expandedAppId, 20);
            }
        }
    }

    function selectTab(tab) {
        if (activeTab === tab) return;
        activeTab = tab;
        expandedAppId = "";
        sessionData = [];
        refreshData();
    }

    function toggleExpand(appId) {
        if (expandedAppId === appId) {
            expandedAppId = "";
            sessionData = [];
        } else {
            expandedAppId = appId;
            sessionData = AppUsage.getSessionHistory(appId, 20);
        }
    }

    // ── Layout ──

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Tabs ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: tabRow.implicitHeight + Appearance.spacing.md

            Row {
                id: tabRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.xs

                TabButton { tabName: "today";  label: qsTr("Today") }
                TabButton { tabName: "week";   label: qsTr("Week") }
                TabButton { tabName: "month";  label: qsTr("Month") }
                TabButton { tabName: "total";  label: qsTr("Total") }

                component TabButton: Item {
                    required property string tabName
                    required property string label

                    implicitWidth: btnText.implicitWidth + Appearance.padding.md * 2
                    implicitHeight: btnText.implicitHeight + Appearance.spacing.sm * 2

                    StyledRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: activeTab === tabName
                            ? Colours.palette.m3primaryContainer
                            : "transparent"
                    }

                    StyledText {
                        id: btnText
                        anchors.centerIn: parent
                        text: label
                        color: activeTab === tabName
                            ? Colours.palette.m3onPrimaryContainer
                            : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.labelLarge
                    }

                    StateLayer {
                        radius: Appearance.rounding.small
                        function onClicked(): void { selectTab(tabName); }
                    }
                }
            }
        }

        // ── Main Content: App List + Donut Chart ──
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.md

            // ── App List (left) ──
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.small
                color: Colours.tPalette.m3surfaceContainer

                StyledFlickable {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.sm
                    clip: true
                    contentHeight: listColumn.implicitHeight

                    Column {
                        id: listColumn
                        width: parent.width
                        spacing: Appearance.spacing.xs

                        // Empty state
                        StyledText {
                            width: parent.width
                            visible: !loading && usageData.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("No usage data yet")
                            color: Colours.palette.m3outline
                            font.pointSize: Appearance.font.size.bodyMedium
                            padding: Appearance.padding.xl * 2
                        }

                        // Loading state
                        StyledBusyIndicator {
                            id: busyIndicator
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: loading
                            running: loading
                        }

                        // App usage rows
                        Repeater {
                            model: usageData

                            delegate: Item {
                                id: appRow
                                required property var modelData
                                required property int index

                                width: parent.width
                                implicitHeight: expandedAppId === modelData.app_id
                                    ? contentCol.implicitHeight + sessionsCol.implicitHeight + Appearance.spacing.md
                                    : contentCol.implicitHeight

                                // ── Main row ──
                                Column {
                                    id: contentCol
                                    width: parent.width

                                    StyledRect {
                                        width: parent.width
                                        implicitHeight: Math.max(iconCol.implicitHeight, infoCol.implicitHeight) + Appearance.spacing.sm * 2
                                        radius: Appearance.rounding.small
                                        color: expandedAppId === modelData.app_id
                                            ? Colours.palette.m3surfaceContainerHigh
                                            : "transparent"

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Appearance.spacing.xs
                                            spacing: Appearance.spacing.sm

                                            // Rank + icon
                                            Column {
                                                id: iconCol
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Appearance.spacing.xs

                                                StyledText {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: (appRow.index + 1).toString()
                                                    color: Colours.palette.m3outline
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                }

                                                MaterialIcon {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: AppUsage.getIconForApp(modelData.app_id)
                                                    color: Colours.palette.m3primary
                                                    font.pointSize: Appearance.font.size.titleLarge
                                                }
                                            }

                                            // Info
                                            Column {
                                                id: infoCol
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - iconCol.implicitWidth - barCol.implicitWidth - Appearance.spacing.sm * 3
                                                spacing: Appearance.spacing.xs

                                                StyledText {
                                                    width: parent.width
                                                    text: modelData.app_id || modelData.app_name
                                                    color: Colours.palette.m3onSurface
                                                    font.pointSize: Appearance.font.size.bodyMedium
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    text: qsTr("%1 · %2 sessions")
                                                        .arg(modelData.total_display)
                                                        .arg(modelData.session_count)
                                                    color: Colours.palette.m3outline
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                }
                                            }

                                            // Usage bar + time
                                            Column {
                                                id: barCol
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Appearance.spacing.xs

                                                // Usage percentage bar
                                                StyledRect {
                                                    anchors.right: parent.right
                                                    implicitWidth: 80
                                                    implicitHeight: 6
                                                    radius: Appearance.rounding.full
                                                    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                                                    StyledRect {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        implicitWidth: parent.width * getPercentage(modelData.total_ms)
                                                        radius: Appearance.rounding.full
                                                        color: getBarColor(appRow.index)
                                                    }
                                                }

                                                StyledText {
                                                    anchors.right: parent.right
                                                    text: modelData.total_display
                                                    color: Colours.palette.m3onSurfaceVariant
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                }
                                            }
                                        }

                                        // Click to expand sessions
                                        StateLayer {
                                            radius: Appearance.rounding.small
                                            function onClicked(): void {
                                                toggleExpand(modelData.app_id);
                                            }
                                        }
                                    }
                                }

                                // ── Session timeline (expanded) ──
                                Column {
                                    id: sessionsCol
                                    anchors.top: contentCol.bottom
                                    width: parent.width
                                    visible: expandedAppId === modelData.app_id
                                    spacing: 6
                                    padding: Appearance.padding.sm

                                    StyledText {
                                        text: qsTr("Sessions")
                                        color: Colours.palette.m3primary
                                        font.pointSize: Appearance.font.size.labelLarge
                                        bottomPadding: 2
                                    }

                                    // Horizontal session bar (global timeline)
                                    Item {
                                        width: parent.width
                                        implicitHeight: 22

                                        // Background track
                                        StyledRect {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 8
                                            radius: 4
                                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                                        }

                                        // Color blocks for this app's sessions
                                        Row {
                                            id: sessionBar
                                            width: parent.width
                                            height: 8
                                            spacing: 2

                                            Repeater {
                                                model: periodSessions.length > 0 ? periodSessions : []

                                                delegate: StyledRect {
                                                    required property var modelData
                                                    required property int index

                                                    readonly property bool isThisApp: modelData.app_id === expandedAppId

                                                    width: periodTotalMs > 0
                                                        ? Math.max(2, (modelData.duration_ms / periodTotalMs) * (sessionBar.width - (periodSessions.length - 1) * 2))
                                                        : 0
                                                    height: 8
                                                    radius: 3
                                                    color: isThisApp ? getBarColor(appRow.index) : "transparent"
                                                }
                                            }
                                        }
                                    }

                                    // Top 10 longest sessions
                                    StyledText {
                                        text: qsTr("Top 10 Longest")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.labelSmall
                                        topPadding: 4
                                        bottomPadding: 2
                                    }

                                    Repeater {
                                        model: getTopSessions()

                                        delegate: Item {
                                            required property var modelData
                                            required property int index

                                            implicitHeight: 20
                                            width: parent.width

                                            Row {
                                                spacing: Appearance.spacing.sm
                                                anchors.verticalCenter: parent.verticalCenter

                                                StyledText {
                                                    text: (index + 1).toString() + "."
                                                    color: Colours.palette.m3outline
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                    width: 18
                                                }

                                                StyledText {
                                                    text: modelData.duration_display
                                                    color: Colours.palette.m3tertiary
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                    font.bold: true
                                                    width: 60
                                                }

                                                StyledText {
                                                    text: modelData.app_name || modelData.app_id
                                                    color: Colours.palette.m3onSurface
                                                    font.pointSize: Appearance.font.size.labelSmall
                                                    elide: Text.ElideRight
                                                    width: parent.parent.width - 90
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        visible: sessionData.length === 0
                                        text: qsTr("No sessions")
                                        color: Colours.palette.m3outline
                                        font.pointSize: Appearance.font.size.labelSmall
                                        padding: Appearance.padding.sm
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Donut Chart Panel (right) ──
            StyledRect {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                radius: Appearance.rounding.small
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.sm
                    spacing: Appearance.spacing.sm

                    // Donut chart + center overlay (fixed, not scrolling)
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: Math.min(parent.width, 180)
                        implicitHeight: (width) + 4
                        // ^ height = chart height + small gap

                        DonutChart {
                            id: donutChart
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, 180)
                            height: width
                            segments: buildDonutSegments()
                        }

                        // Center total label
                        StyledText {
                            id: centerLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -8
                            text: getTotalDisplay()
                            color: Colours.palette.m3onSurface
                            font.pointSize: Appearance.font.size.titleMedium
                            font.bold: true
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: centerLabel.bottom
                            anchors.topMargin: 2
                            text: qsTr("total")
                            color: Colours.palette.m3outline
                            font.pointSize: Appearance.font.size.labelSmall
                        }
                    }

                    // Legend (scrollable)
                    StyledFlickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: legendCol.implicitHeight

                        Column {
                            id: legendCol
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: buildDonutSegments()

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    width: parent.width
                                    implicitHeight: 22

                                    Row {
                                        spacing: Appearance.spacing.sm
                                        anchors.verticalCenter: parent.verticalCenter

                                        // Color swatch
                                        StyledRect {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: modelData.color
                                        }

                                        // App ID
                                        StyledText {
                                            text: modelData.label
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.pointSize: Appearance.font.size.labelSmall
                                            width: Math.min(implicitWidth + 4, parent.parent.width - 100)
                                            elide: Text.ElideRight
                                        }

                                        // Percentage
                                        StyledText {
                                            text: modelData.pct
                                            color: Colours.palette.m3onSurface
                                            font.pointSize: Appearance.font.size.labelSmall
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: buildDonutSegments().length === 0
                                text: qsTr("No data")
                                color: Colours.palette.m3outline
                                font.pointSize: Appearance.font.size.labelSmall
                                horizontalAlignment: Text.AlignHCenter
                                padding: Appearance.padding.md
                            }
                        }
                    }
                }
            }
        }

        // ── Total stat for selected period ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: totalStatLabel.implicitHeight + Appearance.padding.md

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.sm

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "schedule"
                    color: Colours.palette.m3tertiary
                    font.pointSize: Appearance.font.size.bodyMedium
                }

                StyledText {
                    id: totalStatLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var label = activeTab.charAt(0).toUpperCase() + activeTab.slice(1);
                        return qsTr("Total (%1): %2")
                            .arg(label)
                            .arg(getTotalDisplay());
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.bodySmall
                }
            }
        }

        // ── Footer (current session) ──
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: currentSessionText.implicitHeight + Appearance.padding.md * 2
            radius: Appearance.rounding.small
            color: Colours.tPalette.m3surfaceContainer

            visible: AppUsage.currentAppId !== ""

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.sm

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "circle"
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.labelSmall
                }

                StyledText {
                    id: currentSessionText
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Now: %1").arg(AppUsage.currentAppId || AppUsage.currentAppName)
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.bodySmall
                    elide: Text.ElideRight
                    width: root.implicitWidth - Appearance.padding.xl * 4
                }
            }
        }
    }

    // ── Helper Functions ──

    function getPercentage(totalMs) {
        if (!usageData || usageData.length === 0) return 0;
        var maxMs = usageData[0].total_ms;
        return maxMs > 0 ? Math.min(totalMs / maxMs, 1.0) : 0;
    }

    function getBarColor(index) {
        var colors = [
            Colours.palette.m3primary,
            Colours.palette.m3secondary,
            Colours.palette.m3tertiary,
            Colours.palette.m3error
        ];
        return colors[index % colors.length];
    }

    function getDonutColor(index) {
        var colors = [
            "#4CAF50", "#2196F3", "#FF9800", "#9C27B0",
            "#00BCD4", "#FF5722", "#607D8B", "#E91E63",
            "#795548", "#FFC107"
        ];
        return colors[index % colors.length];
    }

    /// Build segments array for DonutChart from usageData
    function buildDonutSegments() {
        if (!usageData || usageData.length === 0) return [];
        var total = 0;
        for (var i = 0; i < usageData.length; i++) {
            total += usageData[i].total_ms;
        }
        if (total <= 0) return [];

        var maxSegments = 7;
        var segments = [];
        var otherTotal = 0;
        for (i = 0; i < usageData.length; i++) {
            if (i < maxSegments) {
                var pct = Math.round((usageData[i].total_ms / total) * 100);
                segments.push({
                    label: usageData[i].app_id || usageData[i].app_name,
                    value: usageData[i].total_ms,
                    color: getDonutColor(i),
                    pct: pct + "%"
                });
            } else {
                otherTotal += usageData[i].total_ms;
            }
        }
        if (otherTotal > 0) {
            var otherPct = Math.round((otherTotal / total) * 100);
            segments.push({
                label: qsTr("Other"),
                value: otherTotal,
                color: getDonutColor(maxSegments),
                pct: otherPct + "%"
            });
        }
        return segments;
    }

    /// Format total ms as human-readable string
    function getTotalDisplay() {
        if (!usageData || usageData.length === 0) return "0m";
        var total = 0;
        for (var i = 0; i < usageData.length; i++) {
            total += usageData[i].total_ms;
        }
        return AppUsage.formatDuration(total);
    }

    /// Return top 10 sessions sorted by duration descending, merging same titles
    function getTopSessions() {
        if (!sessionData || sessionData.length === 0) return [];

        // Merge sessions with the same title (app_name = window title)
        var merged = {};
        for (var i = 0; i < sessionData.length; i++) {
            var s = sessionData[i];
            var key = s.app_name || s.app_id || "unknown";
            if (merged[key]) {
                merged[key].duration_ms += s.duration_ms;
            } else {
                merged[key] = {
                    app_name: key,
                    app_id: s.app_id,
                    duration_ms: s.duration_ms
                };
            }
            merged[key].duration_display = AppUsage.formatDuration(merged[key].duration_ms);
        }

        // Convert to array and sort by duration descending
        var result = [];
        for (var key in merged) {
            result.push(merged[key]);
        }
        result.sort(function(a, b) { return b.duration_ms - a.duration_ms; });
        return result.slice(0, 10);
    }

    function formatTime(isoString) {
        if (!isoString) return "--:--";
        // ISO format: "2026-06-14T09:30:00"
        var parts = isoString.split("T");
        if (parts.length < 2) return isoString;
        return parts[1].substring(0, 5);
    }
}
