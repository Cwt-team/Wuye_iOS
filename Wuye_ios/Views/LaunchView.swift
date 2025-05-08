import SwiftUI

struct LaunchView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showAPITest = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
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

// MARK: - Preview
struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
            .environmentObject(AuthManager.shared)
    }
}
