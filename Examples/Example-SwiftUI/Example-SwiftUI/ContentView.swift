import SwiftUI
import Chaport

struct ContentView: View {
    @State private var isStart = false
    @State private var unread = 0
        
    let chatWindowDelegate = ChatWindow.Delegate()
    var body: some View {
        ZStack {
            VStack {
                EmbedView()
                Spacer()
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        OptionButton(label: "Present", action: {
                            ChaportSDK.shared.present()
                        })
                        OptionButton(label: "Clear session", action: {
                            ChaportSDK.shared.stopSession()
                        })
                    }
                    .padding(.top, 20)
                    
                    HStack(spacing: 20) {
                        OptionButton(label: "Embed", action: {
                            if let vc = EmbedBox.lastCreatedController,
                               let chatContainer = EmbedBox.lastChatContainer {
                                ChaportSDK.shared.embed(into: chatContainer, parentViewController: vc)
                            }
                        })
                        OptionButton(label: "FAQ", action: {
                            if let vc = EmbedBox.lastCreatedController,
                               let chatContainer = EmbedBox.lastChatContainer {
                                ChaportSDK.shared.embed(into: chatContainer, parentViewController: vc)
                                ChaportSDK.shared.openFAQ()
                            }
                        })
                    }
                    
                    HStack(spacing: 20) {
                        OptionButton(label: "Remove", color: !isStart ? Color(red: 0xCC/255, green: 0xCC/255, blue: 0xD0/255) : nil, action: {
                            ChaportSDK.shared.remove()
                        })
                        HStack {
                            Text("Unread: \(unread)").frame(maxWidth: .infinity)
                        }
                        .padding(6)
                        .background(unread == 0 ? Color(red: 0xCC/255, green: 0xCC/255, blue: 0xD0/255) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .background(Color.white)
            }
            .background(Color(red: 0xEF/255, green: 0xEF/255, blue: 0xF3/255))
            .frame(alignment: .bottom)
        }
        .onAppear(perform: setupChatWindow)
    }
    
    private func setupChatWindow() {
        chatWindowDelegate.onSetUnread = setUnread
        chatWindowDelegate.onSetStart = setStart
        ChatWindow.setup(with: chatWindowDelegate)
    }
    
    private func setUnread(count: Int) {
        unread = count
    }
    
    private func setStart(start: Bool) {
        isStart = start
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
