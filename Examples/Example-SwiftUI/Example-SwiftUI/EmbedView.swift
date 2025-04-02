import SwiftUI

struct EmbedBox: UIViewControllerRepresentable {
    static weak var lastCreatedController: UIViewController?
    static weak var lastChatContainer: UIView?

    func makeUIViewController(context: Context) -> UIViewController {
        let containerVC = UIViewController()

        let chatContainer = UIView()
        chatContainer.translatesAutoresizingMaskIntoConstraints = false

        containerVC.view.addSubview(chatContainer)

        NSLayoutConstraint.activate([
            chatContainer.topAnchor.constraint(equalTo: containerVC.view.topAnchor),
            chatContainer.leadingAnchor.constraint(equalTo: containerVC.view.leadingAnchor),
            chatContainer.trailingAnchor.constraint(equalTo: containerVC.view.trailingAnchor),
            chatContainer.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor)
        ])

        EmbedBox.lastCreatedController = containerVC
        EmbedBox.lastChatContainer = chatContainer

        return containerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct EmbedView: View {
    var body: some View {
        EmbedBox()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.2))
    }
}
