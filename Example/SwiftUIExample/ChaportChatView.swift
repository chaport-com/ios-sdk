import SwiftUI
import ChaportSDK

struct ChaportView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let sessionData: [String: Any] = ["persist": true]
            let config = Config(appId: "67ebdc851e966982eb469d50", session: sessionData, region: "ru")
            let user = UserDetails(name: "John Doe", email: "john@example.com", custom: ["age": 30])
            ChaportSDK.shared.configure(config: config)
            ChaportSDK.shared.setLanguage(languageCode: "ru")
            ChaportSDK.shared.setUserDefault(userDetails: user)
            ChaportSDK.shared.present(from: container)
        }

        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
