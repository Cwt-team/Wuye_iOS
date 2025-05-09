import Foundation
import GRDB

// 注意：本文件已被移动到统一模型文件中，此文件应删除或保留为空，以避免重复声明

/*
struct UnlockRecord: BaseModel {
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
}
*/ 