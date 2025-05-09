import Foundation

struct LoginResponse: Codable {
    let token: String
    let userId: Int
    let username: String
}
