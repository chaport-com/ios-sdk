import SwiftUI
import ChaportSDK

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Chaport.shared.setDeviceToken(deviceToken: tokenString)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for push: \(error.localizedDescription)")
    }
}
