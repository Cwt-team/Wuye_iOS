import SwiftUI

struct ProfileView: View {
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 个人信息头
                VStack(spacing: 12) {
                    Image("avatar")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .padding(.top, 40)
                    Text(auth.currentUser?.name ?? "游客")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Text(auth.currentUser?.community ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: { /* 切换在线/隐身 */ }) {
                        Text("在线")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)

                Spacer()

                // 功能列表 & 退出登录
                List {
                    Section {
                        NavigationLink(destination: EmptyView()) {
                            Label("我的订单", systemImage: "cart.fill")
                        }
                        NavigationLink(destination: EmptyView()) {
                            Label("我的报事", systemImage: "wrench.fill")
                        }
                        NavigationLink(destination: EmptyView()) {
                            Label("设置", systemImage: "gear")
                        }
                    }
                    Section {
                        Button(action: {
                            auth.token = ""
                            auth.isLoggedIn = false
                        }) {
                            Label("退出登录", systemImage: "arrow.backward.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .accentColor(.purple)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
