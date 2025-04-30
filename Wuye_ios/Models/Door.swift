import Foundation
import GRDB

// 注意：本文件已被移动到统一模型文件中，此文件应删除或保留为空，以避免重复声明

/*
struct Door: BaseModel {
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
}
*/ 