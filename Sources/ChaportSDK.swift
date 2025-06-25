import Foundation
import UIKit

public enum ChaportSDKError: Error {
    case webViewNotLoaded
    case invalidResponse
    case unknown
    case chatDenied(payload: [String: String]?)
    case chatError(payload: [String: String]?)
}

public class ChaportSDK: NSObject {
    @MainActor public static let shared = ChaportSDK()
    public static let version = "1.0.23"
    internal weak var delegate: ChaportSDKDelegate?
    internal weak var swiftDelegate: ChaportSDKSwiftDelegate?
    private var _isSessionStarted: Bool = false
    private var _isChatPresented: Bool = false
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

    
    private var config: ChaportConfig?
    private var userCredentials: ChaportUserCredentials?
    private var deviceToken: String?
    private var languageCode: String?
    private var startedBotId: String?
    private var startedBotTimestamp: Double?
    private var teamId: String?
    private var visitorData: ChaportVisitorData?
    private var visitorDataHash: String?
    private var webViewController: ChaportWebViewController?
    private var webViewInactivityTimer: Timer?
    
    internal var webViewURL: URL? {
        guard let config = config else { return nil }
        let domain: String
        let region = config["region"] ?? "eu"
        
        switch region {
          case "us":
            domain = "app.chaport.com"
            break
          case "eu":
            domain = "app.chaport.com"
            break
          case "au":
            domain = "app.chaport.com"
            break
          case "br":
            domain = "app.chaport.com"
            break
          case "ph":
            domain = "app.chaport.com"
            break
          case "ru":
            domain = "app.chaport.ru"
            break
          default:
            domain = "app.chaport.com"
            DispatchQueue.main.async {
                ChaportLogger.log("Unsupported region code: \(region), falling back to 'eu'", level: .warning)
            }
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
    
    public func setDelegate(_ delegate: AnyObject) {
        self.delegate = delegate as? ChaportSDKDelegate
        self.swiftDelegate = delegate as? ChaportSDKSwiftDelegate
    }
    
    public func configure(with config: ChaportConfig) {
        if (self.config != nil && isSessionStarted()) {
            ChaportLogger.log("Unable to re-configure after session has already been started", level: .warning)
            return;
        }
        self.config = config
    }
    
    public func setLanguage(_ languageCode: String) {
        self.languageCode = languageCode
    }
    
    public func startSession(userCredentials: ChaportUserCredentials? = nil) {
        if isSessionStarted() {
            ChaportLogger.log("Session has already been started", level: .warning)
            return;
        }
        
        guard let _ = config else {
            ChaportLogger.log("You must call configure() before startSession()", level: .error)
            return
        }

        self.ensureWebViewController()
        self.getTeamIdAsync() { _ in } // initialize teamId early

        self.userCredentials = userCredentials
        self._isSessionStarted = true
    }
    
    public func stopSession(clearCache: Bool = true, completion: @escaping () -> Void = {}) {
        if !isSessionStarted() {
            ChaportLogger.log("Unable to stop session that hasn't been started", level: .warning)
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
                self.visitorData = nil
                self.visitorDataHash = nil
                self.startedBotId = nil
                self.startedBotTimestamp = nil
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
    
    public func setVisitorData(_ data: ChaportVisitorData, signedWith hash: String? = nil) {
        self.visitorData = data
        self.visitorDataHash = hash
        
        // visitor data stored at self is sent automatically immediately after startSession is processed
        if webViewController?.isStartSessionProcessed == true {
            webViewController?.setVisitorData(visitorData: data, hash: hash)
        }
    }
    
    public func present(from viewController: UIViewController? = nil, completion: @escaping () -> Void = {}) {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using present()", level: .warning)
            return
        }
        
        self.ensureWebViewLoaded(waitForLoad: false) { _ in
            self.presentWhenViewReady(viewController: viewController) {
                completion()
            }
        }
    }
    
    private func presentWhenViewReady(viewController: UIViewController?, priorTries: Int = 0, completion: @escaping () -> Void = {}) {
        guard let webVC = self.webViewController else {
            self.delegate?.chatDidFail?(error: ChaportSDKError.webViewNotLoaded)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let presentingVC = viewController ?? self.getTopViewController()
            guard presentingVC?.view.window != nil else {
                if (priorTries > 5) { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.presentWhenViewReady(viewController: viewController, priorTries: priorTries + 1, completion: completion)
                }
                return
            }
            
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()

            webVC.modalPresentationStyle = .pageSheet
            
            presentingVC?.present(webVC, animated: true) {
                self._isChatPresented = true
                self._isChatVisible = true
                
                webVC.setClosable(isClosable: true)
                completion()
            }
        }
    }
    
    public func embed(into containerView: UIView, parentViewController: UIViewController) {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using embed()", level: .warning)
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
            self._isChatPresented = false

            webVC.setClosable(isClosable: false)
        }
    }
    
    public func dismiss() {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using dismiss()", level: .warning)
            return
        }
        if isChatEmbedded() {
            ChaportLogger.log("Called .dismiss() for embedded chat, doing .remove() instead", level: .info)
            return remove()
        }
        if let webVC = webViewController {
            if webVC.presentingViewController != nil {
                webVC.dismiss(animated: true) { [weak self] in
                    self?._isChatVisible = false
                    self?._isChatPresented = false
                }
            } else {
                self._isChatVisible = false
                self._isChatPresented = false
            }
        }
    }
    
    public func remove() {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using remove()", level: .warning)
            return
        }
        if isChatPresented() {
            ChaportLogger.log("Called .remove() for presented chat, doing .dismiss() instead", level: .info)
            return dismiss()
        }
        if let webVC = webViewController {
            webVC.willMove(toParent: nil)
            webVC.view.removeFromSuperview()
            webVC.removeFromParent()
            self._isChatVisible = false
        }
    }
    
    public func setDeviceToken(_ deviceToken: String) {
        self.deviceToken = deviceToken
        webViewController?.setDeviceToken(token: deviceToken)
    }
    
    public func isChaportPushNotification(_ notification: UNNotificationRequest) -> Bool {
        return notification.content.userInfo["operator"] != nil
    }
    
    public func startBot(botId: String) {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using startBot()", level: .warning)
            return
        }
        
        let timestamp = Date().timeIntervalSince1970 * 1000

        self.startedBotId = botId
        self.startedBotTimestamp = timestamp
        
        if webViewController?.isStartSessionProcessed == true { // bot data stored at self is sent automatically immediately after startSession is processed
            webViewController?.startBot(botId: botId, timestamp: timestamp)
        }
    }
    
    public func openFAQ() {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using openFAQ()", level: .warning)
            return
        }
        guard let webVC = webViewController else {
            delegate?.chatDidFail?(error: ChaportSDKError.webViewNotLoaded)
            return
        }
        
        webVC.openFAQ()
    }
    
    public func openFAQArticle(articleSlug: String) {
        if !isSessionStarted() {
            ChaportLogger.log("You must call startSession() before using openFAQArticle()", level: .warning)
            return
        }
        webViewController?.openFAQArticle(articleSlug: articleSlug)
    }
    
    public func isChatVisible() -> Bool {
        return self._isChatVisible;
    }
    
    public func isChatPresented() -> Bool {
        return self._isChatVisible && self._isChatPresented;
    }
    
    public func isChatEmbedded() -> Bool {
        return self._isChatVisible && !self._isChatPresented;
    }
    
    public func isSessionStarted() -> Bool {
        return self._isSessionStarted;
    }
    
    public func fetchUnreadMessageInfo(completion: @escaping (Result<ChaportUnreadMessageInfo?, Error>) -> Void) {
        self.ensureWebViewLoaded() { webviewLoadResult in
            switch webviewLoadResult {
            case .success():
                self.webViewController?.evaluateJavascriptWithResponse(message: ["action": "getUnreadMessage"]) { result in
                    switch result {
                    case .success(let value):
                        guard let unreadInfo = ChaportUnreadMessageInfo(from: value) else {
                            completion(.failure(ChaportSDKError.invalidResponse))
                            return
                        }
                        completion(.success(unreadInfo))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func canStartBot(botId: String? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
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

                self.webViewController?.evaluateJavascriptWithResponse(message: ["action": "canStartBot", "payload": botId ?? NSNull()]) { result in
                    switch result {
                    case .success(let value):
                        guard
                            let dict = value as? [String: Any],
                            let canStart = dict["canStart"] as? Bool
                        else {
                            ChaportLogger.log("canStartBot method returned response malformed response", level: .warning)
                            completion(.failure(ChaportSDKError.invalidResponse))
                            return
                        }
                        
                        completion(.success(canStart))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func setLogLevel(level: ChaportLogLevel) {
        ChaportLogger.setLogLevel(level)
    }
    
    private func ensureWebViewController() {
        if (self.webViewController == nil) {
            let webVC = ChaportWebViewController(dataSource: self)
            webVC.delegate = self

            self.webViewController = webVC
        }
    }
    
    private func getTopViewController(from base: UIViewController? = {
        let activeScene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first

        let rootVC = activeScene?.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        return rootVC
    }()) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }

        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getTopViewController(from: selected)
            }
        }

        if let presented = base?.presentedViewController {
            return getTopViewController(from: presented)
        }

        return base
    }

    private func resetInactivityTimer() {
        if (webViewController == nil) {
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
    
    private func ensureWebViewLoaded(waitForLoad: Bool = true, completion: @escaping (Result<Void, Error>) -> Void) {
        if isSessionStarted() {
            self.ensureWebViewController()
            self.resetInactivityTimer()
            
            if waitForLoad {
                webViewController?.loadWebView(completion: { result in
                    switch result {
                    case .success():
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                })
            } else {
                _ = webViewController?.loadWebView(completion: { _ in })
                completion(.success(()))
            }
        } else {
            completion(.success(()))
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
        return self.teamId
    }
    
    internal func getTeamIdAsync(completion: @escaping (String) -> Void) {
        if let teamId = self.teamId {
            completion(teamId)
        } else {
            DispatchQueue.global(qos: .utility).async {
                let id = self.getTeamIdViaSecurityFramework() ??
                    self.getTeamIdFromProvisioningProfile() ??
                    self.getTeamIdFromAccessGroups() ?? ""
                DispatchQueue.main.async {
                    self.teamId = id
                    completion(id)
                }
            }
        }
    }
    
    private func destroyWebView() {
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

extension ChaportSDK: ChaportWebViewControllerDelegate {
    public func webViewLinkClicked(url: URL) -> ChaportLinkAction {
        return delegate?.linkDidClick?(url: url) ?? .allow
    }
    public func webViewDidReceiveMessage(_ message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        let payload = message["payload"] as? [String : Any] ?? [:]
        let data = (payload["data"] ?? payload) as? [String : Any] ?? [:]
        
        switch action {
        case "ack":
            self.webViewController?.resolvePendingRequest(message: message)
            
        case "emit":
            if let event = payload["name"] as? String {
                
                switch event {
                case "chat.dismiss":
                    dismiss()

                case "chat.start":
                    delegate?.chatDidStart?()
                    self.startedBotId = nil
                    self.startedBotTimestamp = nil

                case "chat.denied":
                    let error = ChaportSDKError.chatDenied(payload: data.mapValues { value in
                        if let string = value as? String {
                            return string
                        } else {
                            return String(describing: value)
                        }
                    })
                    delegate?.chatDidFail?(error: error)

                case "chat.unreadChange":
                    if let unreadInfo = ChaportUnreadMessageInfo(from: data) {
                        // Swift delegate call (if implemented in Swift)
                        swiftDelegate?.unreadMessageDidChange(unreadInfo: unreadInfo)
                        
                        // Objective-C compatible delegate call (if implemented in ObjC)
                        delegate?.unreadMessageDidChange?(
                            count: unreadInfo.count,
                            lastMessageText: unreadInfo.lastMessageText,
                            lastMessageAuthor: unreadInfo.lastMessageAuthor?.asDictionary as NSDictionary?,
                            lastMessageAt: unreadInfo.lastMessageAt
                        )
                    } else {
                        ChaportLogger.log("Received unreadChange event with malformed payload", level: .warning)
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
        var payload: [String: Any]? = nil
        
        if let details = userCredentials {
            payload = ["id": details.id, "token": details.token]
        }
        
        self.webViewController?.startSession(payload: payload) { result in
            switch result {
            case .success():
                if self.visitorData != nil {
                    self.webViewController?.setVisitorData(visitorData: self.visitorData!, hash: self.visitorDataHash)
                }
                if self.startedBotId != nil && self.startedBotTimestamp != nil {
                    self.webViewController?.startBot(botId: self.startedBotId!, timestamp: self.startedBotTimestamp!)
                }
                completion(.success(()))

            case .failure(let error):
                completion(.failure(error))
                break
            }
        }
    }
}

class ClosureSleeve {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}
