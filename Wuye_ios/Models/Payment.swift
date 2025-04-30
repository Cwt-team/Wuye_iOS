import Foundation
import GRDB

// 注意：该文件已被移动到统一模型文件中，此文件应删除或保留为空，以避免重复声明

/*
/// 支付模型
struct Payment: BaseModel {
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
    
    // 初始化方法
    init(id: Int64? = nil, userId: Int64, propertyId: Int64, 
         amount: Double, type: String = "property_fee", 
         status: String = "pending", paymentMethod: String? = nil, 
         transactionId: String? = nil, billNumber: String? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date(), 
         syncStatus: String = "synced") {
        self.id = id
        self.userId = userId
        self.propertyId = propertyId
        self.amount = amount
        self.type = type
        self.status = status
        self.paymentMethod = paymentMethod
        self.transactionId = transactionId
        self.billNumber = billNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}
*/ 