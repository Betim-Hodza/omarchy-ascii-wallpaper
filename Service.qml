pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// ascii-wallpaper service: wires the "Style > ASCII Wallpaper" menu entry when
// the plugin loads, unwires it when the plugin is disabled or removed.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/betim.ascii-wallpaper"
  readonly property string script: pluginDir + "/ascii-wallpaper.sh"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
  readonly property string cleanupHelper: stateHome + "/omarchy/ascii-wallpaper/cleanup"

  Timer {
    id: wireWatchdog
    interval: 15000
    repeat: false
    onTriggered: if (wireProc.running) wireProc.running = false
  }

  Process {
    id: wireProc
    command: ["timeout", "15", root.script, "--wire-menu"]
    onRunningChanged: if (running) wireWatchdog.restart(); else wireWatchdog.stop()
  }

  Component.onCompleted: wireProc.running = true

  // The helper is a copy in the state dir, so it still exists after the plugin
  // folder is removed. Guard against symlinks before executing.
  Component.onDestruction: Quickshell.execDetached([
    "bash", "-c",
    'p="$1"; [[ ! -L "$p" && -f "$p" && -x "$p" ]] && exec "$p" --cleanup-after-unload',
    "bash", root.cleanupHelper
  ])
}
