pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var _frequencies: ({})

    readonly property string _filePath: `${Paths.state}/app-frequency.json`

    // Ensure state directory exists on startup
    Process {
        command: ["mkdir", "-p", Paths.state]
        running: true
        onExited: frequencyFile.reload()
    }

    FileView {
        id: frequencyFile

        path: root._filePath
        watchChanges: true

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed && typeof parsed === "object")
                    root._frequencies = parsed;
            } catch (e) {
                console.error("FrequencyTracker: Failed to parse:", e.message);
            }
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.error("FrequencyTracker: Failed to read:", err);
        }
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            try {
                frequencyFile.setText(JSON.stringify(root._frequencies, null, 2));
            } catch (e) {
                console.error("FrequencyTracker: Failed to save:", e.message);
            }
        }
    }

    function get(appId: string): int {
        return root._frequencies[appId] || 0;
    }

    function increment(appId: string): void {
        root._frequencies[appId] = (root._frequencies[appId] || 0) + 1;
        saveTimer.restart();
    }
}
