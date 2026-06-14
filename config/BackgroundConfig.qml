import Quickshell.Io

JsonObject {
    property bool enabled: true
    property bool wallpaperEnabled: true
    property Backdrop backdrop: Backdrop {}
    property DesktopClock desktopClock: DesktopClock {}
    property Visualiser visualiser: Visualiser {}

    component Backdrop: JsonObject {
        property bool enabled: true
        property bool tintEnabled: false
        property real tintOpacity: 0.15
        property bool blurEnabled: true
        property real blur: 0.8
    }

    component DesktopClock: JsonObject {
        property bool enabled: false
        property real scale: 1.0
        property string position: "bottom-right"
        property bool invertColors: false
        property DesktopClockBackground background: DesktopClockBackground {}
        property DesktopClockShadow shadow: DesktopClockShadow {}
    }

    component DesktopClockBackground: JsonObject {
        property bool enabled: false
        property real opacity: 0.7
        property bool blur: true
    }

    component DesktopClockShadow: JsonObject {
        property bool enabled: true
        property real opacity: 0.7
        property real blur: 0.4
    }

    component Visualiser: JsonObject {
        property bool enabled: false
        property bool autoHide: true
        property bool blur: false
        property real rounding: 1
        property real spacing: 1
    }
}
