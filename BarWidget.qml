import QtQuick
import qs.Ui

BarWidget {
    id: root
    moduleName: "nkarl.fcitx-active-input-lang"

    readonly property var inputService: bar && bar.shell
        ? bar.shell.serviceFor("nkarl.fcitx-active-input-lang")
        : null
    readonly property string inputMethod: inputService ? inputService.inputMethod : ""
    property var queue: []

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false
    readonly property var activeEntry: queue.length > 0 ? queue[0] : null
    readonly property string label: activeEntry ? activeEntry.label : "???"

    function copyQueue(source) {
        return JSON.parse(JSON.stringify(source || []))
    }

    function queuesEqual(left, right) {
        if (left.length !== right.length) return false
        for (let i = 0; i < left.length; i++) {
            if (left[i].id !== right[i].id || left[i].label !== right[i].label)
                return false
        }
        return true
    }

    function methodInfo(inputMethodId) {
        const methods = inputService && inputService.availableMethods instanceof Array
            ? inputService.availableMethods : []
        for (let i = 0; i < methods.length; i++) {
            if (methods[i].id === inputMethodId) return methods[i]
        }
        return null
    }

    function suggestedLabel(inputMethodId) {
        const info = methodInfo(inputMethodId)
        const languageCode = info ? String(info.languageCode || "").trim() : ""
        if (languageCode !== "")
            return languageCode.substring(0, 3).toUpperCase()
        const parts = String(inputMethodId || "")
            .replace(/^keyboard-/, "")
            .split(/[^A-Za-z0-9]+/)
            .filter(function(part) { return part !== "" })
        const source = parts.length > 0 ? parts[parts.length - 1] : "???"
        return source.substring(0, 3).toUpperCase()
    }

    function normalizedQueue(value) {
        if (!(value instanceof Array)) return []
        const result = []
        const seen = ({})
        for (let i = 0; i < value.length; i++) {
            const entry = value[i] || ({})
            const methodId = String(entry.id || "").trim()
            if (methodId === "" || seen[methodId]) continue
            seen[methodId] = true
            let displayLabel = String(entry.label || "").trim().toUpperCase().substring(0, 3)
            if (displayLabel === "") displayLabel = suggestedLabel(methodId)
            result.push({ id: methodId, label: displayLabel })
        }
        return result
    }

    function defaultQueue() {
        const available = inputService && inputService.availableMethods instanceof Array
            ? inputService.availableMethods : []
        const methods = available.slice()
        const currentIndex = methods.findIndex(function(method) { return method.id === inputMethod })
        if (currentIndex > 0) {
            const current = methods.splice(currentIndex, 1)[0]
            methods.unshift(current)
        }
        return methods.map(function(method) {
            return { id: method.id, label: suggestedLabel(method.id) }
        })
    }

    function loadQueue() {
        const stored = normalizedQueue(setting("inputMethods", []))
        let next = copyQueue(stored)
        if (next.length === 0) next = defaultQueue()
        if (next.length === 0) return

        // Fcitx is authoritative when it changes outside this widget. Restore
        // the invariant that rank one is active, except while Fcitx is still
        // confirming a promotion requested by this widget.
        const target = inputService ? inputService.activationTarget : ""
        if (target === "") {
            const currentIndex = next.findIndex(function(entry) { return entry.id === inputMethod })
            if (currentIndex > 0) {
                const current = next.splice(currentIndex, 1)[0]
                next.unshift(current)
            } else if (currentIndex < 0 && inputMethod !== "") {
                next.unshift({ id: inputMethod, label: suggestedLabel(inputMethod) })
            }
        }

        queue = next
        if (!queuesEqual(stored, next)) persistQueue(next)
        injectPanel()
    }

    function persistQueue(nextQueue) {
        const normalized = normalizedQueue(nextQueue)
        if (normalized.length === 0) return
        queue = normalized
        if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return
        const nextSettings = JSON.parse(JSON.stringify(settings || ({})))
        nextSettings.inputMethods = normalized
        bar.shell.updateEntryInline(moduleName, nextSettings)
    }

    function promote(index) {
        if (index <= 0 || index >= queue.length) return
        const next = copyQueue(queue)
        const promoted = next[index]
        next[index] = next[index - 1]
        next[index - 1] = promoted
        if (index === 1 && inputService) inputService.activate(promoted.id)
        persistQueue(next)
    }

    function promoteSecond() {
        if (queue.length > 1) promote(1)
    }

    function addMethod(method) {
        const id = typeof method === "string" ? method : String(method && method.id || "")
        if (id === "" || queue.some(function(entry) { return entry.id === id })) return
        const next = copyQueue(queue)
        next.push({ id: id, label: suggestedLabel(id) })
        persistQueue(next)
    }

    function removeMethod(index) {
        if (index <= 0 || index >= queue.length || queue.length <= 1) return
        const next = copyQueue(queue)
        next.splice(index, 1)
        persistQueue(next)
    }

    function setLabel(inputMethodId, value) {
        const index = queue.findIndex(function(entry) { return entry.id === inputMethodId })
        if (index < 0 || index >= queue.length) return
        const next = copyQueue(queue)
        const labelValue = String(value || "").trim().toUpperCase().substring(0, 3)
        next[index].label = labelValue !== "" ? labelValue : suggestedLabel(next[index].id)
        persistQueue(next)
    }

    function open() { if (panelLoader.item) panelLoader.item.open() }
    function close() { if (panelLoader.item) panelLoader.item.close() }
    function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.inputService = root.inputService
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: {
        injectPanel()
        loadQueue()
    }
    onSettingsChanged: loadQueue()
    onInputServiceChanged: {
        injectPanel()
        loadQueue()
    }
    onInputMethodChanged: if (inputMethod !== "") loadQueue()

    Connections {
        target: root.inputService
        function onAvailableMethodsChanged() { root.loadQueue() }
        function onActivationTargetChanged() { root.loadQueue() }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.label
        tooltipText: (root.inputMethod || "Unavailable")
            //+ "\nLeft click: promote next · Right click: configure"

        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.promoteSecond()
            else if (buttonCode === Qt.RightButton) root.togglePanel()
        }
    }
}
