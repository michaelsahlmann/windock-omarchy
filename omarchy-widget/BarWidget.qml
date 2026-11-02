import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "michael.windock"

  property bool running: false
  property string serverIp: ""
  property string pin: ""

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function copyPin() {
    if (root.pin === "") return
    if (root.bar) root.bar.run("wl-copy " + root.pin)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Línea 1: "on"/"off" del servicio. Línea 2: IP de esta PC. Línea 3: PIN.
  Process {
    id: statusProc
    command: ["bash", "-c",
      "systemctl --user is-active windock.service >/dev/null 2>&1 && echo on || echo off; " +
      "ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == \"src\") print $(i + 1)}'; " +
      "windock status 2>/dev/null | sed -n 's/^[[:space:]]*PIN:[[:space:]]*//p'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n")
        root.running = lines[0] === "on"
        root.serverIp = lines[1] || ""
        root.pin = lines[2] || ""
      }
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.running ? "󰄢" : "󰄣"
    // Invertido a propósito: apagado = rojo (urgent), encendido = gris normal.
    active: !root.running
    slotSize: Style.bar.statusSlot
    tooltipText: !root.running
      ? "WinDock apagado · clic para prender · http://" + root.serverIp + ":8620"
      : "WinDock activo en http://" + root.serverIp + ":8620 · PIN " + root.pin + " · clic para apagar · clic derecho: copiar PIN"
    onTooltipHoveredChanged: if (tooltipHovered) root.refresh()
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton && root.running) {
        root.copyPin()
      } else {
        root.bar.run(root.running
          ? "systemctl --user stop windock.service"
          : "systemctl --user start windock.service")
      }
      refreshSoon.restart()
    }
  }

  Timer {
    id: refreshSoon
    interval: 800
    onTriggered: root.refresh()
  }
}
