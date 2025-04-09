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
}

public class Chaport: NSObject, UNUserNotificationCenterDelegate {
    
    @MainActor public static let shared = Chaport()
    
    public weak var delegate: ChaportSDKDelegate?
    
    private var config: Config?
    private var languageCode: String?
    private var visitorData: VisitorData?
    private var visitorDataHash: String?
    private var deviceToken: String?
    private var isCanStartBot: Bool?
    
    // Ссылка на текущий контроллер с WebView
    private var webViewController: ChaportWebViewController?
    
    // Таймер для удаления WebView через 10 минут бездействия
    private var webViewInactivityTimer: Timer?
    
    // Формирование URL для WebView с учётом региона, сессии, языка и прочего
    private var webViewURL: URL? {
        guard let config = config else { return nil }
        let domain: String
        
        switch config.region ?? "eu" {
          case "ru":
            domain = "app.chaport.ru"
            break
          case "us", "eu", "au", "br", "ph":
            domain = "app.chaport.com"
            break
          default:
            fatalError("Unsupported region code: \(config.region ?? "ru")")
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/widget/sdk.html"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "appId", value: config.appId))
        if let languageCode = languageCode {
            queryItems.append(URLQueryItem(name: "language", value: languageCode))
        }
        
        if let deviceToken = deviceToken {
            queryItems.append(URLQueryItem(name: "deviceToken", value: deviceToken))
        }
        
        components.queryItems = queryItems

        return components.url
    }
    
    // MARK: - Публичные методы
    
    /// Настройка SDK
    public func configure(config: Config) {
        self.config = config
    }
    
    /// Установка языка до старта сессии
    public func setLanguage(languageCode: String) {
        self.languageCode = languageCode
    }
    
    /// Завершение сессии и удаление WebView
    @MainActor public func stopSession(clearCache: Bool = true) {
        guard let webVC = webViewController else { return }
        webVC.stopSession { [weak self] in
            self?.webViewController = nil
        }
    }
    
    /// Передача данных посетителя
    @MainActor public func setVisitorData(visitor: VisitorData) {
        if (self.visitorData == nil) {
            self.visitorData = visitor
            let payload: [String: Any] = ["name": visitor.name, "email": visitor.email, "custom": visitor.custom]
            webViewController?.setVisitorData(payload: payload, hash: self.visitorDataHash!)
        }
    }
    
    /// Отображение чата (модально)
    @MainActor public func present(from viewController: UIViewController) {
        loadWebViewIfNeeded { [weak self] in
            guard let self = self, let webVC = self.webViewController else { return }

            DispatchQueue.main.async {
                guard viewController.view.window != nil else {
                    return
                }

                webVC.modalPresentationStyle = .fullScreen
                viewController.present(webVC, animated: true) {
                    self.delegate?.chatDidPresent()
                    webVC.setClosable(isClosable: true);
                }
            }
        }
    }
    
    /// Встраивание чата (embed) в заданный containerView
    @MainActor public func embed(into containerView: UIView, parentViewController: UIViewController) {
        loadWebViewIfNeeded { [weak self] in
            guard let self = self, let webVC = self.webViewController else { return }
            parentViewController.addChild(webVC)
            webVC.view.frame = containerView.bounds
            containerView.addSubview(webVC.view)
            webVC.didMove(toParent: parentViewController)

            webVC.setClosable(isClosable: false)
            self.delegate?.chatDidPresent()
        }
    }
    
    /// Скрытие чата, открытого через present()
    @MainActor public func dismiss() {
        if let webVC = webViewController, webVC.presentingViewController != nil {
            webVC.dismiss(animated: true) { [weak self] in
                self?.delegate?.chatDidDismiss()
            }
        }
    }
    
    /// Удаление встроенного чата (embed)
    @MainActor public func remove() {
        if let webVC = webViewController {
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()
            webViewController = nil
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
        return notification.content.userInfo["operator"] != nil
    }
    
    /// Обработка push-уведомления (пример реализации)
    @MainActor public func handlePushNotification(notification: UNNotificationRequest) {
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
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                let topVC = self.topMostViewController(from: rootVC)
                self.present(from: topVC)
            }
        }
    }
    
    @MainActor public func isChatVisible() -> Bool {
        return webViewController?.isChatVisible == true
    }
    
    @MainActor public func canStartBot() -> Bool {
        return isCanStartBot ?? false
    }
    
    public func parseChaportPush(from userInfo: [AnyHashable: Any]) -> ChaportPushPayload? {
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: [])
            let decoded = try JSONDecoder().decode(ChaportPushPayload.self, from: data)
            return decoded
        } catch {
            return nil
        }
    }
    
    @MainActor public func showInAppBanner(operatorName: String, operatorPhotoURL: String, message: String, tapAction: @escaping () -> Void) {
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
    
    @MainActor public func topMostViewController(from root: UIViewController) -> UIViewController {
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
        let timestamp = Date().timeIntervalSince1970 * 1000
        let payload: [String: Any] = ["id": botId, "timestamp": timestamp]
        webViewController?.startBot(payload: payload)
    }
    
    /// Проверка возможности запуска бота
    @MainActor public func canStartBot(botId: String? = nil, completion: @escaping (Bool) -> Void) {
        loadWebViewIfNeeded { [weak self] in
            self?.webViewController?.canStartBot(botId: botId, completion: completion)
        }
    }
    
    /// Открытие главной страницы FAQ
    @MainActor public func openFAQ() {
        webViewController?.openFAQ()
    }
    
    /// Открытие статьи FAQ
    @MainActor public func openFAQArticle(articleSlug: String) {
        webViewController?.openFAQArticle(articleSlug: articleSlug)
    }
    
    /// Получение последнего непрочитанного сообщения и общего количества
    @MainActor public func getUnreadMessage(completion: @escaping (String?, Int) -> Void) {
        loadWebViewIfNeeded { [weak self] in
            self?.webViewController?.getUnreadMessage(completion: completion)
        }
    }
    
    /// Отправка сообщения в WebView с поддержкой ack
    @MainActor public func sendMessageToWebView(message: [String: Any], completion: @escaping (Result<Any?, Error>) -> Void) {
        guard let webVC = webViewController else {
            completion(.failure(ChaportSDKError.webViewNotLoaded))
            return
        }
        var messageToSend = message
        if message["requestId"] == nil {
            messageToSend["requestId"] = UUID().uuidString
        }
        webVC.evaluateJavaScript(message: messageToSend, completion: completion)
    }
    
    // MARK: - Внутренние методы
    
    func sha1(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func mergeSessionData() -> [String: Any] {
        var sessionData = config?.session ?? [:]

        let visitorId = UserDefaults.standard.string(forKey: "chaportVisitorId") ?? ""
        
        if !visitorId.isEmpty {
            let personalSalt = "chaport_salt_2025"
            let token = sha1(personalSalt + visitorId)
            self.visitorDataHash = token
            
            return [
                "id": visitorId,
                "token": token
            ]
        }

        return [:]
    }
    
    @MainActor private func loadWebViewIfNeeded(completion: @escaping () -> Void) {
        if webViewController == nil {
            guard let url = webViewURL else {
                delegate?.chatDidFail(error: ChaportSDKError.invalidResponse)
                return
            }

            let webVC = ChaportWebViewController(url: url)
            webVC.delegate = self
            self.webViewController = webVC
            
            let payload = mergeSessionData()
            webVC.startSession(with: payload)
            
            if let visitor = visitorData {
                let payload: [String: Any] = ["name": visitor.name, "email": visitor.email, "custom": visitor.custom]
                webVC.setVisitorData(payload: payload, hash: self.visitorDataHash!)
            }
            
            if let deviceToken = deviceToken {
                webVC.setDeviceToken(token: deviceToken)
            }

            webVC.loadViewIfNeeded()

            resetInactivityTimer()
            webVC.loadWebView(completion: completion)
        } else {
            resetInactivityTimer()
            completion()
        }
    }
    
    private func resetInactivityTimer() {
        webViewInactivityTimer?.invalidate()
        webViewInactivityTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false, block: { [weak self] _ in
            DispatchQueue.main.async {
                self?.destroyWebView()
            }
        })
    }
    
    @MainActor private func destroyWebView() {
        webViewController?.stopSession { [weak self] in
            guard let self = self else { return }

            if (self.webViewController?.presentingViewController) != nil {
                self.webViewController?.dismiss(animated: true) {
                    self.webViewController = nil
                    self.delegate?.chatDidDismiss()
                }
            } else {
                self.webViewController = nil
                self.delegate?.chatDidDismiss()
            }
        }
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
            if let lastMessage = data["lastMessageText"] as? String,
               let count = data["count"] as? Int {
                delegate?.unreadMessageDidChange(unreadCount: count, lastMessage: lastMessage)
            }
            
            if let canStart = data["canStart"] as? Int {
                isCanStartBot = canStart == 1
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
            if let payload = message["payload"] as? [String: String] {
                let error = ChaportSDKError.chatDenied(payload: payload)
                delegate?.chatDidFail(error: error)
                if let event = message["event"] as? String, event == "chat.denied" {
                    destroyWebView()
                }
            }
            
        default:
            break
        }
    }
}

class ClosureSleeve {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
