import Foundation
import GRDB

// ========== BaseModel 协议与扩展（由 BaseModel.swift 迁移而来） ==========

/// 数据库模型基础协议
protocol BaseModel: Codable, FetchableRecord, PersistableRecord {
    /// 同步状态 (synced/pending/deleted)
    var syncStatus: String? { get set }
}

/// 基础模型的默认实现
extension BaseModel {
    func markAsCreated() {
        var model = self
        model.syncStatus = "created"
    }
    
    func markAsUpdated() {
        var model = self
        model.syncStatus = "updated"
    }
    
    func markAsDeleted() {
        var model = self
        model.syncStatus = "deleted"
    }
}

/// GRDB的列名辅助类型
extension GRDB.Column { }

// MARK: - 物业模型
struct Property: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var name: String
    var address: String
    var userId: Int64
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "properties"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id, name, address
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, name: String, address: String, userId: Int64,
         createdAt: Date = Date(), updatedAt: Date = Date(),
         syncStatus: String = "synced") {
        self.id = id
        self.name = name
        self.address = address
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 门禁模型
struct Door: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var propertyId: Int64
    var name: String
    var doorCode: String
    var doorType: String
    var isActive: Bool
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "doors"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case name, doorCode = "door_code"
        case doorType = "door_type"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, propertyId: Int64, name: String,
         doorCode: String, doorType: String = "main",
         isActive: Bool = true, createdAt: Date = Date(),
         updatedAt: Date = Date(), syncStatus: String = "synced") {
        self.id = id
        self.propertyId = propertyId
        self.name = name
        self.doorCode = doorCode
        self.doorType = doorType
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 解锁记录模型
struct UnlockRecord: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var doorId: Int64
    var userId: Int64
    var unlockTime: Date
    var unlockMethod: String
    var isSuccess: Bool
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "unlock_records"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id
        case doorId = "door_id"
        case userId = "user_id"
        case unlockTime = "unlock_time"
        case unlockMethod = "unlock_method"
        case isSuccess = "is_success"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, doorId: Int64, userId: Int64,
         unlockTime: Date = Date(), unlockMethod: String = "app",
         isSuccess: Bool = true, createdAt: Date = Date(),
         updatedAt: Date = Date(), syncStatus: String = "synced") {
        self.id = id
        self.doorId = doorId
        self.userId = userId
        self.unlockTime = unlockTime
        self.unlockMethod = unlockMethod
        self.isSuccess = isSuccess
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 工单模型
struct WorkOrder: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var userId: Int64
    var propertyId: Int64
    var title: String
    var description: String
    var type: String
    var status: String
    var assignedTo: Int64?
    var imageURLs: [String]?
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "work_orders"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case propertyId = "property_id"
        case title, description, type, status
        case assignedTo = "assigned_to"
        case imageURLs = "image_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, userId: Int64, propertyId: Int64,
         title: String, description: String, type: String = "repair",
         status: String = "pending", assignedTo: Int64? = nil,
         imageURLs: [String]? = nil, createdAt: Date = Date(),
         updatedAt: Date = Date(), syncStatus: String = "synced") {
        self.id = id
        self.userId = userId
        self.propertyId = propertyId
        self.title = title
        self.description = description
        self.type = type
        self.status = status
        self.assignedTo = assignedTo
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 付款记录模型
struct Payment: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var userId: Int64
    var propertyId: Int64
    var amount: Double
    var type: String
    var status: String
    var paymentMethod: String?
    var transactionId: String?
    var billNumber: String?
    var paymentDate: Date?
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "payments"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case propertyId = "property_id"
        case amount, type, status
        case paymentMethod = "payment_method"
        case transactionId = "transaction_id"
        case billNumber = "bill_number"
        case paymentDate = "payment_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, userId: Int64, propertyId: Int64,
         amount: Double, type: String = "property_fee",
         status: String = "pending", paymentMethod: String? = nil,
         transactionId: String? = nil, billNumber: String? = nil,
         paymentDate: Date? = nil, createdAt: Date = Date(),
         updatedAt: Date = Date(), syncStatus: String = "synced") {
        self.id = id
        self.userId = userId
        self.propertyId = propertyId
        self.amount = amount
        self.type = type
        self.status = status
        self.paymentMethod = paymentMethod
        self.transactionId = transactionId
        self.billNumber = billNumber
        self.paymentDate = paymentDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 通知模型
struct Notification: Codable, FetchableRecord, PersistableRecord {
    // 基本信息
    var id: Int64?
    var title: String
    var content: String
    var read: Bool
    var userId: Int64
    
    // 状态信息
    var createdAt: Date
    var updatedAt: Date = Date()
    var syncStatus: String = "synced"
    
    // 表名
    static let databaseTableName = "notifications"
    
    // 编码键
    enum CodingKeys: String, CodingKey {
        case id, title, content, read
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, title: String, content: String, read: Bool = false,
         userId: Int64, createdAt: Date = Date(), updatedAt: Date = Date(),
         syncStatus: String = "synced") {
        self.id = id
        self.title = title
        self.content = content
        self.read = read
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // 同步状态相关方法
    mutating func markAsSynced() {
        syncStatus = "synced"
    }
    
    mutating func markAsPending() {
        syncStatus = "pending"
    }
    
    mutating func markAsDeleted() {
        syncStatus = "deleted"
    }
}

// MARK: - 用户模型
struct UserM: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var username: String
    var phone: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case phone
    }
    
    static var databaseTableName: String {
        return "users"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("username", .text).notNull()
            t.column("phone", .text).notNull().unique()
        }
    }
}

// MARK: - 同步状态
enum SyncState: String, Codable {
    case synced      // 已同步
    case created     // 本地创建，未上传
    case updated     // 本地更新，未上传
    case deleted     // 本地删除，未上传
    case conflict    // 冲突
    
    var isLocal: Bool {
        return self != .synced
    }
}

// MARK: - 门禁卡模型
struct DoorCard: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var cardNumber: String
    var userId: Int64
    var doorId: Int64
    var isActive: Bool
    var syncState: SyncState
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case cardNumber
        case userId
        case doorId
        case isActive
        case syncState
        case createdAt
        case updatedAt
    }
    
    static var databaseTableName: String {
        return "door_cards"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("cardNumber", .text).notNull()
            t.column("userId", .integer).notNull().indexed()
            t.column("doorId", .integer).notNull().indexed()
            t.column("isActive", .boolean).notNull().defaults(to: true)
            t.column("syncState", .text).notNull().defaults(to: SyncState.created.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }
}

// MARK: - 物业费模型
struct PropertyFee: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var propertyId: Int64
    var amount: Double
    var startDate: Date
    var endDate: Date
    var isPaid: Bool
    var paymentMethod: String?
    var paymentId: Int64?
    var syncState: SyncState
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId
        case amount
        case startDate
        case endDate
        case isPaid
        case paymentMethod
        case paymentId
        case syncState
        case createdAt
        case updatedAt
    }
    
    static var databaseTableName: String {
        return "property_fees"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("propertyId", .integer).notNull().indexed()
            t.column("amount", .double).notNull()
            t.column("startDate", .datetime).notNull()
            t.column("endDate", .datetime).notNull()
            t.column("isPaid", .boolean).notNull().defaults(to: false)
            t.column("paymentMethod", .text)
            t.column("paymentId", .integer)
            t.column("syncState", .text).notNull().defaults(to: SyncState.created.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }
}

// MARK: - 通知模型
struct NotificationM: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var title: String
    var content: String
    var type: String
    var targetId: Int64?
    var userId: Int64?
    var isRead: Bool
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case type
        case targetId
        case userId
        case isRead
        case createdAt
        case updatedAt
    }
    
    static var databaseTableName: String {
        return "notifications"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("title", .text).notNull()
            t.column("content", .text).notNull()
            t.column("type", .text).notNull()
            t.column("targetId", .integer)
            t.column("userId", .integer).indexed()
            t.column("isRead", .boolean).notNull().defaults(to: false)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }
}

// MARK: - 设施预约模型
struct Reservation: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var userId: Int64
    var facilityId: Int64
    var startTime: Date
    var endTime: Date
    var status: String  // pending, approved, rejected, cancelled
    var notes: String?
    var syncState: SyncState
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case facilityId
        case startTime
        case endTime
        case status
        case notes
        case syncState
        case createdAt
        case updatedAt
    }
    
    static var databaseTableName: String {
        return "reservations"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("userId", .integer).notNull().indexed()
            t.column("facilityId", .integer).notNull().indexed()
            t.column("startTime", .datetime).notNull()
            t.column("endTime", .datetime).notNull()
            t.column("status", .text).notNull().defaults(to: "pending")
            t.column("notes", .text)
            t.column("syncState", .text).notNull().defaults(to: SyncState.created.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }
}

// MARK: - 社区设施模型
struct Facility: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var description: String?
    var location: String
    var isAvailable: Bool
    var openTime: String   // 格式如"08:00-20:00"
    var bookingRate: Double?  // 预约费率，可能为空表示免费
    var syncState: SyncState
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case location
        case isAvailable
        case openTime
        case bookingRate
        case syncState
        case createdAt
        case updatedAt
    }
    
    static var databaseTableName: String {
        return "facilities"
    }
    
    // 用于GRDB的表定义
    static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("description", .text)
            t.column("location", .text).notNull()
            t.column("isAvailable", .boolean).notNull().defaults(to: true)
            t.column("openTime", .text).notNull()
            t.column("bookingRate", .double)
            t.column("syncState", .text).notNull().defaults(to: SyncState.created.rawValue)
            t.column("createdAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
        }
    }
}

// MARK: - 模型命名空间
enum Models {
    // 用户响应模型
    struct UserResponse: Codable {
        let success: Bool
        let message: String?
        let user: User
    }
    
    // 管理系统登录响应模型
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
}

// 添加将OwnerInfo转换为User的扩展
extension Models.AdminLoginResponse.OwnerInfo {
    func toUser() -> User {
        return User(
            id: self.id,
            username: self.username,
            password: "",  // 不存储密码
            phone: self.phone,
            email: self.email ?? "",
            address: self.address ?? "",
            avatarURL: nil,
            community: nil
        )
    }
}
