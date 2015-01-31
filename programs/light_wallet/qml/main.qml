import QtQuick 2.4
import QtQuick.Window 2.2
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0

import "utils.js" as Utils
import org.BitShares.Types 1.0

import Material 0.1

Window {
   id: window
   visible: true

   property alias pageStack: __pageStack
   property alias lockAction: __lockAction
   property alias payAction: __payAction

   Component.onCompleted: {
      if( wallet.walletExists )
         wallet.openWallet()
      if( !( wallet.accountNames.length && wallet.accounts[wallet.accountNames[0]].isRegistered ) )
         onboardLoader.sourceComponent = onboardingUi
      else
         pageStack.push({item: assetsUi, properties: {accountName: wallet.accountNames[0]}})

      window.connectToServer()
   }

   function showError(error, buttonName, buttonCallback) {
      snack.text = error
      if( buttonName && buttonCallback ) {
         snack.buttonText = buttonName
         snack.onClick.connect(buttonCallback)
         snack.onDissapear.connect(function() {
            snack.onClick.disconnect(buttonCallback)
         })
      } else
         snack.buttonText = ""
      snack.open()
   }
   function deviceType() {
      switch(Device.type) {
      case Device.phone:
      case Device.phablet:
         return "phone"
      case Device.tablet:
         return "tablet"
      case Device.desktop:
      default:
         return "computer"
      }
   }
   function connectToServer() {
      if( !wallet.connected )
         wallet.connectToServer("nathanhourt.com", 5657, "DVS8GV6nP15gBZQbuEGamH95gYR5EioxkUbEYjpDHMjPEeRWsvR63")
   }
   function openTransferPage() {
      //TODO: Add arguments which prefill items in transfer page
      if( wallet.accounts[wallet.accountNames[0]].availableAssets.length )
         window.pageStack.push({item: transferUi, properties: {accountName: wallet.accountNames[0]}})
      else
         showError(qsTr("You don't have any assets, so you cannot make a transfer."), qsTr("Refresh Balances"),
                   wallet.syncAllBalances)
   }


   AppTheme {
      id: theme
      primaryColor: "#2196F3"
      backgroundColor: "#BBDEFB"
      accentColor: "#80D8FF"
   }
   Action {
      id: __lockAction
      name: qsTr("Lock Wallet")
      iconName: "action/lock"
      onTriggered: wallet.lockWallet()
   }
   Action {
      id: __payAction
      name: qsTr("Send Payment")
      iconName: "action/payment"
      onTriggered: openTransferPage()
   }
   QtObject {
      id: visuals
      property real margins: units.dp(16)
   }
   Timer {
      id: refreshPoller
      running: wallet.unlocked
      triggeredOnStart: true
      interval: 10000
      repeat: true
      onTriggered: {
         if( !wallet.connected )
            connectToServer()
         else
            wallet.sync()
      }
   }
   LightWallet {
      id: wallet

      function runWhenConnected(fn) {
         Utils.connectOnce(wallet.onConnectedChanged, fn, function() { return connected })
      }

      onErrorConnecting: {
         showError(error)
      }
      onNotification: showError(message)
   }

   WelcomeLayout {
      id: lockScreen
      width: window.width
      height: window.height
      backgroundColor: Theme.backgroundColor
      z: 1
      onPasswordEntered: {
         if( wallet.unlocked )
            return proceedIfUnlocked()

         wallet.unlockWallet(password)
      }

      states: [
         State {
            name: "locked"
            when: !wallet.unlocked
            PropertyChanges {
               target: lockScreen
               x: 0
            }
         },
         State {
            name: "unlocked"
            when: wallet.unlocked
            PropertyChanges {
               target: lockScreen
               x: window.width
            }
         }
      ]
      transitions: [
         Transition {
            from: "unlocked"
            to: "locked"
            SequentialAnimation {
               PropertyAnimation {
                  target: lockScreen
                  duration: 500
                  property: "x"
                  easing.type: Easing.OutBounce
               }
               ScriptAction { script: lockScreen.focus() }
            }
         },
         Transition {
            from: "locked"
            to: "unlocked"
            SequentialAnimation {
               PropertyAnimation {
                  target: lockScreen
                  duration: 500
                  property: "x"
                  easing.type: Easing.InQuad
               }
               ScriptAction { script: lockScreen.clearPassword() }
            }
         }
      ]
   }

   Item {
      id: applicationArea
      anchors.fill: parent
      enabled: wallet.unlocked && !onboardLoader.sourceComponent
      Toolbar {
         id: toolbar
         width: parent.width
         backgroundColor: Theme.primaryColor
      }
      View {
         id: criticalNotificationArea
         y: toolbar.height
         backgroundColor: "#F44336"
         height: units.dp(100)
         width: parent.width
         enabled: false
         z: -1

         //Show iff brain key is set, the main page is not active or transitioning out, and we're not already in an onboarding UI
         property bool active: wallet.brainKey.length > 0 &&
                               !onboardLoader.sourceComponent

         Label {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:  parent.left
            anchors.right: criticalNotificationButton.left
            anchors.margins: visuals.margins
            text: qsTr("Your wallet has not been backed up. You should back it up as soon as possible.")
            color: "white"
            style: "subheading"
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
         }
         Button {
            id: criticalNotificationButton
            anchors.right: parent.right
            anchors.rightMargin: visuals.margins
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Back Up Wallet")
            textColor: "white"

            onClicked: onboardLoader.sourceComponent = backupUi
         }

         states: [
            State {
               name: "active"
               when: criticalNotificationArea.active
               PropertyChanges {
                  target: criticalNotificationArea
                  enabled: true
               }
               PropertyChanges {
                  target: pageStack
                  anchors.topMargin: criticalNotificationArea.height
               }
            }
         ]
         transitions: [
            Transition {
               from: ""
               to: "active"
               reversible: true
               PropertyAnimation { target: pageStack; property: "anchors.topMargin"; easing.type: Easing.InOutQuad }
            }
         ]
      }
      PageStack {
         id: __pageStack
         anchors {
            left: parent.left
            right: parent.right
            top: toolbar.bottom
            bottom: parent.bottom
         }

         onPushed: toolbar.push(page)
         onPopped: toolbar.pop()

         Component {
            id: assetsUi

            AssetsLayout {
               onLockRequested: {
                  wallet.lockWallet()
                  uiStack.pop()
               }
               onOpenHistory: window.pageStack.push(historyUi, {"accountName": account, "assetSymbol": symbol})
            }
         }
         Component {
            id: historyUi

            HistoryLayout {
            }
         }
         Component {
            id: transferUi

            TransferLayout {
               onTransferComplete: window.pageStack.pop()
            }
         }
      }
   }
   Component {
      id: onboardingUi

      OnboardingLayout {
         onFinished: {
            pageStack.push({item: assetsUi, properties: {accountName: wallet.accountNames[0]}, immediate: true})
            onboardLoader.sourceComponent = undefined
         }
      }
   }
   Component {
      id: backupUi

      BackupLayout {
         onFinished: onboardLoader.sourceComponent = undefined
      }
   }
   Loader {
      id: onboardLoader
      z: 2
      anchors.fill: parent
   }
   Snackbar {
      id: snack
      duration: 5000
      enabled: opened
      onClick: opened = false
      z: 21
   }
}
