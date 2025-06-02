import SwiftUI
import Chaport

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                EmbedBox(onReady: { controller, container in
                    viewModel.embedController = controller
                    viewModel.chatContainer = container
                })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0xB2/255, green: 0xB2/255, blue: 0xB2/255))

                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        OptionButton(label: "Present", action: viewModel.presentChat)
                        OptionButton(label: "Clear session", action: viewModel.clearSession)
                    }.padding(.top, 20)

                    HStack(spacing: 20) {
                        OptionButton(label: "Embed", action: viewModel.embedChat)
                        OptionButton(label: "FAQ", action: viewModel.openFAQ)
                    }

                    HStack(spacing: 20) {
                        OptionButton(
                            label: "Remove",
                            color: viewModel.isChatVisible ? nil : Color(red: 0xCC/255, green: 0xCC/255, blue: 0xD0/255),
                            action: viewModel.removeChat
                        )

                        HStack {
                            Text("Unread: \(viewModel.unreadCount)")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(6)
                        .background(viewModel.unreadCount == 0 ? Color(red: 0xCC/255, green: 0xCC/255, blue: 0xD0/255) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .background(Color.white)
            }
            .background(Color.white)
            .frame(alignment: .bottom)
        }
    }
}

struct OptionButton: View {
    var label: String
    var color: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).frame(maxWidth: .infinity)
        }
        .padding(6)
        .background(color ?? Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

struct EmbedBox: UIViewControllerRepresentable {
    var onReady: (UIViewController, UIView) -> Void

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
        
        onReady(containerVC, chatContainer)

        return containerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
