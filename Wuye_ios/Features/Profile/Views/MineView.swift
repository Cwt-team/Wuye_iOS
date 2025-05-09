import SwiftUI

// 我的页面
struct MineView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSIPSettings = false
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // 个人信息部分
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            if let user = authManager.currentUser {
                                Text(user.username)
                                    .font(.headline)
                                
                                Text(user.phone)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            } else {
                                Text("加载中...")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                
                // 设置部分
                Section(header: Text("设置")) {
                    NavigationLink(destination: ProfileSettingsView()) {
                        MineSettingRow(icon: "person.fill", iconColor: .blue, text: "个人资料", action: {})
                    }
                    
                    NavigationLink(destination: NotificationSettingsView()) {
                        MineSettingRow(icon: "bell.fill", iconColor: .orange, text: "通知设置", action: {})
                    }
                    
                    NavigationLink(destination: PreferencesView()) {
                        MineSettingRow(icon: "gearshape.fill", iconColor: .gray, text: "偏好设置", action: {})
                    }
                    
                    Button(action: {
                        showSIPSettings = true
                    }) {
                        MineSettingRow(icon: "phone.fill", iconColor: .green, text: "SIP通话设置", action: {
                            showSIPSettings = true
                        })
                    }
                }
                
                // 支持部分
                Section(header: Text("支持")) {
                    NavigationLink(destination: HelpCenterView()) {
                        MineSettingRow(icon: "questionmark.circle.fill", iconColor: .purple, text: "帮助中心", action: {})
                    }
                    
                    NavigationLink(destination: FeedbackView()) {
                        MineSettingRow(icon: "exclamationmark.bubble.fill", iconColor: .pink, text: "意见反馈", action: {})
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        MineSettingRow(icon: "info.circle.fill", iconColor: .blue, text: "关于我们", action: {})
                    }
                }
                
                // 退出登录部分
                Section {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showSIPSettings) {
                SIPSettingsView()
            }
            .alert(isPresented: $showLogoutConfirmation) {
                Alert(
                    title: Text("确认退出"),
                    message: Text("您确定要退出登录吗？"),
                    primaryButton: .destructive(Text("退出"), action: logout),
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
    
    // 退出登录
    private func logout() {
        authManager.logout()
    }
}

// 设置行视图
struct MineSettingRow: View {
    var icon: String
    var iconColor: Color
    var text: String
    var showBadge: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
                
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(Color(.label))
                    .padding(.leading, 6)
                
                Spacer()
                
                if showBadge {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.vertical, 12)
        }
    }
}

// 预览
struct MineView_Previews: PreviewProvider {
    static var previews: some View {
        MineView()
            .environmentObject(AuthManager.shared)
    }
} 