# Chaport Live Chat SDK for iOS

## Requirements

* iOS 15.6+
* Swift 5
* Xcode 13.4+

## Installation

### 1. Install Chaport Live Chat SDK to your iOS app

#### 1.1 Using Cocoapods

Add Chaport to your Podfile like this:

```
use_frameworks!

target :YourApp do
  pod 'Chaport', '~> 1'
end
```

Then run `pod install`.

See [Example-Swift](Examples/Example-Swift/) app for a CocoaPods example.

#### 1.2 Using Swift Package Manager

Add Chaport to your app in Xcode:
1. Open `File` → `Add Package Dependencies...`.
2. Enter `https://github.com/chaport-com/ios-sdk` in a search input and press `Enter`.
3. Select the `ios-sdk` package and click the `Add package` button.
4. Click the `Add package` button again.

See [Example-SwiftUI](Examples/Example-SwiftUI/) app for an SPM example.

#### 1.3 Manually

##### Swift

Simply copy files from Sources directory into your project.

##### Objective-C

TBD

### 2. Update your Info.plist

To enable your users to take and upload photos to the chat as well as download photos to their photo library, add these properties to your Info.plist file:

* `Privacy - Camera Usage Description` [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription)
* `Privacy - Photo Library Usage Description` [NSPhotoLibraryUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryusagedescription) or `Privacy - Photo Library Additions Usage Description` [NSPhotoLibraryAddUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)

### 3. Configure Chaport Live Chat SDK

TBD retrieve appId, configure and present/embed examples

### 4. Enable Push Notifications (Optional)

## Usage

### Initialization

```
import Chaport

let config = Config(appId: "your_app_id")
ChaportSDK.shared.configure(config: config)
```

### 

## 3.2 Отображение чата

Вы можете открыть чат модально:

ChaportSDK.shared.present(from: self)

или встроить его в контейнерный view:

ChaportSDK.shared.embed(into: containerView, parentViewController: self)

## 3.3 Push-уведомления

Передайте токен устройства:

ChaportSDK.shared.setDeviceToken(deviceToken: "your_device_token")

Проверьте принадлежность уведомления чату:

if ChaportSDK.shared.isChaportPushNotification(notification: notificationRequest) {
    // обработка
}

## 4. API методов

Поддерживаются следующие методы:

	•	configure(config:)
	•	setLanguage(languageCode:)
	•	startSession(userDetails:)
	•	stopSession(clearCache:)
	•	setVisitorData(visitor:hash:)
	•	present(from:)
	•	embed(into:parentViewController:)
	•	dismiss()
	•	remove()
	•	setDeviceToken(deviceToken:)
	•	isChaportPushNotification(notification:)
	•	handlePushNotification(notification:)
	•	startBot(botId:)
	•	canStartBot(botId:completion:) и canStartBotAsync(botId:)
	•	openFAQ()
	•	openFAQArticle(articleSlug:)
	•	getUnreadMessage(completion:) и getUnreadMessageAsync()
	•	sendMessageToWebView(message:completion:) и sendMessageToWebViewAsync(message:)

## 5. Делегат

Для отслеживания событий необходимо реализовать протокол ChaportSDKDelegate:

public protocol ChaportSDKDelegate: AnyObject {
    func chatDidStart()
    func chatDidPresent()
    func chatDidDismiss()
    func chatDidFail(error: Error)
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?)
    func linkDidClick(url: URL)
}

Назначьте делегата через ChaportSDK.shared.delegate.

## 6. Примеры интеграции

В каталоге Example/ приведены примеры для UIKit и SwiftUI. Ознакомьтесь с файлами ViewController.swift (UIKit) и ChaportChatView.swift, ContentView.swift (SwiftUI).
