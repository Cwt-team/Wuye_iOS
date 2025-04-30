import Foundation
import GRDB

// 注意：本文件已被移动到统一模型文件中，此文件应删除或保留为空，以避免重复声明

/*
/// 工单模型
struct WorkOrder: BaseModel {
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
}
*/ 