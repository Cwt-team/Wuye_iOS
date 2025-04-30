import SwiftUI

struct LaunchView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showAPITest = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
            } else {
                LoginView()
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    showAPITest.toggle()
                                }) {
                                    Image(systemName: "network")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .padding(12)
                                        .background(Color(.systemBackground).opacity(0.8))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    )
            }
        }
        .onAppear {
            authManager.checkAuthStatus()
        }
        .sheet(isPresented: $showAPITest) {
            APITestView()
        }
    }
}
