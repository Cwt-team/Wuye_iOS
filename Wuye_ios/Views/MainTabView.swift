import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页",   systemImage: "house.fill") }
            UnlockView()
                .tabItem { Label("开锁",   systemImage: "lock.open.fill") }
            ProfileView()
                .tabItem { Label("我的",   systemImage: "person.fill") }
        }
        .accentColor(.purple)
        .background(Color.white)
        .onAppear {
            print("MainTabView appeared - User logged in: \(authManager.isLoggedIn)")
        }
    }
}
