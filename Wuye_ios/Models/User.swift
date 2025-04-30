import Foundation
import GRDB

// 注意：该文件已被移动到统一模型文件，仅保留此处定义以兼容现有代码
struct User: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64
    var username: String
    var password: String
    var phone: String
    var email: String
    var address: String
    var avatarURL: String?
    var community: String?
    
    // 同步状态 - 用于本地数据同步
    var syncStatus: String = "synced" // synced, pending, deleted
    
    // 时间戳
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // 表名
    static let databaseTableName = "users"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id, username, password, phone, email, address
        case avatarURL = "avatar_url"
        case community
        case syncStatus = "sync_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 初始化方法 - 完整初始化
    init(id: Int64, username: String, password: String, phone: String, email: String, address: String, 
         avatarURL: String? = nil, community: String? = nil, syncStatus: String = "synced",
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.username = username
        self.password = password
        self.phone = phone
        self.email = email
        self.address = address
        self.avatarURL = avatarURL
        self.community = community
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 从OwnerInfo转换的初始化方法
    init(from ownerInfo: Models.AdminLoginResponse.OwnerInfo) {
        self.id = ownerInfo.id
        self.username = ownerInfo.username
        self.password = "" // 不存储密码
        self.phone = ownerInfo.phone
        self.email = ownerInfo.email ?? ""
        self.address = ownerInfo.address ?? ""
        self.avatarURL = nil
        self.community = nil
        self.syncStatus = "synced"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 标记为已同步
    mutating func markAsSynced() {
        syncStatus = "synced"
        updatedAt = Date()
    }
    
    // 标记为待同步
    mutating func markAsPending() {
        syncStatus = "pending"
        updatedAt = Date()
    }
    
    // 标记为已删除
    mutating func markAsDeleted() {
        syncStatus = "deleted"
        updatedAt = Date()
    }
    
    // 更新用户信息
    mutating func update(with user: User) {
        // 保留ID
        username = user.username
        phone = user.phone
        email = user.email
        address = user.address
        avatarURL = user.avatarURL
        community = user.community
        // 不更新密码，除非明确设置
        if !user.password.isEmpty {
            password = user.password
        }
        updatedAt = Date()
    }
}

// MARK: - 用于GRDB的表定义
extension User {
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("username", .text).notNull()
            t.column("password", .text).notNull()
            t.column("phone", .text).notNull().indexed()
            t.column("email", .text).notNull()
            t.column("address", .text).notNull()
            t.column("avatar_url", .text)
            t.column("community", .text)
            t.column("sync_status", .text).notNull().defaults(to: "synced")
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
    }
}
