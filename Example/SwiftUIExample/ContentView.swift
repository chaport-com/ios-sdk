#if canImport(SwiftUI) && !os(macOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_13_0
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink("Открыть Chaport Чат", destination: ChaportChatView())
                    .padding()
            }
            .navigationTitle("Chaport SDK Example")
        }
    } 
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
