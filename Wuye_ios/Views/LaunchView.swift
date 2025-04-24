import SwiftUI

struct LaunchView: View {
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            auth.isLoggedIn = !auth.token.isEmpty
        }
    }
}
