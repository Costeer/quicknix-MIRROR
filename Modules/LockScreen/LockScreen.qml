import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Widgets

Loader {
    id: root
    active: false

    Component.onCompleted: {
        PanelService.lockScreen = root;
        if (Quickshell.env("QUICKNIX_TEST_LOCKSCREEN") === "1") {
            Qt.callLater(function () {
                root.active = true;
            });
        }
    }
    Component.onDestruction: if (PanelService.lockScreen === root)
        PanelService.lockScreen = null

    onActiveChanged: {
        const hooks = Settings.data.hooks;
        if (hooks && hooks.enabled) {
            const cmd = active ? hooks.screenLock : hooks.screenUnlock;
            if (cmd && cmd.length > 0)
                Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    Timer {
        id: unloadTimer
        interval: 200
        repeat: false
        onTriggered: root.active = false
    }

    sourceComponent: Item {
        id: container

        property date now: new Date()
        property bool releasing: false

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: container.now = new Date()
        }

        LockContext {
            id: lockContext
            onUnlocked: {
                container.releasing = true;
                unlockTransitionTimer.restart();
            }
        }

        Timer {
            id: unlockTransitionTimer
            interval: 520
            repeat: false
            onTriggered: {
                sessionLock.locked = false;
                unloadTimer.restart();
                container.releasing = false;
            }
        }

        WlSessionLock {
            id: sessionLock
            locked: root.active

            WlSessionLockSurface {
                id: surface
                color: Qt.alpha(Color.mSurface, container.releasing ? 0 : 1)

                Rectangle {
                    anchors.fill: parent
                    color: Color.mSurface
                    opacity: container.releasing ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 520
                            easing.type: Easing.OutQuart
                        }
                    }

                    Item {
                        id: lockScene
                        anchors.fill: parent
                        opacity: container.releasing ? 0 : 1
                        scale: container.releasing ? 1.035 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 700
                                easing.type: Easing.OutQuart
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 520
                                easing.type: Easing.OutQuart
                            }
                        }

                    Rectangle {
                        id: ambientWash
                        anchors.fill: parent
                        opacity: Settings.data.general.lockScreenTint ? 0.22 : 0.14
                        gradient: Gradient {
                            GradientStop {
                                position: 0.00
                                color: Qt.alpha(Color.mPrimary, 0.42)
                            }
                            GradientStop {
                                position: 0.46
                                color: Qt.alpha(Color.mSurface, 0.86)
                            }
                            GradientStop {
                                position: 1.00
                                color: Qt.alpha(Color.mSecondary, 0.30)
                            }
                        }
                    }

                    Rectangle {
                        width: Math.max(parent.width, parent.height) * 0.58
                        height: width
                        radius: width / 2
                        x: parent.width * 0.62
                        y: -height * 0.30
                        color: Color.mPrimary
                        opacity: 0.14
                    }

                    Rectangle {
                        width: Math.max(parent.width, parent.height) * 0.46
                        height: width
                        radius: width / 2
                        x: -width * 0.20
                        y: parent.height * 0.58
                        color: Color.mTertiary
                        opacity: 0.10
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(28, Math.min(parent.width, parent.height) * 0.055)
                        spacing: Math.max(28, parent.width * 0.04)

                        ColumnLayout {
                            visible: surface.width >= 760
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.maximumWidth: parent.width > 900 ? parent.width * 0.54 : parent.width
                            spacing: Style.marginL

                            Item {
                                Layout.fillHeight: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Qt.formatTime(container.now, "HH:mm")
                                color: Color.mOnSurface
                                font.family: Settings.data.ui.fontDefault
                                font.pixelSize: (Settings.data.general.compactLockScreen ? 76 : 118) * Style.uiScaleRatio
                                font.weight: Font.Bold
                                lineHeight: 0.86
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Qt.formatDate(container.now, "dddd, MMMM d")
                                color: Color.mOnSurfaceVariant
                                font.family: Settings.data.ui.fontDefault
                                font.pixelSize: 22 * Style.uiScaleRatio
                                font.weight: Font.Medium
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }

                        Rectangle {
                            id: unlockCard
                            Layout.preferredWidth: Math.min(430 * Style.uiScaleRatio, parent.width * 0.92)
                            Layout.alignment: Qt.AlignVCenter | (surface.width < 760 ? Qt.AlignHCenter : Qt.AlignRight)
                            Layout.fillHeight: false
                            implicitHeight: cardContent.implicitHeight + Style.marginXL * 2
                            radius: Style.radiusL * 1.4
                            color: Qt.alpha(Color.mSurfaceVariant, 0.92)

                            ColumnLayout {
                                id: cardContent
                                anchors.fill: parent
                                anchors.margins: Style.marginXL
                                spacing: Style.marginL

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginM

                                    Rectangle {
                                        Layout.preferredWidth: 48 * Style.uiScaleRatio
                                        Layout.preferredHeight: 48 * Style.uiScaleRatio
                                        radius: Style.iRadiusL
                                        color: Qt.alpha(Color.mSecondary, 0.18)
                                        NIcon {
                                            anchors.centerIn: parent
                                            icon: "lock"
                                            pointSize: Style.fontSizeXXXL
                                            color: Color.mSecondary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Style.marginXXS
                                        Text {
                                            Layout.fillWidth: true
                                            text: "Welcome back"
                                            color: Color.mOnSurface
                                            font.family: Settings.data.ui.fontDefault
                                            font.pixelSize: 24 * Style.uiScaleRatio
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: lockContext.username.length > 0 ? lockContext.username : "Enter your password"
                                            color: Color.mOnSurfaceVariant
                                            font.family: Settings.data.ui.fontDefault
                                            font.pixelSize: Style.fontSizeL * Style.uiScaleRatio
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 54 * Style.uiScaleRatio
                                    radius: height / 2
                                    color: Color.mSurface

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Style.marginL
                                        anchors.rightMargin: Style.marginM
                                        spacing: Style.marginM

                                        TextField {
                                            id: passwordInput
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: lockContext.password
                                            echoMode: TextInput.Password
                                            placeholderText: "Password"
                                            placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.62)
                                            color: Color.mOnSurface
                                            enabled: !lockContext.busy
                                            focus: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            selectByMouse: false
                                            background: null
                                            font.family: Settings.data.ui.fontDefault
                                            font.pixelSize: Style.fontSizeXL * Style.uiScaleRatio
                                            onTextChanged: lockContext.password = text
                                            onAccepted: lockContext.tryUnlock()
                                            Component.onCompleted: forceActiveFocus()
                                        }
                                    }
                                }


                                Text {
                                    Layout.fillWidth: true
                                    visible: lockContext.message.length > 0
                                    text: lockContext.message
                                    color: lockContext.error ? Color.mError : Color.mOnSurfaceVariant
                                    font.family: Settings.data.ui.fontDefault
                                    font.pixelSize: Style.fontSizeM * Style.uiScaleRatio
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
