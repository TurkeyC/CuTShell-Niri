pragma Singleton

import qs.config
import Celestia
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/Celestia/Shell`
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/Celestia/Shell`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/Celestia/Shell`
    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/Celestia/Shell`

    readonly property string imagecache: `${cache}/imagecache`
    readonly property string notificationsData: `${data}/notifications.json`
    readonly property string wallsdir: Quickshell.env("CELESTIA_WALLPAPERS_DIR") || absolutePath(Config.paths.wallpaperDir)
    readonly property string libdir: Quickshell.env("CELESTIA_LIB_DIR") || "/usr/lib/Celestia/Shell"

    function toLocalFile(path: url): string {
        path = Qt.resolvedUrl(path);
        return path.toString() ? CUtils.toLocalFile(path) : "";
    }

    function absolutePath(path: string): string {
        return toLocalFile(path.replace("~", home));
    }

    function shortenHome(path: string): string {
        return path.replace(home, "~");
    }
}
