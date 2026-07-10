pragma Singleton

import qs.config
import qs.utils
import Celestia
import Celestia.Internal
import Celestia.Services
import Quickshell
import QtQuick

Singleton {
    id: root

    // ── Properties ──

    readonly property bool ready: UsageTracker.ready

    /// Currently tracked app ID
    readonly property string currentAppId: UsageTracker.currentAppId
    /// Currently tracked app name
    readonly property string currentAppName: UsageTracker.currentAppName

    // ── Lifecycle ──

    Component.onCompleted: {
        // Initialize UsageTracker with persistent database
        UsageTracker.path = Paths.data + "/app_usage.db";
        UsageTracker.start();
        console.log("AppUsage: Initialized with DB at", UsageTracker.path);
    }

    // ── Focus Tracking ──

    // Track app focus changes via Niri IPC
    Connections {
        target: Niri

        function onFocusedWindowClassChanged() {
            if (!UsageTracker.ready) return;

            var appId = Niri.focusedWindowClass;
            var appName = Niri.focusedWindowTitle;

            if (!appId || appId === "Desktop" || appId === "") {
                UsageTracker.reportFocusOut();
                return;
            }

            UsageTracker.reportFocusIn(appId, appName || appId);
        }
    }

    // Handle focus loss (no window focused, e.g. desktop click)
    Connections {
        target: NiriIpc

        function onFocusedWindowChanged() {
            if (!UsageTracker.ready) return;

            if (!Niri.focusedWindowId || Niri.focusedWindowId === "") {
                UsageTracker.reportFocusOut();
            }
        }
    }

    // ── Query Wrappers (for Dashboard) ──

    function getTodayUsage() {
        return UsageTracker.getTodayUsage();
    }

    function getWeekUsage() {
        return UsageTracker.getWeekUsage();
    }

    function getMonthUsage() {
        return UsageTracker.getMonthUsage();
    }

    function getTotalUsage() {
        return UsageTracker.getTotalUsage();
    }

    function getTopApps(period, limit) {
        return UsageTracker.getTopApps(period, limit || 20);
    }

    function getSessionHistory(appId, limit) {
        return UsageTracker.getSessionHistory(appId || "", limit || 50);
    }

    function getPeriodSessions(period, limit) {
        return UsageTracker.getPeriodSessions(period || "today", limit || 500);
    }

    // Map common app_ids to Material Icons
    function getIconForApp(appId) {
        if (!appId) return "widgets";

        var lower = appId.toLowerCase();
        if (lower.indexOf("ghostty") >= 0 || lower.indexOf("terminal") >= 0 || lower.indexOf("kitty") >= 0 || lower.indexOf("alacritty") >= 0) return "terminal";
        if (lower.indexOf("firefox") >= 0 || lower.indexOf("chromium") >= 0 || lower.indexOf("chrome") >= 0 || lower.indexOf("brave") >= 0 || lower.indexOf("edge") >= 0) return "language";
        if (lower.indexOf("code") >= 0 || lower.indexOf("cursor") >= 0 || lower.indexOf("neovide") >= 0) return "code";
        if (lower.indexOf("spotify") >= 0 || lower.indexOf("vlc") >= 0 || lower.indexOf("mpv") >= 0) return "music_note";
        if (lower.indexOf("nautilus") >= 0 || lower.indexOf("dolphin") >= 0 || lower.indexOf("nemo") >= 0 || lower.indexOf("thunar") >= 0) return "folder";
        if (lower.indexOf("discord") >= 0 || lower.indexOf("telegram") >= 0 || lower.indexOf("slack") >= 0) return "chat";
        if (lower.indexOf("gimp") >= 0 || lower.indexOf("inkscape") >= 0 || lower.indexOf("krita") >= 0) return "palette";
        if (lower.indexOf("libreoffice") >= 0 || lower.indexOf("onlyoffice") >= 0) return "description";
        if (lower.indexOf("obsidian") >= 0 || lower.indexOf("notion") >= 0) return "note";
        if (lower.indexOf("steam") >= 0 || lower.indexOf("lutris") >= 0) return "sports_esports";
        if (lower.indexOf("thunderbird") >= 0 || lower.indexOf("geary") >= 0) return "mail";
        if (lower.indexOf("evince") >= 0 || lower.indexOf("zathura") >= 0) return "picture_as_pdf";

        return "widgets";
    }

    function formatDuration(ms) {
        if (ms < 1000) return "0s";
        var totalSecs = Math.floor(ms / 1000);
        var hours = Math.floor(totalSecs / 3600);
        var mins = Math.floor((totalSecs % 3600) / 60);
        var secs = totalSecs % 60;

        if (hours > 0) {
            return mins > 0 ? hours + "h " + mins + "m" : hours + "h";
        }
        if (mins > 0) {
            return secs > 0 ? mins + "m " + secs + "s" : mins + "m";
        }
        return secs + "s";
    }
}
