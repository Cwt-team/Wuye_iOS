import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showingLogoutAlert = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部用户信息区
                    userHeaderView
                    
                    // 设置项目分组
                    settingGroupsView
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "完成" : "编辑")
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert(isPresented: $showingLogoutAlert) {
                Alert(
                    title: Text("确认退出登录"),
                    message: Text("您确定要退出当前账号吗？"),
                    primaryButton: .destructive(Text("退出")) {
                        authManager.logout()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
    
    // 用户头像与基本信息
    private var userHeaderView: some View {
        VStack(spacing: 15) {
            if let user = authManager.currentUser {
                // 头像
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                        AsyncImage(url: URL(string: avatarURL)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    
                    // 编辑按钮
                    if isEditing {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 35, y: 35)
                    }
                }
                .padding(.top, 20)
                
                // 用户名
                Text(user.username)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 手机号
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                    Text(user.phone)
                        .foregroundColor(.secondary)
                }
                
                // 邮箱
                if !user.email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.secondary)
                        Text(user.email)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // 未登录状态
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .padding(.top, 20)
                
                Text("未登录")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Button("点击登录") {
                    authManager.logout() // 强制退出到登录页
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 25)
        .background(colorScheme == .dark ? Color(.systemBackground) : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // 设置项目分组
    private var settingGroupsView: some View {
        VStack(spacing: 20) {
            // 基本信息组
            SettingsGroupView(title: "基本信息", items: [
                SettingItem(icon: "house.fill", title: "我的房屋", iconColor: .blue),
                SettingItem(icon: "person.text.rectangle.fill", title: "个人资料", iconColor: .purple),
                SettingItem(icon: "key.fill", title: "修改密码", iconColor: .orange)
            ])
            
            // 服务组
            SettingsGroupView(title: "服务中心", items: [
                SettingItem(icon: "wrench.and.screwdriver.fill", title: "报修记录", iconColor: .red),
                SettingItem(icon: "creditcard.fill", title: "缴费记录", iconColor: .green),
                SettingItem(icon: "bell.fill", title: "通知中心", iconColor: .cyan),
                SettingItem(icon: "questionmark.circle.fill", title: "帮助与反馈", iconColor: .yellow)
            ])
            
            // 系统设置组
            SettingsGroupView(title: "系统设置", items: [
                SettingItem(icon: "gear", title: "通用设置", iconColor: .gray),
                SettingItem(icon: "hand.raised.fill", title: "隐私设置", iconColor: .indigo),
                SettingItem(icon: "info.circle.fill", title: "关于我们", iconColor: .teal)
            ])
            
            // 退出登录按钮
            if authManager.currentUser != nil {
                Button(action: {
                    showingLogoutAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("退出登录")
                            .foregroundColor(.red)
                            .padding(.vertical, 15)
                        Spacer()
                    }
                    .background(colorScheme == .dark ? Color(.systemBackground) : Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .padding(.top, 10)
    }
}

// 设置项组视图
struct SettingsGroupView: View {
    let title: String
    let items: [SettingItem]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 5)
            
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    NavigationLink(destination: Text(items[index].title)) {
                        SettingItemView(item: items[index])
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(colorScheme == .dark ? Color(.systemBackground) : Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .padding(.horizontal)
        }
    }
}

// 设置项模型
struct SettingItem {
    let icon: String
    let title: String
    let iconColor: Color
}

// 单个设置项视图
struct SettingItemView: View {
    let item: SettingItem
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: item.icon)
                .foregroundColor(item.iconColor)
                .frame(width: 25, height: 25)
                .padding(.leading, 10)
            
            Text(item.title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.trailing, 15)
        }
        .padding(.vertical, 12)
    }
}
