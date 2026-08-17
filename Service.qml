import QtQuick
import Quickshell.Io

Item {
    id: service

    property string inputMethod: ""
    property var availableMethods: []
    property string pendingActivation: ""
    property string activationTarget: ""
    readonly property string monitorPath: Qt.resolvedUrl("fcitx-state-monitor").toString().replace(/^file:\/\//, "")

    function refreshMethods() {
        if (!listProcess.running)
            listProcess.running = true
    }

    function activate(inputMethodId) {
        const id = String(inputMethodId || "")
        if (id === "") return
        activationTarget = id
        activationTimeout.restart()
        if (setProcess.running) {
            pendingActivation = id
            return
        }
        setProcess.command = [service.monitorPath, "--set", id]
        setProcess.running = true
    }

    Process {
        command: [service.monitorPath]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                const state = line.trim()
                if (state === "") return
                service.inputMethod = state
                if (state === service.activationTarget) {
                    service.activationTarget = ""
                    activationTimeout.stop()
                }
            }
        }
    }

    Timer {
        id: activationTimeout
        interval: 2000
        onTriggered: service.activationTarget = ""
    }

    Process {
        id: listProcess
        command: [service.monitorPath, "--list"]

        stdout: StdioCollector {
            id: listOutput
            waitForEnd: true
        }

        onExited: {
            const seen = ({})
            const methods = []
            const lines = String(listOutput.text || "").split("\n")
            for (let i = 0; i < lines.length; i++) {
                const fields = lines[i].split("\t")
                if (fields.length < 4) continue
                const order = Number(fields[0])
                const id = fields[1].trim()
                if (id !== "" && !seen[id]) {
                    seen[id] = true
                    methods.push({
                        order: isNaN(order) ? methods.length : order,
                        id: id,
                        name: fields[2].trim() || id,
                        languageCode: fields[3].trim()
                    })
                }
            }
            methods.sort(function(a, b) { return a.order - b.order })
            service.availableMethods = methods
        }
    }

    Process {
        id: setProcess
        onExited: {
            if (service.pendingActivation === "") return
            const next = service.pendingActivation
            service.pendingActivation = ""
            service.activate(next)
        }
    }

    Component.onCompleted: refreshMethods()
}
