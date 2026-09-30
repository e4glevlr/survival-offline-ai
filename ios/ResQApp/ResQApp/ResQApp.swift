import SwiftUI
import ResQUI

@main
struct ResQApp: App {
    var body: some Scene {
        WindowGroup {
            ChatScreen(model: ChatViewModel(responder: DemoResponder()))
        }
    }
}
