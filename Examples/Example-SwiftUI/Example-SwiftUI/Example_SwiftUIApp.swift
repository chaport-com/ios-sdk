import SwiftUI
import ChaportSDK

@main
struct Example_SwiftUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestPushPermissions()
                }
        }
    }
    
    private func requestPushPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        ChaportSDK.shared.handlePushNotification(notification: notification.request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if ChaportSDK.shared.isChaportPushNotification(notification: response.notification.request) {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController,
               let topVC = ChaportSDK.shared.topMostViewController(from: rootVC) {
                ChaportSDK.shared.present(from: topVC)
            }
        }

        completionHandler()
    }
}
