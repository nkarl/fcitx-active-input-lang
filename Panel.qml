import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "nkarl.fcitx-active-input-lang"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var inputService: null
    property int editingIndex: -1
    property bool addChooserOpen: false
    readonly property var barIdentity: hostWidget || root
    readonly property color contentForeground: bar ? bar.foreground : Color.foreground
    readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property var queue: hostWidget ? hostWidget.queue : []
    readonly property var availableMethods: inputService ? inputService.availableMethods : []
    readonly property var unselectedMethods: {
        const selected = ({})
        for (let i = 0; i < queue.length; i++) selected[queue[i].id] = true
        return availableMethods.filter(function(method) { return !selected[method.id] })
    }

    function methodInfo(inputMethodId) {
        for (let i = 0; i < availableMethods.length; i++) {
            if (availableMethods[i].id === inputMethodId) return availableMethods[i]
        }
        return null
    }

    function prettyName(inputMethodId) {
        const info = methodInfo(inputMethodId)
        if (info && info.name) return info.name
        return String(inputMethodId || "")
            .split(/[-_]+/)
            .map(function(part) {
                return part.length > 0 ? part.charAt(0).toUpperCase() + part.slice(1) : ""
            })
            .join(" ")
    }

    function open() {
        if (inputService) inputService.refreshMethods()
        editingIndex = -1
        addChooserOpen = false
        controller.show()
    }
    function close() { controller.hide() }
    function toggle() { opened ? close() : open() }

    function switchPanel(direction) {
        if (bar && typeof bar.switchPanelFrom === "function")
            return bar.switchPanelFrom(barIdentity, direction)
        return false
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(400))
        contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: content
                    width: flick.width
                    spacing: Style.space(12)

                    Row {
                        width: parent.width
                        spacing: Style.space(12)

                        Column {
                            width: parent.width - activeBadge.width - parent.spacing
                            spacing: Style.space(2)

                            Text {
                                text: "Input Methods"
                                color: root.contentForeground
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }

                            Text {
                                //text: "Push a method upward until it becomes active"
                                color: Util.alpha(root.contentForeground, 0.64)
                                font.family: root.contentFontFamily
                                font.pixelSize: Style.font.caption
                            }
                        }

                        Button {
                            id: activeBadge
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.queue.length > 0 ? root.queue[0].label : "???"
                            selected: true
                        }
                    }

                    PanelSeparator { width: parent.width }

                    Column {
                        width: parent.width
                        spacing: Style.space(6)

                        Repeater {
                            model: root.queue

                            delegate: BorderSurface {
                                id: queueRow
                                required property var modelData
                                required property int index
                                readonly property var panelOwner: root
                                width: parent.width
                                implicitHeight: Style.space(56)
                                radius: Style.cornerRadius
                                color: index === 0
                                    ? Style.selectedFillFor(root.contentForeground, Color.accent)
                                    : "transparent"
                                borderSpec: Border.controlSpec(index === 0 ? "selected" : "normal",
                                    root.contentForeground, Color.accent)

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Style.space(7)
                                    spacing: Style.space(8)

                                    Item {
                                        id: editableArea
                                        width: parent.width - controls.width - parent.spacing
                                        height: parent.height

                                        Row {
                                            anchors.fill: parent
                                            spacing: Style.space(8)

                                            Item {
                                                width: Style.space(58)
                                                height: parent.height

                                                BorderSurface {
                                                    anchors.fill: parent
                                                    visible: root.editingIndex !== queueRow.index
                                                    radius: Style.cornerRadius
                                                    color: Util.alpha(root.contentForeground, 0.08)
                                                    borderSpec: Border.controlSpec("normal",
                                                        root.contentForeground, Color.accent)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: queueRow.modelData.label
                                                        color: root.contentForeground
                                                        font.family: root.contentFontFamily
                                                        font.pixelSize: Style.font.body
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.IBeamCursor
                                                        acceptedButtons: Qt.LeftButton
                                                        preventStealing: true
                                                        onPressed: function(mouse) {
                                                            // Keep this gesture inside the label badge. In
                                                            // particular, do not let the row's arrow button
                                                            // or the panel's underlying bar button see it.
                                                            mouse.accepted = true
                                                        }
                                                        onClicked: function(mouse) {
                                                            mouse.accepted = true
                                                            queueRow.panelOwner.editingIndex = queueRow.index
                                                            Qt.callLater(function() {
                                                                labelEditor.forceActiveFocus()
                                                                labelEditor.selectAll()
                                                            })
                                                        }
                                                    }
                                                }

                                                TextField {
                                                    id: labelEditor
                                                    anchors.fill: parent
                                                    visible: root.editingIndex === queueRow.index
                                                    text: queueRow.modelData.label
                                                    maximumLength: 3
                                                    horizontalAlignment: TextInput.AlignHCenter
                                                    font.capitalization: Font.AllUppercase

                                                    function commit() {
                                                        if (queueRow.panelOwner.hostWidget)
                                                            queueRow.panelOwner.hostWidget.setLabel(
                                                                queueRow.modelData.id, text)
                                                        queueRow.panelOwner.editingIndex = -1
                                                    }

                                                    onAccepted: commit()
                                                    onActiveFocusChanged: {
                                                        if (!activeFocus && visible) commit()
                                                    }
                                                }
                                            }

                                            Column {
                                                width: parent.width - Style.space(58) - parent.spacing
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Style.space(2)

                                                Text {
                                                    width: parent.width
                                                    text: root.prettyName(queueRow.modelData.id)
                                                    color: root.contentForeground
                                                    font.family: root.contentFontFamily
                                                    font.pixelSize: Style.font.body
                                                    font.bold: queueRow.index === 0
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: queueRow.modelData.id
                                                    color: Util.alpha(root.contentForeground, 0.58)
                                                    font.family: root.contentFontFamily
                                                    font.pixelSize: Style.font.caption
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                    }

                                    Row {
                                        id: controls
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(3)

                                        Text {
                                            visible: queueRow.index === 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "ACTIVE"
                                            color: Color.accent
                                            font.family: root.contentFontFamily
                                            font.pixelSize: Style.font.caption
                                            font.bold: true
                                        }

                                        Button {
                                            visible: queueRow.index > 0
                                            text: "↑"
                                            tooltipText: "Push up one rank"
                                            onClicked: {
                                                queueRow.panelOwner.editingIndex = -1
                                                if (queueRow.panelOwner.hostWidget)
                                                    queueRow.panelOwner.hostWidget.promote(queueRow.index)
                                            }
                                        }

                                        Button {
                                            visible: queueRow.index > 0
                                            text: "−"
                                            tooltipText: "Remove from switch list"
                                            onClicked: {
                                                queueRow.panelOwner.editingIndex = -1
                                                if (queueRow.panelOwner.hostWidget)
                                                    queueRow.panelOwner.hostWidget.removeMethod(queueRow.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PanelSeparator { width: parent.width }

                    Button {
                        width: parent.width
                        bordered: true
                        leftAlign: true
                        text: root.addChooserOpen ? "−   Close input method list" : "+   Add input method"
                        onClicked: {
                            root.addChooserOpen = !root.addChooserOpen
                            if (root.addChooserOpen && root.inputService)
                                root.inputService.refreshMethods()
                        }
                    }

                    Column {
                        visible: root.addChooserOpen
                        width: parent.width
                        spacing: Style.space(6)

                        PanelSectionHeader {
                            width: parent.width
                            text: "AVAILABLE IN ACTIVE FCITX GROUP"
                        }

                        Text {
                            visible: root.unselectedMethods.length === 0
                            width: parent.width
                            text: root.availableMethods.length === 0
                                ? "No input methods were found in the active Fcitx group."
                                : "All input methods in the active Fcitx group have been added."
                            color: Util.alpha(root.contentForeground, 0.64)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: root.unselectedMethods

                            delegate: Item {
                                required property var modelData
                                readonly property var panelOwner: root
                                width: parent.width
                                implicitHeight: addButton.implicitHeight

                                Button {
                                    id: addButton
                                    anchors.fill: parent
                                    leftAlign: true
                                    bordered: true
                                    text: "+   " + (parent.modelData.name
                                        || parent.panelOwner.prettyName(parent.modelData.id))
                                    tooltipText: parent.modelData.id
                                    onClicked: {
                                        if (parent.panelOwner.hostWidget)
                                            parent.panelOwner.hostWidget.addMethod(parent.modelData)
                                        parent.panelOwner.addChooserOpen = false
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: "To show more choices here, add them to the active group in "
                                + "Fcitx 5 Configuration, then close and reopen this list."
                            color: Util.alpha(root.contentForeground, 0.64)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
