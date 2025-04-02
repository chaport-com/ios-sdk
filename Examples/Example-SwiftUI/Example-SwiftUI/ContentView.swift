import SwiftUI
import ChaportSDK

struct ContentView: View {
    @State private var isStart = false
    @State private var unread = 0
        
    let chatWindowDelegate = ChatWindow.Delegate()
    var body: some View {
        ZStack {
            VStack {
                if isStart {
                    EmbedView()
                }
                Spacer()
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        OptionButton(label: "Present", action: {
                            isStart = false
                            Chaport.shared.present(from: UIApplication.shared.windows.first!.rootViewController!)
                        })
                        OptionButton(label: "Clear session", action: {
                            Chaport.shared.stopSession()
                            isStart = false
                            unread = 0
                        })
                    }
                    .padding(.top, 20)
                    
                    HStack(spacing: 20) {
                        OptionButton(label: "Embed", action: {
                            isStart = true
                        })
                        OptionButton(label: "FAQ", action: {
                            isStart = true
                            Chaport.shared.openFAQ()
                        })
                    }
                    
                    HStack(spacing: 20) {
                        OptionButton(label: "Remove", action: {
                            Chaport.shared.remove()
                            isStart = false
                            unread = 0
                        })
                        HStack {
                            Text("Unread: \(unread)").frame(maxWidth: .infinity)
                        }
                        .padding(6)
                        .background(Color.blue)
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
        ChatWindow.setup(with: chatWindowDelegate)
    }
    
    private func setUnread(count: Int) {
        unread = count
    }
}

struct OptionButton: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).frame(maxWidth: .infinity)
        }
        .padding(6)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
