import Foundation
import WebKit
import UIKit
import UserNotifications
import CommonCrypto

public enum ChaportSDKError: Error {
    case webViewNotLoaded
    case invalidResponse
    case unknown
    case chatDenied(payload: [String: String]?)
    case chatError(payload: [String: String]?)
}

public class Chaport: NSObject, UNUserNotificationCenterDelegate {
    
    @MainActor public static let shared = Chaport()
    public weak var delegate: ChaportSDKDelegate?
    public var isStartSession: Bool = false
    
    private var config: Config?
    private var visitorData: VisitorData?
    private var details: UserDetails?
    private var hashStr: String?
    private var languageCode: String?
    private var deviceToken: String?
    private var pendingContinuations: [String: CheckedContinuation<[String: Any], Never>] = [:]
    private var webViewController: ChaportWebViewController?
    private var webViewInactivityTimer: Timer?
    
    private var webViewURL: URL? {
        guard let config = config else { return nil }
        let domain: String
        
        switch config["region"] ?? "eu" {
          case "ru":
            domain = "app.chaport.ru"
            break
          case "us", "eu", "au", "br", "ph":
            domain = "app.chaport.com"
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
            languageCode = Locale.current.languageCode
        }
        
        queryItems.append(URLQueryItem(name: "language", value: languageCode))
        
        if let deviceToken = deviceToken {
            queryItems.append(URLQueryItem(name: "deviceToken", value: deviceToken))
        }

        let sessionDict: [String: String] = [
            "persist": (config.session?.persist ?? false) ? "true" : "false"
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
        if isStartSession { return }
        
        guard let _ = config else {
            print("Config not found")
            return
        }
        
        guard let url = webViewURL else {
            print("webViewURL not found")
            return
        }

        let webVC = ChaportWebViewController(url: url)
        webVC.delegate = self
        self.webViewController = webVC
        self.details = details
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
        if !isStartSession { return }
        self.destroyWebView(clearCache: clearCache) {
            completion()
        }
    }
    
    /// Передача данных посетителя
    @MainActor
    public func setVisitorData(visitor: VisitorData, hash: String? = nil) {
        var payload: [String: Any] = [:]
        
        if let name = visitor.name {
            payload["name"] = name
        }
        if let email = visitor.email {
            payload["email"] = email
        }
        if let phone = visitor.phone {
            payload["phone"] = phone
        }
        if let notes = visitor.notes {
            payload["notes"] = notes
        }
        if let custom = visitor.custom {
            payload["custom"] = custom
        }
        self.visitorData = visitor
        self.hashStr = hash
    }
    
    /// Отображение чата (модально)
    @MainActor public func present(from viewController: UIViewController, completion: @escaping () -> Void = {}) {
        checkSession()
        
        guard let webVC = webViewController else {
            delegate?.chatDidFail(error: ChaportSDKError.webViewNotLoaded)
            return
        }
        
        DispatchQueue.main.async {
            guard viewController.view.window != nil else {
                return
            }
            
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()
            webVC.isChatVisible = false

            webVC.modalPresentationStyle = .pageSheet
            viewController.present(webVC, animated: true) {
                webVC.isChatVisible = true
                
                if self.isStartSession {
                    self.delegate?.chatDidPresent()
                    return
                }
                
                webVC.setClosable(isClosable: true)
                completion()
            }
        }
    }
    
    @MainActor
    public func getChatViewController() -> UIViewController? {
        if !isStartSession { return nil }
        if let webVC = self.webViewController {
            return webVC
        }
        return nil
    }
    
    /// Встраивание чата (embed) в заданный containerView
    @MainActor public func embed(into containerView: UIView, parentViewController: UIViewController) {
        checkSession()
        
        guard let webVC = webViewController else {
            delegate?.chatDidFail(error: ChaportSDKError.webViewNotLoaded)
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
        
        if self.isStartSession {
            webVC.isChatVisible = true
            self.delegate?.chatDidPresent()
            return
        }
        
        webVC.setClosable(isClosable: false)
    }
    
    /// Скрытие чата, открытого через present()
    @MainActor public func dismiss() {
        if !isStartSession { return }
        if let webVC = webViewController {
            if webVC.presentingViewController != nil {
                webVC.dismiss(animated: true) { [weak self] in
                    self?.delegate?.chatDidDismiss()
                    webVC.isChatVisible = false
                }
            } else {
                self.delegate?.chatDidDismiss()
                webVC.isChatVisible = false
            }
        }
    }
    
    /// Удаление встроенного чата (embed)
    @MainActor public func remove() {
        if let webVC = webViewController {
            if !webVC.isChatVisible { return }
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()
            webVC.isChatVisible = false
            delegate?.chatDidDismiss()
        }
    }
    
    /// Передача токена устройства для push-уведомлений
    @MainActor public func setDeviceToken(deviceToken: String) {
        self.deviceToken = deviceToken
        webViewController?.setDeviceToken(token: deviceToken)
    }
    
    /// Проверка, является ли push-уведомление от Chaport
    public func isChaportPushNotification(notification: UNNotificationRequest) -> Bool {
        if !isStartSession { return false }
        return notification.content.userInfo["operator"] != nil
    }
    
    /// Обработка push-уведомления (пример реализации)
    @MainActor public func handlePushNotification(notification: UNNotificationRequest, completion: @escaping () -> Void = {}) {
        if !isStartSession { return }
        guard UIApplication.shared.applicationState == .active else { return }
        
        if webViewController?.isChatVisible == true {
            return
        }
        
        let userInfo = notification.content.userInfo

        guard let payload = parseChaportPush(from: userInfo) else { return }

        let operatorName = payload.operator.name
        let operatorPhotoURL = payload.operator.image
        let message = payload.message ?? notification.content.body

        showInAppBanner(operatorName: operatorName, operatorPhotoURL: operatorPhotoURL, message: message) {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
               let topVC = self.topMostViewController(from: rootVC) {
                self.present(from: topVC) {
                    completion()
                }
            }
        }
    }
    
    private func parseChaportPush(from userInfo: [AnyHashable: Any]) -> ChaportPushPayload? {
        if !isStartSession { return nil }
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: [])
            let decoded = try JSONDecoder().decode(ChaportPushPayload.self, from: data)
            return decoded
        } catch {
            return nil
        }
    }
    
    @MainActor public func showInAppBanner(operatorName: String, operatorPhotoURL: String, message: String, tapAction: @escaping () -> Void) {
        if !isStartSession { return }
        guard let window = UIApplication.shared.windows.first else { return }

        let bannerHeight: CGFloat = 88
        let bannerWidth = window.bounds.width - 32
        let bannerView = UIView(frame: CGRect(x: 16, y: -bannerHeight, width: bannerWidth, height: bannerHeight))

        let isDarkMode: Bool
        if #available(iOS 12.0, *) {
            isDarkMode = window.traitCollection.userInterfaceStyle == .dark
        } else {
            isDarkMode = false
        }

        bannerView.backgroundColor = isDarkMode ? UIColor(white: 0.1, alpha: 1.0) : .white
        bannerView.layer.cornerRadius = 14
        bannerView.layer.shadowColor = UIColor.black.cgColor
        bannerView.layer.shadowOpacity = 0.1
        bannerView.layer.shadowRadius = 4
        bannerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        bannerView.clipsToBounds = false

        let imageSize: CGFloat = 44
        let imageView = UIImageView(frame: CGRect(x: 12, y: (bannerHeight - imageSize) / 2, width: imageSize, height: imageSize))
        imageView.backgroundColor = .lightGray
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = imageSize / 2
        imageView.contentMode = .scaleAspectFill
        
        if let url = URL(string: operatorPhotoURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        }

        let nameLabel = UILabel()
        nameLabel.text = operatorName
        nameLabel.font = .boldSystemFont(ofSize: 16)
        nameLabel.textColor = isDarkMode ? .white : .black
        nameLabel.frame = CGRect(x: imageView.frame.maxX + 12, y: 12, width: bannerWidth - imageView.frame.maxX - 24, height: 20)

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = isDarkMode ? .lightText : .darkGray
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.frame = CGRect(x: imageView.frame.maxX + 12, y: nameLabel.frame.maxY + 2, width: bannerWidth - imageView.frame.maxX - 24, height: 40)

        bannerView.addSubview(imageView)
        bannerView.addSubview(nameLabel)
        bannerView.addSubview(messageLabel)
        window.addSubview(bannerView)

        UIView.animate(withDuration: 0.3) {
            bannerView.frame.origin.y = 50
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            UIView.animate(withDuration: 0.3, animations: {
                bannerView.frame.origin.y = -bannerHeight
            }, completion: { _ in
                bannerView.removeFromSuperview()
            })
        }

        let tap = UITapGestureRecognizer(target: ClosureSleeve {
            bannerView.removeFromSuperview()
            tapAction()
        }, action: #selector(ClosureSleeve.invoke))
        bannerView.addGestureRecognizer(tap)
    }
    
    @MainActor public func topMostViewController(from root: UIViewController) -> UIViewController? {
        if !isStartSession { return nil }
        if let presented = root.presentedViewController {
            return topMostViewController(from: presented)
        } else if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMostViewController(from: visible)
        } else if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return root
    }
    
    /// Запуск чат-бота
    @MainActor public func startBot(botId: String) {
        if !isStartSession { return }
        let timestamp = Date().timeIntervalSince1970 * 1000
        let payload: [String: Any] = ["id": botId, "timestamp": timestamp]
        webViewController?.startBot(payload: payload)
    }
    
    /// Открытие главной страницы FAQ
    @MainActor public func openFAQ() {
        guard let webVC = webViewController else {
            delegate?.chatDidFail(error: ChaportSDKError.webViewNotLoaded)
            return
        }
        
        webVC.openFAQ()
    }
    
    /// Открытие статьи FAQ
    @MainActor public func openFAQArticle(articleSlug: String) {
        if !isStartSession { return }
        webViewController?.openFAQArticle(articleSlug: articleSlug)
    }
    
    @MainActor public func isChatVisible() -> Bool {
        return self.webViewController?.isChatVisible ?? false
    }
    
    @MainActor public func getUnreadMessage() async -> [String: Any]? {
        checkSession()
        let response = await sendMessageToWebView(action: "getUnreadMessage", data: [:])
        return response
    }

    @MainActor public func canStartBot(botId: String? = nil) async -> Bool {
        checkSession()
        var payload: [String: Any] = [:]
        
        if let botId = botId {
            payload["payload"] = botId
        }
        
        let response = await sendMessageToWebView(action: "canStartBot", data: payload)
        return (response?["canStart"] as? Int) == 1
    }
    
    @MainActor private func sendMessageToWebView(action: String, data: [String: Any]) async -> [String: Any]? {
        if !isStartSession { return nil }
        guard let webVC = webViewController else {
            return nil
        }
        
        let requestId = UUID().uuidString
        var message = data
        message["requestId"] = requestId
        message["action"] = action

        return await withCheckedContinuation { continuation in
            pendingContinuations[requestId] = continuation
            webVC.evaluateJavaScript(message: message) { _ in }
        }
    }
    
    // MARK: - Внутренние методы
    
    private func resetInactivityTimer() {
        guard let webVC = webViewController else { return }

        webViewInactivityTimer?.invalidate()
        
        webViewInactivityTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { _ in
            DispatchQueue.main.async {
                if webVC.isChatVisible {
                    Chaport.shared.resetInactivityTimer()
                } else {
                    Chaport.shared.destroyWebView() {}
                }
            }
        }
    }
    
    @MainActor private func checkSession() {
        if !isStartSession {
            self.startSession()
            
            var payload: [String: Any]? = nil
            
            if let details = details {
                payload = ["id": details.id, "token": details.token]
            }
            
            if let session = config?.session {
                if payload == nil {
                    payload = ["session": session]
                }
                
                payload!["session"] = session
            }

            webViewController?.loadWebView(completion: {
                self.webViewController?.startSession(with: payload)
                self.resetInactivityTimer()
                
                if let visitor = self.visitorData {
                    self.webViewController?.setVisitorData(payload: visitor.asDictionary, hash: self.hashStr)
                }
            })
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
    
    @MainActor private func destroyWebView(clearCache: Bool = false, completion: @escaping () -> Void) {
        guard let webVC = webViewController else {
            return
        }
        
        if self.isStartSession {
            webVC.stopSession(clearCache: clearCache)
            self.isStartSession = false
            
            if (self.webViewController?.presentingViewController) != nil {
                self.webViewController?.dismiss(animated: true) {
                    self.delegate?.chatDidDismiss()
                }
            } else {
                self.delegate?.chatDidDismiss()
                self.remove()
            }
        }
        
        completion()
    }
}

// MARK: - ChaportWebViewControllerDelegate

extension Chaport: ChaportWebViewControllerDelegate {
    func webViewDidReceiveMessage(_ message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        guard let payload = message["payload"] as? [String : Any] else { return }
        guard let data = (payload["data"] ?? payload) as? [String : Any] else { return }
        
        print("Action: \(action)")
        print("Payload: \(data)")
        
        switch action {
        case "ack":
            if let requestId = message["requestId"] as? String,
                let continuation = pendingContinuations.removeValue(forKey: requestId) {
                DispatchQueue.main.async {
                    continuation.resume(returning: data)
                }
            }
            
            break
            
        case "emit":
            if let event = payload["name"] as? String {
                print("Event: \(event)")
                
                switch event {
                case "chat.dismiss":
                    dismiss()
                case "chat.start":
                    delegate?.chatDidStart()
                case "session.start":
                    guard let webVC = webViewController else {
                        return
                    }
                    
                    self.isStartSession = true
                    delegate?.chatDidPresent()
                    webVC.startEvents()
                case "chat.denied":
                    if let payload = message["payload"] as? [String: String] {
                        let error = ChaportSDKError.chatDenied(payload: payload)
                        delegate?.chatDidFail(error: error)
                        self.webViewController?.isChatVisible = false
                    }
                case "chat.unreadChange":
                    if let count = data["count"] as? Int {
                        let lastMessage = data["lastMessageText"] as? String
                        delegate?.unreadMessageDidChange(unreadCount: count, lastMessage: lastMessage)
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
            delegate?.chatDidFail(error: error)
            
        default:
            break
        }
    }
    
    func webViewDidFailToLoad(error: Error) {
        delegate?.chatDidFail(error: error)
    }
}

class ClosureSleeve {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
