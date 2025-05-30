import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var callManager: CallManager
    @StateObject private var sipManager = SipManager.shared
    
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
            
            // 可选：通话建立时弹出 CallView（你可以根据实际需求调整）
            // if callManager.state == .connected, let currentCall = sipManager.currentCall {
            //     CallView(
            //         callerName: callManager.currentCaller,
            //         callerNumber: callManager.currentNumber,
            //         isIncoming: false // 或根据实际情况判断
            //     )
            // }
        }
        .fullScreenCover(item: $callManager.incomingCall) { incoming in
            if let currentCall = SipManager.shared.currentCall {
                IncomingCallView(
                    call: currentCall,
                    callerName: incoming.name,
                    callerNumber: incoming.number
                )
            } else {
                EmptyView()
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
