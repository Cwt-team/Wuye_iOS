import Foundation

struct LoginResponse: Codable {
    let success: Bool
    let message: String
    let ownerInfo: OwnerInfo?
}

struct OwnerInfo: Codable {
    let id: Int
    let name: String
    let phoneNumber: String
    let account: String
    let communityId: Int?
    let houseId: Int?
}
