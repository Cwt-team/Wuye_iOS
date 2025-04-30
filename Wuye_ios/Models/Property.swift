import Foundation
import GRDB

// 注意：该文件已被移动到统一模型文件中，此文件应删除或保留为空，以避免重复声明

/*
struct Property: BaseModel {
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
}
*/ 