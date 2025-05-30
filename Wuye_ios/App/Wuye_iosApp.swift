import SwiftUI
import Alamofire
import AVFoundation
import linphonesw
import AudioToolbox

// 全局自定义会话，用于所有API请求
var customSession: Session = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    
    // 添加默认请求头
    configuration.headers = .default
    
    // 创建会话
    return Session(configuration: configuration)
}()

@main
struct Wuye_iosApp: App {
    // 应用委托对象
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 创建应用级别的环境对象
    @StateObject private var authManager = AuthManager.shared
    
    // 使用延迟初始化，确保CallManager在适当的时机创建
    @StateObject private var callManager = CallManager.shared
    
    // 存储自定义会话，以便在app的整个生命周期中使用
    static let customSession: Session = {
        // 创建定制的会话配置
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        
        // 在开发环境中，允许自签名证书和无效证书
        let serverTrustManager = ServerTrustManager(evaluators: [
            "dev-api.wuye-app.com": DisabledTrustEvaluator(),
            "api.wuye-app.com": DefaultTrustEvaluator(),
            "127.0.0.1": DisabledTrustEvaluator(),
            "localhost": DisabledTrustEvaluator(),
            "192.168.1.21": DisabledTrustEvaluator()
        ])
        
        // 修复代理设置
        #if DEBUG
        ProxyHelper.shared.fixProxySettings(for: configuration)
        
        // 创建事件监视器
        let eventMonitor = APIEventMonitor()
        
        // 创建带事件监视器的会话
        return Session(
            configuration: configuration,
            serverTrustManager: serverTrustManager,
            eventMonitors: [eventMonitor]
        )
        #else
        // 生产环境不使用事件监视器
        return Session(
            configuration: configuration,
            serverTrustManager: serverTrustManager
        )
        #endif
    }()
    
    init() {
        // 应用程序初始化设置
        #if DEBUG
        print("� 应用程序启动中...")
        // 设置默认使用本地服务器（方便开发测试）
        UserDefaults.standard.set(true, forKey: "UseLocalServer")
        // 设置使用局域网IP地址
        UserDefaults.standard.set(true, forKey: "UseNetworkLocalServer")
        print("⚠️ 开发模式: 默认使用本地服务器 127.0.0.1:5000")
        // 检查并修复代理设置
        Self.configureNetworkProxy()
        // 配置SSL证书信任
        Self.configureSSLTrust()
        #endif
        
        // 为模拟器环境增加异常保护
        #if targetEnvironment(simulator)
        print("⚠️ 在模拟器环境中运行，某些功能（如音频）可能受限")
        #endif

        // 合并 UI 外观配置
        configureAppearance()
        // 合并 SIP 管理器初始化
        configureSipManager()
    }
    
    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(authManager)
                .environmentObject(callManager)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - 私有方法
    
    /// 配置网络代理设置
    private static func configureNetworkProxy() {
        // 设置URLSession的默认配置
        let config = URLSessionConfiguration.default
        ProxyHelper.shared.fixProxySettings(for: config)
        
        // 打印代理状态信息
        ProxyHelper.shared.checkSystemProxyStatus()
        
        // 在iOS平台上，我们只能通过ProxyHelper来处理HTTP代理设置
        // getFixedProxyDictionary方法已经过滤掉了iOS上不可用的代理设置
        
        // 打印提示信息
        #if DEBUG
        print("� 已完成网络代理配置检查，确保使用正确端口 (5000)")
        #endif
    }
    
    /// 配置SSL证书信任
    private static func configureSSLTrust() {
        #if DEBUG
        print("� 配置SSL证书信任...")
        print("✅ 已创建定制会话: timeoutInterval=60s, 已配置SSL证书信任策略")
        #endif
    }

    // MARK: - UI外观配置
    private func configureAppearance() {
        UINavigationBar.appearance().backgroundColor = .systemBackground
        UINavigationBar.appearance().tintColor = .systemBlue
        UITabBar.appearance().backgroundColor = .systemBackground
    }

    // MARK: - SIP管理器初始化
    private func configureSipManager() {
        let defaults = UserDefaults.standard
        let sipServer = defaults.string(forKey: "sipServer") ?? "116.198.199.38"
        let sipPort = defaults.string(forKey: "sipPort") ?? "5060"
        let sipUsername = defaults.string(forKey: "sipUsername") ?? ""
        let sipPassword = defaults.string(forKey: "sipPassword") ?? ""

        if !sipUsername.isEmpty {
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
