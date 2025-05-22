import SwiftUI

struct WuyeApp: App {
    // 创建应用状态对象，供全app访问
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        // 配置应用外观
        configureAppearance()
        
        // 初始化SIP管理器
        configureSipManager()
    }
    
    var body: some Scene {
        WindowGroup {
            // 根据登录状态显示不同视图
            if authManager.isLoggedIn {
                MainTabView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
    
    // 配置应用外观
    private func configureAppearance() {
        // 设置导航栏样式
        UINavigationBar.appearance().backgroundColor = .systemBackground
        UINavigationBar.appearance().tintColor = .systemBlue
        
        // 设置TabBar样式
        UITabBar.appearance().backgroundColor = .systemBackground
    }
    
    // 配置SIP管理器
    private func configureSipManager() {
        // 读取配置
        let defaults = UserDefaults.standard
        let sipServer = defaults.string(for: .sipServer) ?? "sip.wuyeapp.com"
        let sipPort = defaults.string(for: .sipPort) ?? "5060"
        let sipUsername = defaults.string(for: .sipUsername) ?? ""
        let sipPassword = defaults.string(for: .sipPassword) ?? ""
        
        // 只有在有用户名的情况下才配置
        if !sipUsername.isEmpty {
            // 初始化SIP服务
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                SipManager.shared.configureSipAccount(
                    username: sipUsername,
                    password: sipPassword,
                    domain: sipServer,
                    port: sipPort,
                    transport: "UDP"
                )
            }
        }
        
        print("SIP管理器初始化完成")
    }
}

// UserDefaults Keys 扩展
extension UserDefaults {
    // 存储SIP配置的键
    enum Keys: String {
        case sipServer = "sipServer"
        case sipPort = "sipPort"
        case sipUsername = "sipUsername"
        case sipPassword = "sipPassword"
    }
    
    // 便利方法
    func string(for key: Keys) -> String? {
        return string(forKey: key.rawValue)
    }
    
    func set(_ value: String, for key: Keys) {
        set(value, forKey: key.rawValue)
    }
} 
