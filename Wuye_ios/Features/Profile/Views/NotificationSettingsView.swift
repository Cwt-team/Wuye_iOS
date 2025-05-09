import SwiftUI
import UserNotifications

/// 通知设置视图
struct NotificationSettingsView: View {
    // 通知设置
    @State private var isAppNotificationsEnabled = false
    @State private var isSystemNotificationsEnabled = false
    @State private var isCallsEnabled = true
    @State private var isMessagesEnabled = true
    @State private var isMaintainenceEnabled = true
    @State private var isAnnouncementsEnabled = true
    @State private var isPaymentsEnabled = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            // 通知主开关
            Section(header: Text("通知设置")) {
                Toggle("应用内通知", isOn: $isAppNotificationsEnabled)
                    .onChange(of: isAppNotificationsEnabled) { newValue in
                        if newValue {
                            // 开启应用内通知不需要系统权限
                            updateLocalSetting("appNotifications", value: true)
                        } else {
                            // 关闭应用内通知
                            updateLocalSetting("appNotifications", value: false)
                        }
                    }
                
                Toggle("系统通知", isOn: $isSystemNotificationsEnabled)
                    .onChange(of: isSystemNotificationsEnabled) { newValue in
                        if newValue {
                            // 请求系统通知权限
                            requestNotificationPermission()
                        } else {
                            // 提示用户去系统设置中关闭通知
                            alertMessage = "请在系统设置中关闭物业APP的通知权限"
                            showingAlert = true
                            // 更新本地设置
                            updateLocalSetting("systemNotifications", value: false)
                        }
                    }
            }
            
            // 通知类型设置
            Section(header: Text("接收的通知类型")) {
                Toggle("来电通知", isOn: $isCallsEnabled)
                    .onChange(of: isCallsEnabled) { newValue in
                        updateLocalSetting("callNotifications", value: newValue)
                    }
                
                Toggle("消息通知", isOn: $isMessagesEnabled)
                    .onChange(of: isMessagesEnabled) { newValue in
                        updateLocalSetting("messageNotifications", value: newValue)
                    }
                
                Toggle("维修通知", isOn: $isMaintainenceEnabled)
                    .onChange(of: isMaintainenceEnabled) { newValue in
                        updateLocalSetting("maintainenceNotifications", value: newValue)
                    }
                
                Toggle("公告通知", isOn: $isAnnouncementsEnabled)
                    .onChange(of: isAnnouncementsEnabled) { newValue in
                        updateLocalSetting("announcementNotifications", value: newValue)
                    }
                
                Toggle("缴费通知", isOn: $isPaymentsEnabled)
                    .onChange(of: isPaymentsEnabled) { newValue in
                        updateLocalSetting("paymentNotifications", value: newValue)
                    }
            }
            
            // 通知提示
            Section(footer: Text("部分通知（如来电通知）需要始终保持开启状态，以确保您不会错过重要信息。")) {
                // 空的section，只显示footer
            }
        }
        .navigationTitle("通知设置")
        .onAppear(perform: loadSettings)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("通知设置"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 加载已保存的设置
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // 获取应用内通知设置
        isAppNotificationsEnabled = defaults.bool(forKey: "appNotifications")
        
        // 检查系统通知权限
        checkNotificationPermission()
        
        // 获取各类通知设置
        isCallsEnabled = defaults.bool(forKey: "callNotifications")
        isMessagesEnabled = defaults.bool(forKey: "messageNotifications")
        isMaintainenceEnabled = defaults.bool(forKey: "maintainenceNotifications")
        isAnnouncementsEnabled = defaults.bool(forKey: "announcementNotifications")
        isPaymentsEnabled = defaults.bool(forKey: "paymentNotifications")
    }
    
    // 更新本地设置
    private func updateLocalSetting(_ key: String, value: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    // 用户允许通知
                    self.isSystemNotificationsEnabled = true
                    self.updateLocalSetting("systemNotifications", value: true)
                } else {
                    // 用户拒绝通知
                    self.isSystemNotificationsEnabled = false
                    self.alertMessage = "请在系统设置中开启物业APP的通知权限，以接收重要通知"
                    self.showingAlert = true
                }
            }
        }
    }
    
    // 检查通知权限
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isSystemNotificationsEnabled = settings.authorizationStatus == .authorized
                self.updateLocalSetting("systemNotifications", value: self.isSystemNotificationsEnabled)
            }
        }
    }
}

// 预览
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingsView()
        }
    }
} 