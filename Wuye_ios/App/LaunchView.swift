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
    
    // 修改setupIncomingCallObserver方法
    private func setupIncomingCallObserver() {
        print("[LaunchView-\(viewId)] 设置来电通知观察者")
        
        // 响应来电通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IncomingCallReceived"),
            object: nil,
            queue: .main
        ) { notification in
            print("[LaunchView-\(viewId)] 收到来电通知，准备显示来电界面")
            
            // 检查是否应该显示来电
            if let userInfo = notification.userInfo,
               let timestamp = userInfo["timestamp"] as? TimeInterval {
                
                // 检查通知是否最近的(5秒内)
                let isRecent = Date().timeIntervalSince1970 - timestamp < 5.0
                
                if !isRecent {
                    print("[LaunchView-\(viewId)] 忽略过期通知")
                    return
                }
            }
            
            // 检查是否有来电信息
            if self.callManager.incomingCall != nil {
                // 直接更新UI状态
                DispatchQueue.main.async {
                    self.showIncomingCall = true
                    print("[LaunchView-\(viewId)] 来电界面显示状态已更新: \(self.showIncomingCall)")
                }
            } else if let userInfo = notification.userInfo,
                      let caller = userInfo["caller"] as? String,
                      let number = userInfo["number"] as? String {
                
                // 从通知中恢复来电信息
                print("[LaunchView-\(viewId)] 从通知恢复来电信息: \(caller) - \(number)")
                self.callManager.handleIncomingCall(caller: caller, number: number)
                
                // 稍后更新UI以确保CallManager有时间处理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showIncomingCall = true
                    print("[LaunchView-\(viewId)] 延迟更新来电界面状态: \(self.showIncomingCall)")
                }
            } else {
                print("[LaunchView-\(viewId)] 警告: 无法获取来电信息")
            }
        }
        
        // 响应来电结束通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("IncomingCallEnded"),
            object: nil,
            queue: .main
        ) { _ in
            print("[LaunchView-\(viewId)] 收到来电结束通知，准备关闭来电界面")
            DispatchQueue.main.async {
                self.showIncomingCall = false
                print("[LaunchView-\(viewId)] 来电界面已关闭")
            }
        }
        
        // 添加系统通知响应
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        print("[LaunchView-\(viewId)] 通知观察者设置完成")
    }
}

// 添加通知代理类
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 显示通知
        completionHandler([.alert, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // 用户点击了通知
        let userInfo = response.notification.request.content.userInfo
        
        if response.notification.request.identifier.starts(with: "call-"),
           let caller = userInfo["caller"] as? String,
           let number = userInfo["number"] as? String {
            
            // 发布通知以显示来电界面
            NotificationCenter.default.post(
                name: NSNotification.Name("IncomingCallReceived"),
                object: nil,
                userInfo: [
                    "caller": caller,
                    "number": number,
                    "forceShow": true
                ]
            )
        }
        
        completionHandler()
    }
}

// MARK: - Preview
struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
            .environmentObject(AuthManager.shared)
            .environmentObject(CallManager.shared)
    }
}
