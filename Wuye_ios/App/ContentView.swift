import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var callManager: CallManager
    
    var body: some View {
        ZStack {
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
        .sheet(isPresented: Binding<Bool>(
            get: { callManager.incomingCall != nil },
            set: { if !$0 { callManager.clearIncomingCall() } }
        )) {
            if let call = callManager.incomingCall {
                IncomingCallView(
                    callerName: call.name,
                    callerNumber: call.number
                )
                .environmentObject(callManager)
                }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager.shared)
            .environmentObject(CallManager.shared)
    }
}
