// 注意：本文件内容已移动到Models.swift中，以避免重复声明和类型查找歧义问题
// 请使用Models.swift中定义的协议和扩展

import Foundation
import GRDB

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

/*
import Foundation
import GRDB

/// 数据库模型基础协议
protocol BaseModel: Codable, FetchableRecord, PersistableRecord {
    /// 同步状态 (synced/pending/deleted)
    var syncStatus: String { get set }
    
    /// 同步标记为已同步
    mutating func markAsSynced()
    
    /// 同步标记为待同步
    mutating func markAsPending()
    
    /// 同步标记为已删除
    mutating func markAsDeleted()
}

/// 基础模型的默认实现
extension BaseModel {
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

/// GRDB的列名辅助类型
extension GRDB.Column { }
*/ 