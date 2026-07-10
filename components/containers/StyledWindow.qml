import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property string name

    WlrLayershell.namespace: `Celestia-${name}`
    color: "transparent"
}
