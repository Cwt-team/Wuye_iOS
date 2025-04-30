import Foundation

/// 代理帮助工具，用于处理iOS应用网络代理设置
class ProxyHelper {
    
    /// 单例
    static let shared = ProxyHelper()
    
    /// 私有初始化方法
    private init() {}
    
    /// 修复URLSessionConfiguration的代理设置
    /// - Parameter configuration: 要修复的配置
    func fixProxySettings(for configuration: URLSessionConfiguration) {
        #if DEBUG
        if let proxySettings = configuration.connectionProxyDictionary {
            var updatedProxySettings = proxySettings
            var isChanged = false
            
            // 检查HTTP代理
            if let httpProxy = proxySettings[kCFNetworkProxiesHTTPProxy] as? String,
               httpProxy == "127.0.0.1",
               let httpPort = proxySettings[kCFNetworkProxiesHTTPPort] as? Int,
               httpPort == 7897 {
                updatedProxySettings[kCFNetworkProxiesHTTPPort] = 8080
                isChanged = true
                print("⚠️ 检测到错误的HTTP代理端口(7897)，已修改为8080")
            }
            
            // 我们无法在iOS上直接访问HTTPS和SOCKS代理设置常量，因为这些常量在iOS SDK中不可用
            // 注意：kCFNetworkProxiesHTTPSProxy等常量只在macOS中存在，iOS中不能使用
            
            if isChanged {
                configuration.connectionProxyDictionary = updatedProxySettings
                printProxyStatus(with: updatedProxySettings)
            } else {
                printProxyStatus(with: proxySettings)
            }
        } else {
            print("ℹ️ 未检测到代理设置")
        }
        #endif
    }
    
    /// 获取修复后的代理设置
    /// - Returns: 修复后的代理设置字典
    func getFixedProxyDictionary() -> [AnyHashable: Any]? {
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [AnyHashable: Any] else {
            print("⚠️ 无法获取系统代理设置")
            return nil
        }
        
        var updatedDict = cfDict
        var isChanged = false
        
        #if DEBUG
        // 检查HTTP代理
        let httpProxyKey = kCFNetworkProxiesHTTPProxy as String
        let httpPortKey = kCFNetworkProxiesHTTPPort as String
        
        if let httpProxy = cfDict[httpProxyKey] as? String,
           httpProxy == "127.0.0.1",
           let httpPort = cfDict[httpPortKey] as? Int,
           httpPort == 7897 {
            updatedDict[httpPortKey] = 8080
            isChanged = true
            print("⚠️ 已修改系统HTTP代理端口：7897 -> 8080")
        }
        
        // 在iOS平台上，只处理HTTP代理设置
        #endif
        
        if isChanged {
            printProxyStatus(with: updatedDict)
            return updatedDict
        } else {
            printProxyStatus(with: cfDict)
            return cfDict
        }
    }
    
    /// 检查系统代理状态
    func checkSystemProxyStatus() {
        #if DEBUG
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [AnyHashable: Any] {
            print("🔍 系统代理状态检查:")
            printProxyStatus(with: proxySettings)
        } else {
            print("⚠️ 无法获取系统代理设置信息")
        }
        #endif
    }
    
    /// 打印代理状态信息
    /// - Parameter settings: 代理设置
    private func printProxyStatus(with settings: [AnyHashable: Any]) {
        #if DEBUG
        print("📱 当前代理配置状态:")
        
        // 定义键
        let httpEnableKey = kCFNetworkProxiesHTTPEnable as String
        let httpProxyKey = kCFNetworkProxiesHTTPProxy as String
        let httpPortKey = kCFNetworkProxiesHTTPPort as String
        
        // 检查HTTP代理
        if let httpEnabled = settings[httpEnableKey] as? Bool, httpEnabled,
           let httpProxy = settings[httpProxyKey] as? String,
           let httpPort = settings[httpPortKey] as? Int {
            print("   HTTP代理: \(httpProxy):\(httpPort)")
        } else {
            print("   HTTP代理: 未启用")
        }
        
        // 其他代理信息根据需要添加
        #endif
    }
} 