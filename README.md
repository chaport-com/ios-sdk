# Chaport Live Chat SDK for iOS

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
  - [Using CocoaPods](#using-cocoapods)
  - [Using Swift Package Manager](#using-swift-package-manager)
  - [Manual installation](#manual-installation)
- [Integration](#integration)
  - [Initialization](#initialize-chaport-sdk)
  - [Chat presentation](#present-the-chat)
  - [Info.plist configuration](#update-your-infoplist)
  - [Push notifications](#implement-push-notifications-optional)
  - [App whitelisting](#enable-application-whitelisting-optional)
- [SDK API](#sdk-api)
  - [Global configuration](#global-configuration)
  - [Session configuration](#session-configuration)
  - [Session management](#session-management)
  - [Custom bots](#custom-bots)
  - [FAQ](#faq)
  - [Push notifications & unread messages](#push-notifications--unread-messages)
  - [Delegate and events](#delegate-and-events)
- [Example apps](#example-apps)

## Requirements

* iOS 15.6+
* Swift 5
* Xcode 13.4+

## Installation

### Using Cocoapods

Add Chaport to your Podfile like this:

```
use_frameworks!

target :YourApp do
  pod 'Chaport', '~> 1'
end
```

Then run `pod install`.

See [Example-Swift](Examples/Example-Swift/) app for a CocoaPods example.

### Using Swift Package Manager

1. In Xcode, go to `File` → `Add Package Dependencies...`.
2. Paste `https://github.com/chaport-com/ios-sdk` into the search bar and press `Enter`.
3. Select the `ios-sdk` package and click the `Add package` button.
4. In the next dialog, confirm by clicking `Add Package` again.

See [Example-SwiftUI](Examples/Example-SwiftUI/) app for an SPM example.

### Manual installation

#### Swift

Copy the contents of the [Sources/](Sources/) directory into your project. Make sure the files are included in your app target.

#### Objective-C

TBD

## Integration

TBD retrieve appId from Chaport app

### Initialize Chaport SDK

```
import Chaport

ChaportSDK.shared.configure(with: ChaportConfig(appId: "your_app_id"))
ChaportSDK.shared.startSession()
```

### Present the chat

Present the chat in a modal view:

```
ChaportSDK.shared.present()
```

Embed the chat into your own view hierarchy:

```
ChaportSDK.shared.embed(into: chatContainerView, parentViewController: self)
```

### Update your Info.plist

To enable your users to take and upload photos to the chat as well as download photos to their photo library, add these properties to your Info.plist file:

* `Privacy - Camera Usage Description` [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription)
* `Privacy - Photo Library Usage Description` [NSPhotoLibraryUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryusagedescription) or `Privacy - Photo Library Additions Usage Description` [NSPhotoLibraryAddUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)

### Implement push notifications (optional)

TBD instruct how to get bundle and team ids, key id and the key itself
TBD instruct how set up iOS SDK in Chaport app

#### Enable Push Notification Capability in Xcode

1. Open your project in Xcode.
2. Select your target.
3. Go to the "Signing & Capabilities" tab.
4. Click the "+ Capability" button and add "Push Notifications".

#### Register the device for push notifications

You can register for notifications at app launch:

```
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if granted {
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }
}
```

Alternatively, delay permission request until the [chat starts](#example-delegate-implementation):

```
func chatDidStart() {
  UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if granted {
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }
}
```

In this case, remember to check and reuse an existing permission on startup:

```
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized else {
            // Push not authorized yet, skipping device token registration
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    return true
}
```

#### Pass the device token to Chaport

```
import Chaport

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
  ChaportSDK.shared.setDeviceToken(tokenString)
}
```

#### Handle incoming notifications

```
func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  willPresent notification: UNNotification,
  withCompletionHandler completionHandler:
  @escaping (UNNotificationPresentationOptions) -> Void
) {
  if ChaportSDK.shared.isChaportPushNotification(notification.request) {
    ChaportSDK.shared.handlePushNotification(notification.request)
    if (ChaportSDK.shared.isChatVisible()) {
      completionHandler([])
    } else {
      completionHandler([.banner, .sound])
    }
  } else {
    // other notifications
    completionHandler([])
  }
}
```

Open the chat when user taps on a notification:

```
func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  didReceive response: UNNotificationResponse,
  withCompletionHandler completionHandler: @escaping () -> Void
) {
  if ChaportSDK.shared.isChaportPushNotification(response.notification.request) {
    if (!ChaportSDK.shared.isChatVisible()) {
      DispatchQueue.main.async {
        ChaportSDK.shared.present()
      }
    }
  }

  completionHandler()
}
```

### Enable application whitelisting (optional)

By default, the Chaport SDK can be initialized with any valid appId. While this setup is flexible and simplifies onboarding, you may request that we restrict SDK usage to a list of approved applications for your account.

This optional restriction helps prevent unauthorized use of your appId in third-party apps.

To use this feature:
1. Go to [Settings → Integrations](https://app.chaport.com/#/settings/integrations), select `Mobile SDK` and connect your iOS applications.
2. Contact our support to enable application whitelisting for your account.

## SDK API

### Configuration

The Chaport SDK separates configuration into two distinct scopes to ensure clarity and flexibility: global and session.

#### Global configuration

Global configuration includes settings that are applied once at app launch and persist for the duration of the app’s lifecycle. These values are not tied to a particular user or session.

##### configure

```
ChaportSDK.shared.configure(with: ChaportConfig(appId: "<appId>"))
```

##### setDeviceToken

Pass device token to enable push notifications on this device.

```
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
  ChaportSDK.shared.setDeviceToken(tokenString)
}
```

##### setLogLevel

```
ChaportSDK.shared.setLogLevel(level: .error)
```

#### Session configuration

Session configuration defines values specific to an individual app user. These settings may change between sessions, such as when a user logs out and another logs in (see [Session management](#session-management)).

##### setVisitorData

```
ChaportSDK.shared.setVisitorData(ChaportVisitorData(name: "Test SDK visitor", email: "test@email.com"))
```

##### setLanguage

By default, language is selected based on the device preference. You can use this method to override the default. Check out [the available languages](https://www.chaport.com/help/general/what-languages-are-supported-by-chaport).

```
ChaportSDK.shared.setLanguage("en")
```

### Session management

The Chaport SDK provides explicit control over session lifecycle. A session represents a period during which the SDK operates in the context of a specific visitor (i.e., app user). This typically involves associating the session with user metadata such as name, email, or language preference (see [Session configuration](#session-configuration)).

Importantly, starting a session does not initiate any user interface or background network activity. The SDK follows a lazy loading model, meaning UI elements (e.g. the chat screen) are only loaded and displayed when explicitly requested.

#### startSession

Initializes the SDK into an active session state. This signals that the app is operating on behalf of a specific visitor, and enables SDK features like chat, FAQs, or bot interaction to be used when needed.

This method does not display the chat or trigger any immediate loading of resources. It simply prepares the SDK to respond appropriately when presentation methods (like present()) are called later.

```
ChaportSDK.shared.startSession()
```

Or pass user credentials to the SDK to control in-chat user identity.

```
ChaportSDK.shared.startSession(userCredentials: ChaportUserCredentials(id: "my-user-id", token: "token-hash"))
```

#### stopSession

Terminates the current session and clears any associated visitor data. This is typically used when a user logs out or when you want to reset the SDK to a neutral, unauthenticated state.

After calling this, any [session-specific configuration](#session-configuration) must be reapplied before or after starting a new session.

#### isSessionStarted

Returns a **Boolean** indicating whether the SDK is currently operating in an active session state.

```
if ChaportSDK.shared.isSessionStarted() {
  // do some processing
}
```

### Chat presentation

#### present

Present the chat in a modal view:

```
ChaportSDK.shared.present()
```

#### embed

Embed the chat into your own view hierarchy:

```
ChaportSDK.shared.embed(into: chatContainerView, parentViewController: self)
```

#### dismiss

Dismiss the chat that was previously `present`ed. For the convenience, this method will also work as [remove](#remove) if chat was instead `embed`ded.

```
ChaportSDK.shared.dismiss()
```

#### remove

Remove the chat that was previously `embed`ded. For the convenience, this method will also work as [dismiss](#dismiss) if chat was instead `present`ed.

```
ChaportSDK.shared.remove()
```

#### isChatPresented

Returns a **Boolean** indicating whether the chat is currently `present`ed.

#### isChatEmbedded

Returns a **Boolean** indicating whether the chat is currently `embed`ded.

#### isChatVisible

Returns a **Boolean** indicating whether the chat is currently either `present`ed or `embed`ded.

### Custom bots

The Chaport SDK allows you to trigger custom bots manually using their unique identifier. However, custom bots are subject to specific conditions that determine whether they can be started. These constraints help avoid unexpected behavior and ensure bots don’t interrupt active conversations or repeat unnecessarily.

A custom bot can only be started if both of the following conditions are met:

1. No chat is currently active
     The user must not already be engaged in an active chat — whether that's a session with an operator or another bot.

2. Bot has not already been completed (if "Once per user" enabled)
     If the targeted bot has the “Once per user” flag enabled, it can only be finished once per user. Repeated attempts will be ignored unless the bot was never completed.

#### canStartBot

Checks whether the specified custom bot can be started under the current conditions. Use this method to determine if calling startBot would have any effect.

```
ChaportSDK.shared.canStartBot(botId: "<botId>") { canStart in
  if canStart {
    ChaportSDK.shared.startBot(botId: "<botId>")
    ChaportSDK.shared.present()
  }
}
```

#### startBot

Attempts to start the specified custom bot. If the conditions above are not met, this call is silently ignored and no action is taken.

This method leaves it to you to present or embed the chat as needed. You may decide to do neither, in which case the initial bot message will pop when app user opens the chat.

```
ChaportSDK.shared.startBot(botId: "<botId>")
ChaportSDK.shared.present()
```

### FAQ

#### openFAQ

```
ChaportSDK.shared.openFAQ()
ChaportSDK.shared.present()
```

#### openFAQArticle

```
ChaportSDK.shared.openFAQArticle(articleSlug: "my-article")
ChaportSDK.shared.present()
```

### Push notifications & unread messages

#### isChaportPushNotification

Returns a **Boolean** indicating whether the passed notification was sent by Chaport.

```
func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  willPresent notification: UNNotification,
  withCompletionHandler completionHandler:
  @escaping (UNNotificationPresentationOptions) -> Void
) {
  if ChaportSDK.shared.isChaportPushNotification(notification: notification.request) {
    if (ChaportSDK.shared.isChatVisible()) {
      completionHandler([])
    } else {
      completionHandler([.banner, .sound])
    }
  } else {
    completionHandler([])
  }
}
```

#### fetchUnreadMessageInfo

```
ChaportSDK.shared.fetchUnreadMessageInfo { result in
  switch result {
  case .success(let unreadMessageInfo):
    print("fetchUnreadMessageInfo: \(String(describing: unreadMessageInfo))")
  case .failure(let error):
    // handle error
    break
  }
}
```

### Delegate and events

The SDK allows you to observe key chat events using a delegate. There are two delegate protocols:

* ChaportSDKDelegate — compatible with both Swift and Objective-C
* ChaportSDKSwiftDelegate — Swift-only, includes Swift-native types

If you're building your app in Swift, we recommend implementing both protocols.
If you're using Objective-C, implement only ChaportSDKDelegate.

#### Assigning the delegate

```
ChaportSDK.shared.setDelegate(self)
```

#### Example delegate implementation

```
extension ViewController: ChaportSDKDelegate, ChaportSDKSwiftDelegate {
  /// Called when a new chat session is started
  func chatDidStart() {
    print("Chat started")
    
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      } else {
        print("Push permission denied: \(String(describing: error))")
      }
    }
  }
  
  /// Called when a chat widget is presented or embedded within a view
  func chatDidPresent() {
    print("Chat presented")
  }
  
  /// Called when a chat widget is dismissed or removed from the view
  func chatDidDismiss() {
    print("Chat dismissed")
  }
  
  /// Called when SDK detects an error
  func chatDidFail(error: Error) {
    print("Chat error: \(error)")
  }
  
  /// Called when unread message information changes
  func unreadMessageDidChange(unreadInfo: ChaportUnreadMessageInfo) {
    print("Unread message changed: \(unreadInfo)")
  }
  
  /// Called when a user clicks an external link in chat, by default links are opened in external browser
  func linkDidClick(url: URL) -> ChaportLinkAction {
    print("Link clicked: \(url)")
    return .allow
  }
}
```

## Example apps

You can find sample UIKit and SwiftUI applications in the [Examples/](Examples/) directory.
