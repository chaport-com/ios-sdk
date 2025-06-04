import SwiftUI
import Chaport

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        window = UIWindow(frame: UIScreen.main.bounds)

            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            guard let rootVC = storyboard.instantiateInitialViewController() else {
                fatalError("Не удалось загрузить Initial View Controller из Main.storyboard")
            }

            window?.rootViewController = rootVC
            window?.makeKeyAndVisible()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        ChaportSDK.shared.setDeviceToken(deviceToken: tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for push: \(error.localizedDescription)")
    }
    
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
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if ChaportSDK.shared.isChaportPushNotification(notification: response.notification.request) {
            if (!ChaportSDK.shared.isChatVisible()) {
                DispatchQueue.main.async {
                    ChaportSDK.shared.present()
                }
            }
        }

        completionHandler()
    }
}
