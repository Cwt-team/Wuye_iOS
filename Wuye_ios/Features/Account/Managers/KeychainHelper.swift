import Foundation
import Security

/// 钥匙串错误类型
enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidItemFormat
    case unexpectedStatus(OSStatus)
}

/// 钥匙串助手类
class KeychainHelper {
    // 单例
    static let shared = KeychainHelper()
    private init() {}
    
    // MARK: - 公共方法
    
    /// 保存字符串到钥匙串
    /// - Parameters:
    ///   - string: 要保存的字符串
    ///   - service: 服务标识符
    ///   - account: 账户标识符
    /// - Returns: 保存结果
    @discardableResult
    func save(_ string: String, service: String, account: String) -> Result<Void, KeychainError> {
        // 将字符串转换为数据
        guard let data = string.data(using: .utf8) else {
            return .failure(.invalidItemFormat)
        }
        
        // 准备查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // 检查项目是否已存在
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // 更新现有项目
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                return .failure(.unexpectedStatus(updateStatus))
            }
        } else if status == errSecItemNotFound {
            // 创建新项目
            var newQuery = query
            newQuery[kSecValueData as String] = data
            newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                return .failure(.unexpectedStatus(addStatus))
            }
        } else {
            return .failure(.unexpectedStatus(status))
        }
        
        return .success(())
    }
    
    /// 从钥匙串获取字符串
    /// - Parameters:
    ///   - service: 服务标识符
    ///   - account: 账户标识符
    /// - Returns: 存储的字符串，如果不存在则返回nil
    func get(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// 从钥匙串删除项目
    /// - Parameters:
    ///   - service: 服务标识符
    ///   - account: 账户标识符
    /// - Returns: 删除结果
    @discardableResult
    func delete(service: String, account: String) -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return .success(())
        } else {
            return .failure(.unexpectedStatus(status))
        }
    }
    
    /// 更新钥匙串中的字符串
    /// - Parameters:
    ///   - string: 新的字符串值
    ///   - service: 服务标识符
    ///   - account: 账户标识符
    /// - Returns: 更新结果
    @discardableResult
    func update(_ string: String, service: String, account: String) -> Result<Void, KeychainError> {
        // 如果项目不存在，则创建它
        guard get(service: service, account: account) != nil else {
            return save(string, service: service, account: account)
        }
        
        guard let data = string.data(using: .utf8) else {
            return .failure(.invalidItemFormat)
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            return .failure(.unexpectedStatus(status))
        }
        
        return .success(())
    }
    
    /// 检查项目是否存在于钥匙串中
    /// - Parameters:
    ///   - service: 服务标识符
    ///   - account: 账户标识符
    /// - Returns: 是否存在
    func exists(service: String, account: String) -> Bool {
        return get(service: service, account: account) != nil
    }
    
    /// 清除钥匙串中所有与当前应用相关的项目
    /// - Returns: 清除结果
    @discardableResult
    func clearAll() -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return .success(())
        } else {
            return .failure(.unexpectedStatus(status))
        }
    }
}
