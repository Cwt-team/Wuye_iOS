import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            HomeView()
                .environmentObject(authManager)
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            UnlockView()
                .environmentObject(authManager)
                .tabItem {
                    Label("开锁", systemImage: "lock.open.fill")
                }
            
            ProfileView()
                .environmentObject(authManager)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager.shared)
    }
}
