import Foundation
//import WebKit
import UIKit
//import UserNotifications
//import CommonCrypto

public enum ChaportSDKError: Error {
    case webViewNotLoaded
    case invalidResponse
    case unknown
    case chatDenied(payload: [String: String]?)
    case chatError(payload: [String: String]?)
}

public class ChaportSDK: NSObject {
    
    @MainActor public static let shared = ChaportSDK()
    public weak var delegate: ChaportSDKDelegate?
    private var _isSessionStarted: Bool = false
//    private var _isChatVisible: Bool = false
    private var _isChatVisible: Bool = false {
        didSet {
            guard oldValue != _isChatVisible else { return }
            if  (_isChatVisible) {
                delegate?.chatDidPresent?()
            } else {
                delegate?.chatDidDismiss?()
            }
        }
    }
    
    private var config: Config?
    private var visitorData: VisitorData?
    private var details: UserDetails?
    private var hashStr: String?
    private var languageCode: String?
    private var deviceToken: String?
    private var startedBotId: String?
    private var startedBotTimestamp: Double?
//    private var pendingRequestCompletions: [String: (Result<Any, Error>) -> Void] = [:]
    private var webViewController: ChaportWebViewController?
    private var webViewInactivityTimer: Timer?
    
    internal var webViewURL: URL? {
        guard let config = config else { return nil }
        let domain: String
        
        switch config["region"] ?? "eu" {
          case "us", "eu", "au", "br", "ph":
            domain = "app.chaport.com"
            break
          case "ru":
            domain = "app.chaport.ru"
            break
          default:
            fatalError("Unsupported region code: \(config["region"] ?? "eu")")
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/widget/sdk.html"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "appId", value: config.appId))
        if languageCode == nil {
            if #available(iOS 16, *) {
                languageCode = Locale.current.language.languageCode?.identifier
            } else {
                languageCode = Locale.current.languageCode
            }
        }
        
        queryItems.append(URLQueryItem(name: "language", value: languageCode))
        queryItems.append(URLQueryItem(name: "close", value: "0"))
        
        if let deviceToken = deviceToken {
            queryItems.append(URLQueryItem(name: "deviceToken", value: deviceToken))
        }

        let sessionDict: [String: String] = [
            "persist": (config.session?.persist ?? true) ? "true" : "false"
        ]

        if let sessionJSON = try? JSONSerialization.data(withJSONObject: sessionDict, options: []),
            let sessionString = String(data: sessionJSON, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "session", value: sessionString))
        }

        let appInfo: [String: String] = [
            "teamId": getTeamId() ?? "",
            "bundleId": Bundle.main.bundleIdentifier ?? ""
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: appInfo, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "app", value: jsonString))
        }
        
        components.queryItems = queryItems

        return components.url
    }
    
    // MARK: - Публичные методы
    
    @MainActor public func startSession(details: UserDetails? = nil) {
        if isSessionStarted() {
            Logger.log("Session has already been started", level: .warning)
            return;
        }
        
        guard let _ = config else {
            Logger.log("You must call configure() before startSession()", level: .error)
            return
        }
        
//        guard let url = webViewURL else {
//            Logger.log("Unable to identify WebView URL", level: .error)
//            return
//        }

        let webVC = ChaportWebViewController(dataSource: self)
        webVC.delegate = self

        self.webViewController = webVC
        self.details = details
        self._isSessionStarted = true
    }
    
    /// Настройка SDK
    public func configure(config: Config) {
        self.config = config
    }
    
    /// Установка языка до старта сессии
    public func setLanguage(languageCode: String) {
        self.languageCode = languageCode
    }
    
    /// Завершение сессии и удаление WebView
    @MainActor public func stopSession(clearCache: Bool = true, completion: @escaping () -> Void = {}) {
        if !isSessionStarted() {
            Logger.log("Unable to stop session that hasn't been started", level: .warning)
            completion()
            return
        }
        
        self.ensureWebViewLoaded() { _ in
            var didRemove = false
            
            // This closure ensures webView removal only happens once
            let removeWebViewIfNeeded = {
                guard !didRemove else { return }
                didRemove = true
                
                self.destroyWebView()
                self._isSessionStarted = false
                completion()
            }

            guard let webVC = self.webViewController else {
                removeWebViewIfNeeded()
                return
            }
                        
            // Start the fallback timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                removeWebViewIfNeeded()
            }

            webVC.stopSession(clearCache: clearCache) { _ in
                removeWebViewIfNeeded()
            }
        }
    }
    
    /// Передача данных посетителя
    @MainActor
    public func setVisitorData(visitor: VisitorData, hash: String? = nil) {
        self.visitorData = visitor
        self.hashStr = hash
        
        webViewController?.setVisitorData(visitorData: visitor, hash: hash)
    }
    
    /// Отображение чата (модально)
    @MainActor public func present(from viewController: UIViewController? = nil, completion: @escaping () -> Void = {}) {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using present()", level: .warning)
            return
        }
        
//        print("Will present 1");
        
        // TODO load webview
//        checkSession()
        self.ensureWebViewLoaded(waitForLoad: false) { _ in
//            print("Will present 2");
            guard let webVC = self.webViewController else {
                self.delegate?.chatDidFail?(error: ChaportSDKError.webViewNotLoaded)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
//                print("Will present 3");
                guard let self = self else { return }
                let presentingVC = viewController ?? self.getTopViewController()
                guard presentingVC?.view.window != nil else { return }
                
//                print("Will present 4");
                
                webVC.willMove(toParent: nil)
                webVC.view.removeFromSuperview()
                webVC.removeFromParent()

                webVC.modalPresentationStyle = .pageSheet
                
//                print("Will present 5");
                presentingVC?.present(webVC, animated: true) {
//                    print("Will present 6");
                    self._isChatVisible = true
                    
                    webVC.setClosable(isClosable: true)
                    completion()
//                    print("Will present 7");
                }
            }
        }
    }
    
    /// Встраивание чата (embed) в заданный containerView
    @MainActor public func embed(into containerView: UIView, parentViewController: UIViewController) {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using embed()", level: .warning)
            return
        }
        
        self.ensureWebViewLoaded(waitForLoad: false) { _ in
            guard let webVC = self.webViewController else {
                self.delegate?.chatDidFail?(error: ChaportSDKError.webViewNotLoaded)
                return
            }
            
            parentViewController.addChild(webVC)
            webVC.view.frame = containerView.bounds
            for subview in containerView.subviews {
                subview.removeFromSuperview()
            }
            containerView.addSubview(webVC.view)
            webVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                webVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                webVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                webVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                webVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            webVC.didMove(toParent: parentViewController)
            
            self._isChatVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                webVC.setClosable(isClosable: false)
            }
            webVC.setClosable(isClosable: false)
        }
    }
    
    /// Скрытие чата, открытого через present()
    @MainActor public func dismiss() {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using dismiss()", level: .warning)
            return
        }
        if let webVC = webViewController {
            if webVC.presentingViewController != nil {
                webVC.dismiss(animated: true) { [weak self] in
//                    self?.delegate?.chatDidDismiss()
                    self?._isChatVisible = false
                }
            } else {
//                self.delegate?.chatDidDismiss()
                self._isChatVisible = false
            }
        }
    }
    
    /// Удаление встроенного чата (embed)
    @MainActor public func remove() {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using remove()", level: .warning)
            return
        }
        if let webVC = webViewController {
//            if !webVC.isChatVisible { return }
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()
            self._isChatVisible = false
//            delegate?.chatDidDismiss()
        }
    }
    
    /// Передача токена устройства для push-уведомлений
    @MainActor public func setDeviceToken(deviceToken: String) {
        self.deviceToken = deviceToken
        webViewController?.setDeviceToken(token: deviceToken)
    }
    
    /// Проверка, является ли push-уведомление от Chaport
    public func isChaportPushNotification(notification: UNNotificationRequest) -> Bool {
        return notification.content.userInfo["operator"] != nil
    }
    
    /// Запуск чат-бота
    @MainActor public func startBot(botId: String) {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using startBot()", level: .warning)
            return
        }
        
        let timestamp = Date().timeIntervalSince1970 * 1000

        self.startedBotId = botId
        self.startedBotTimestamp = timestamp

        webViewController?.startBot(botId: botId, timestamp: timestamp)
    }
    
    /// Открытие главной страницы FAQ
    @MainActor public func openFAQ() {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using openFAQ()", level: .warning)
            return
        }
        guard let webVC = webViewController else {
            delegate?.chatDidFail?(error: ChaportSDKError.webViewNotLoaded)
            return
        }
        
        webVC.openFAQ()
    }
    
    /// Открытие статьи FAQ
    @MainActor public func openFAQArticle(articleSlug: String) {
        if !isSessionStarted() {
            Logger.log("You must call startSession() before using openFAQArticle()", level: .warning)
            return
        }
        webViewController?.openFAQArticle(articleSlug: articleSlug)
    }
    
    @MainActor public func isChatVisible() -> Bool {
//        return self.webViewController?.isChatVisible ?? false
        return self._isChatVisible;
    }
    
    @MainActor public func isSessionStarted() -> Bool {
        return self._isSessionStarted;
    }
    
    @MainActor public func getUnreadMessage(completion: @escaping (Result<Any?, Error>) -> Void) {
        self.ensureWebViewLoaded() { webviewLoadResult in
            switch webviewLoadResult {
            case .success():
                self.webViewController?.evaluateJavascriptWithResponse(message: ["action": "getUnreadMessage"]) { result in
                    switch result {
                    case .success(let value):
                        completion(.success(value))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @MainActor public func canStartBot(botId: String? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        if !isSessionStarted() {
            completion(.failure(ChaportSDKError.webViewNotLoaded))
            return
        }
        self.ensureWebViewLoaded() { webviewLoadResult in
            switch webviewLoadResult {
            case .success():
                var payload: [String: Any] = [:]
                
                if let botId = botId {
                    payload["payload"] = botId
                }

                self.webViewController?.evaluateJavascriptWithResponse(message: ["action": "canStartBot", "payload": ["botId": botId]]) { result in
                    switch result {
                    case .success(let value):
                        let canStart = value as? Int ?? 0
                        
                        completion(.success(canStart == 1 ? true : false))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    @MainActor public func setLogLevel(level: LogLevel) {
        Logger.setLogLevel(level)
    }
    
//    @MainActor private func sendMessageToWebView(action: String, data: [String: Any], completion: @escaping (Result<Any, Error>) -> Void) {
//        if !isSessionStarted() {
//            completion(.failure(ChaportSDKError.webViewNotLoaded))
//            return
//        }
//        guard let webVC = webViewController else {
//            completion(.failure(ChaportSDKError.webViewNotLoaded))
//            return
//        }
//        
//        let requestId = UUID().uuidString
//        var message = data
//        message["requestId"] = requestId
//        message["action"] = action
//        
//        pendingRequestCompletions[requestId] = completion
//
//        webVC.evaluateJavaScript(message: message) { _ in }
//    }
    
    // MARK: - Внутренние методы
    
    private func getTopViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }

        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getTopViewController(base: selected)
            }
        }

        if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }

        return base
    }

    private func resetInactivityTimer() {
        if (webViewController != nil) {
            return
        }

        webViewInactivityTimer?.invalidate()
        
        webViewInactivityTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isChatVisible() {
                    ChaportSDK.shared.resetInactivityTimer()
                } else {
                    ChaportSDK.shared.destroyWebView()
                }
            }
        }
    }
    
    @MainActor private func ensureWebViewLoaded(waitForLoad: Bool = true, completion: @escaping (Result<Void, Error>) -> Void) {
//        print("ensureWebViewLoaded 1")
        if isSessionStarted() {
            self.resetInactivityTimer()
//            print("ensureWebViewLoaded 2")
            
            if waitForLoad {
                webViewController?.loadWebView(completion: { result in
//                    print("ensureWebViewLoaded 3")
                    switch result {
                    case .success():
//                        print("ensureWebViewLoaded 4")
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                })
            } else {
                _ = webViewController?.loadWebView(completion: { _ in })
                completion(.success(())) // Don't wait for the load
            }
        } else {
            completion(.failure(ChaportSDKError.webViewNotLoaded))
        }
    }
    
    private func getTeamIdViaSecurityFramework() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "bundleSeedID",
            kSecAttrService as String: "",
            kSecReturnAttributes as String: kCFBooleanTrue as Any
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let dict = result as? [String: Any],
              let accessGroup = dict[kSecAttrAccessGroup as String] as? String else {
            return nil
        }
        
        let components = accessGroup.components(separatedBy: ".")
        guard components.count > 2 else { return nil }
        
        return components[1]
    }
    
    private func getTeamIdViaBundleSeedId() -> String? {
        guard let bundleSeedId = Bundle.main.infoDictionary?["CFBundleSeedId"] as? String else {
            return nil
        }
        
        return bundleSeedId
    }
    
    private func getTeamIdFromProvisioningProfile() -> String? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let contents = try? String(contentsOfFile: path, encoding: .isoLatin1) else {
            return nil
        }
        
        let scanner = Scanner(string: contents)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        
        guard scanner.scanUpToString("TeamIdentifier</key>") != nil,
              scanner.scanString("TeamIdentifier</key>") != nil,
              scanner.scanUpToString("<string>") != nil,
              scanner.scanString("<string>") != nil else {
            return nil
        }
        
        return scanner.scanUpToString("</string>")
    }
    
    private func getTeamIdFromAccessGroups() -> String? {
        guard let accessGroups = Bundle.main.infoDictionary?["keychain-access-groups"] as? [String],
              let firstGroup = accessGroups.first else {
            return nil
        }
        
        let components = firstGroup.components(separatedBy: ".")
        return components.count > 1 ? components[1] : nil
    }
    
    private func getTeamId() -> String? {
        return getTeamIdViaSecurityFramework() ??
               getTeamIdFromProvisioningProfile() ??
               getTeamIdFromAccessGroups()
    }
    
    @MainActor private func destroyWebView() {
        guard let webVC = webViewController else {
            return
        }
        
        self._isChatVisible = false
        
        webVC.willMove(toParent: nil)
        webVC.view.removeFromSuperview()
        webVC.removeFromParent()
        
        webVC.webViewInstance.navigationDelegate = nil
        webVC.webViewInstance.uiDelegate = nil
        
        self.webViewController = nil
    }
}

// MARK: - ChaportWebViewControllerDelegate

extension ChaportSDK: ChaportWebViewControllerDelegate {
    public func webViewLinkClicked(url: URL) -> WebViewLinkAction {
        return delegate?.linkDidClick?(url: url) ?? .allow
    }
    public func webViewDidReceiveMessage(_ message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        let payload = message["payload"] as? [String : Any] ?? [:]
        let data = (payload["data"] ?? payload) as? [String : Any] ?? [:]
        
//        print("Action: \(action)")
//        print("Payload: \(data)")
        
        switch action {
        case "ack":
//            print("Received ack \(message["requestId"] as? String), \(action)")
            self.webViewController?.resolvePendingRequest(message: message)
            
        case "emit":
            if let event = payload["name"] as? String {
//                print("Event: \(event)")
                
                switch event {
                case "chat.dismiss":
                    dismiss()
                case "chat.start":
                    delegate?.chatDidStart?()
                    self.startedBotId = nil
                    self.startedBotTimestamp = nil
//                case "session.start":
                    
                case "chat.denied":
                    if let payload = message["payload"] as? [String: String] {
                        let error = ChaportSDKError.chatDenied(payload: payload)
                        delegate?.chatDidFail?(error: error)
                        self.remove()
                    }
                case "chat.unreadChange":
                    if let count = data["count"] as? Int {
                        let lastMessage = data["lastMessageText"] as? String
                        delegate?.unreadMessageDidChange?(unreadCount: count, lastMessage: lastMessage)
                    }
                default:
                    break
                }
            }
            
        case "error":
            let payload = data.compactMapValues { value in
                if let string = value as? String {
                    return string
                } else {
                    return String(describing: value)
                }
            }
            
            let error = ChaportSDKError.chatError(payload: payload)
            delegate?.chatDidFail?(error: error)
            
        default:
            break
        }
    }
    
    public func webViewDidFailToLoad(error: Error) {
        delegate?.chatDidFail?(error: error)
    }
}

extension ChaportSDK: ChaportWebViewDataSource {
    func onWebViewDidDisappear() {
        self._isChatVisible = false
    }
    func restoreWebView(completion: @escaping (Result<Any?, Error>) -> Void) {
//        print("restoreWebView 1")
        var payload: [String: Any]? = nil
        
        if let details = details {
            payload = ["id": details.id, "token": details.token]
        }
        
//        print("restoreWebView 2")
        self.webViewController?.startSession(payload: payload) { result in
//            print("restoreWebView 3")
            switch result {
            case .success():
//                print("Session started successfully")
//                print("restoreWebView end")
                if self.visitorData != nil {
                    self.webViewController?.setVisitorData(visitorData: self.visitorData!, hash: self.hashStr)
                }
                if self.startedBotId != nil && self.startedBotTimestamp != nil {
                    self.webViewController?.startBot(botId: self.startedBotId!, timestamp: self.startedBotTimestamp!)
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
                break
//            default:
//                print("Failed to start session:", error)
                // Optionally handle error: show alert, retry, etc.
            }
        }
    }
}

class ClosureSleeve {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
