import Foundation

/// 认证响应模型
struct AuthResponse: Codable {
    let success: Bool
    let message: String?
    let token: String?
}

// 用户认证响应
struct UserResponse: Codable {
    let success: Bool
    let message: String?
    let user: User
}

// 后台管理系统登录响应模型
struct AdminLoginResponse: Codable {
    let success: Bool
    let message: String?
    let ownerInfo: OwnerInfo?
    
    // 业主信息结构，匹配后台API返回
    struct OwnerInfo: Codable {
        let id: Int64
        let name: String
        let phoneNumber: String
        let account: String
        let communityId: Int64?
        let houseId: Int64?
        let username: String
        let phone: String
        let email: String?
        let address: String?
        
        enum CodingKeys: String, CodingKey {
            case id, name, phoneNumber, account, communityId, houseId
            case username, phone, email, address
        }
    }
}

// 注意：此函数应该被移动到AuthManager或APIService中
// 这里暂时注释掉，避免重复声明
/*
func requestLoginCode(phone: String, completion: @escaping (Result<EmptyResponse, APIError>) -> Void) {
    let endpoint = "/auth/send_code"
    APIService.shared.request(endpoint: endpoint, method: .post, body: ["phone": phone], completion: completion)
}
*/

