# ChaportSDK — Полная документация

## 1. Введение

ChaportSDK — это iOS SDK для онлайн-чата Chaport, позволяющий клиентам интегрировать чат в свои iOS-приложения без кнопок, всплывающих окон и т.д.  
SDK разработан на Swift, использует WKWebView для загрузки чата и взаимодействует с JS API Chaport через WKScriptMessageHandler и evaluateJavaScript.  
Поддерживается как UIKit, так и SwiftUI (iOS 12+).

## 2. Установка

### Swift Package Manager

1. Откройте проект в Xcode (минимум Xcode 11).
2. В меню **File → Swift Packages → Add Package Dependency...**
3. Укажите URL репозитория или локальный путь к ChaportSDK (где лежит `Package.swift`).
4. Выберите продукт `ChaportSDK`.

### CocoaPods

Добавьте следующую строку в ваш Podfile:

pod 'ChaportSDK'

### Ручная установка

Скопируйте папку `Sources/ChaportSDK` в свой проект, а затем подключите исходники в **Build Settings** → **Compile Sources**.

## 3. Использование

## 3.1 Инициализация и конфигурация

Перед использованием вызовите метод configure(config:), передав объект Config:

let sessionData: [String: Any] = ["persist": true]
let config = Config(appId: "your_app_id", session: sessionData, region: "ru")
ChaportSDK.shared.configure(config: config)

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
