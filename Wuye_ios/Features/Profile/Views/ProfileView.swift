import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    @State private var showAPITest = false
    @State private var showSipTest = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if let user = authManager.currentUser {
                        HStack(spacing: 15) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(user.username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(user.phone)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 10)
                    } else {
                        Text("用户信息加载中...")
                    }
                }
                
                Section(header: Text("账号设置")) {
                    NavigationLink(destination: Text("修改个人信息")) {
                        ProfileSettingRow(icon: "person.fill", title: "个人信息", color: .blue)
                    }
                    
                    NavigationLink(destination: Text("修改密码")) {
                        ProfileSettingRow(icon: "lock.fill", title: "密码设置", color: .green)
                    }
                }
                
                Section(header: Text("系统设置")) {
                    NavigationLink(destination: Text("系统通知设置")) {
                        ProfileSettingRow(icon: "bell.fill", title: "通知设置", color: .orange)
                    }
                    
                    NavigationLink(destination: EmptyView(), isActive: $showAPITest) {
                        Button(action: {
                            showAPITest = true
                        }) {
                            ProfileSettingRow(icon: "network", title: "API测试", color: .purple)
                        }
                    }
                    
                    NavigationLink(destination: SipTestView(), isActive: $showSipTest) {
                        Button(action: {
                            showSipTest = true
                        }) {
                            ProfileSettingRow(icon: "phone.fill", title: "SIP设置", color: .green)
                        }
                    }
                }
                
                Section {
                    Button(action: { showLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.red)
                                .frame(width: 25, height: 25)
                            Text("退出登录")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("个人中心")
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("确认退出"),
                    message: Text("您确定要退出当前账号吗？"),
                    primaryButton: .destructive(Text("退出")) {
                        authManager.logout()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .sheet(isPresented: $showAPITest) {
                APITestView()
            }
        }
    }
}

struct ProfileSettingRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 25, height: 25)
            Text(title)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthManager.shared)
    }
}
