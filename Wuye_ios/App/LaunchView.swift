import SwiftUI

struct LaunchView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var callManager: CallManager
    @State private var showAPITest = false
    @State private var showIncomingCall = false
    
    // 添加控制台标识，便于调试
    private let viewId = UUID().uuidString.prefix(6)

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(callManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
                    .environmentObject(callManager)
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
            print("[LaunchView-\(viewId)] 视图出现")
            authManager.checkAuthStatus()
            
            // 添加对callManager.incomingCall的观察
            setupIncomingCallObserver()
            
            // 如果已经有来电，立即显示
            if callManager.incomingCall != nil {
                print("[LaunchView-\(viewId)] 视图出现时检测到来电，立即显示来电界面")
                self.showIncomingCall = true
            }
        }
        .onDisappear {
            // 移除观察者，避免内存泄漏
            print("[LaunchView-\(viewId)] 视图消失，移除通知观察者")
            NotificationCenter.default.removeObserver(self)
        }
        .sheet(isPresented: $showAPITest) {
            APITestView()
        }
        .sheet(isPresented: $showIncomingCall) {
            if let call = callManager.incomingCall {
                IncomingCallView(
                    callerName: call.name,
                    callerNumber: call.number
                )
                .environmentObject(callManager)
            } else {
                // 没有来电信息，显示错误界面
                VStack {
                    Text("错误：无法获取来电信息")
                        .foregroundColor(.red)
                    Button("关闭") {
                        self.showIncomingCall = false
                    }
                    .padding()
                }
            }
        }
    }
    
    // 单独设置来电观察器
    private func setupIncomingCallObserver() {
        // 使用NotificationCenter来监听来电状态变化
        print("[LaunchView-\(viewId)] 设置来电通知观察者")
        
        // 响应来电通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IncomingCallReceived"), 
            object: nil, 
            queue: .main
        ) { notification in
            print("[LaunchView-\(viewId)] 收到来电通知，准备显示来电界面")
            
            // 如果userInfo中有来电信息，打印它
            if let userInfo = notification.userInfo,
               let caller = userInfo["caller"] as? String,
               let number = userInfo["number"] as? String {
                print("[LaunchView-\(viewId)] 来电信息: \(caller) - \(number)")
            }
            
            // 再次检查是否有来电信息
            if self.callManager.incomingCall != nil {
                self.showIncomingCall = true
                print("[LaunchView-\(viewId)] 来电界面显示状态已更新: \(self.showIncomingCall)")
            } else {
                print("[LaunchView-\(viewId)] 警告: 收到来电通知但callManager.incomingCall为nil")
            }
        }
        
        // 响应来电结束通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IncomingCallEnded"), 
            object: nil, 
            queue: .main
        ) { _ in
            print("[LaunchView-\(viewId)] 收到来电结束通知，准备关闭来电界面")
            self.showIncomingCall = false
            print("[LaunchView-\(viewId)] 来电界面已关闭")
        }
        
        print("[LaunchView-\(viewId)] 通知观察者设置完成")
    }
}

// MARK: - Preview
struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
            .environmentObject(AuthManager.shared)
            .environmentObject(CallManager())
    }
}
