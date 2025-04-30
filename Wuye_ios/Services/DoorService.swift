import Foundation
import Combine
import GRDB

// MARK: - 门禁服务协议
protocol DoorServiceProtocol {
    func unlockDoor(doorId: Int64, userId: Int64) -> AnyPublisher<Bool, Error>
    func unlockDoorByCode(code: String, userId: Int64) -> AnyPublisher<Bool, Error>
    func scanQRCode(qrData: String, userId: Int64) -> AnyPublisher<Bool, Error>
    func getUnlockRecords(userId: Int64, limit: Int) -> AnyPublisher<[UnlockRecord], Error>
}

// MARK: - 门禁服务实现
class DoorService: DoorServiceProtocol {
    // 单例
    static let shared = DoorService()
    
    // 私有属性
    private let apiService = APIService.shared
    private let doorRepository: DoorRepositoryProtocol
    
    // 私有初始化
    private init() {
        doorRepository = RepositoryFactory.shared.getDoorRepository()
    }
    
    // MARK: - 公共方法
    
    /// 通过门禁ID开锁
    /// - Parameters:
    ///   - doorId: 门禁ID
    ///   - userId: 用户ID
    /// - Returns: 开锁结果
    func unlockDoor(doorId: Int64, userId: Int64) -> AnyPublisher<Bool, Error> {
        return doorRepository.unlockDoor(doorId: doorId, userId: userId)
    }
    
    /// 通过门禁编码开锁
    /// - Parameters:
    ///   - code: 门禁编码
    ///   - userId: 用户ID
    /// - Returns: 开锁结果
    func unlockDoorByCode(code: String, userId: Int64) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 查找对应的门禁
            self.findDoorByCode(code) { result in
                switch result {
                case .success(let door):
                    if let door = door {
                        // 找到门禁后，调用开锁方法
                        self.doorRepository.unlockDoor(doorId: door.id!, userId: userId)
                            .sink(
                                receiveCompletion: { completion in
                                    if case .failure(let error) = completion {
                                        promise(.failure(error))
                                    }
                                },
                                receiveValue: { success in
                                    promise(.success(success))
                                }
                            )
                            .cancel()
                    } else {
                        promise(.failure(NSError(domain: "DoorService", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到对应的门禁"])))
                    }
                    
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    /// 通过扫描二维码开锁
    /// - Parameters:
    ///   - qrData: 二维码数据
    ///   - userId: 用户ID
    /// - Returns: 开锁结果
    func scanQRCode(qrData: String, userId: Int64) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 解析二维码数据
            if let doorCode = self.parseDoorQRCode(qrData) {
                // 如果是有效的门禁二维码，调用通过编码开锁的方法
                self.unlockDoorByCode(code: doorCode, userId: userId)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { success in
                            promise(.success(success))
                        }
                    )
                    .cancel()
            } else {
                // 二维码格式不正确
                promise(.failure(NSError(domain: "DoorService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的门禁二维码"])))
            }
        }.eraseToAnyPublisher()
    }
    
    /// 获取用户的开锁记录
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - limit: 记录限制数量
    /// - Returns: 开锁记录列表
    func getUnlockRecords(userId: Int64, limit: Int) -> AnyPublisher<[UnlockRecord], Error> {
        return doorRepository.getUnlockRecords(forUserId: userId, limit: limit)
    }
    
    // MARK: - 私有方法
    
    /// 通过编码查找门禁
    /// - Parameters:
    ///   - code: 门禁编码
    ///   - completion: 完成回调
    private func findDoorByCode(_ code: String, completion: @escaping (Result<Door?, Error>) -> Void) {
        // 首先尝试从本地数据库查找
        let dbManager = DBManager.shared
        let result = dbManager.fetchOne { db in
            Door.filter(Column("door_code") == code)
        }
        
        switch result {
        case .success(let door):
            completion(.success(door))
            
        case .failure(let error):
            // 检查是否为NotFound错误
            if case DatabaseError.notFound = error {
                // 本地找不到，查询API
                apiService.request(
                    endpoint: "/doors/code/\(code)",
                    method: .get,
                    requiresAuth: true
                ) { (result: Result<Door, APIError>) in
                    switch result {
                    case .success(let door):
                        // 保存到本地数据库
                        var localDoor = door
                        localDoor.syncStatus = "synced"
                        let _ = dbManager.save(record: localDoor)
                        completion(.success(localDoor))
                        
                    case .failure(let error):
                        if case APIError.serverError = error {
                            // 服务器返回404或未找到资源的情况
                            completion(.success(nil))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            } else {
                completion(.failure(error))
            }
        }
    }
    
    /// 解析门禁二维码
    /// - Parameter qrData: 二维码数据
    /// - Returns: 门禁编码，如果无效则返回nil
    private func parseDoorQRCode(_ qrData: String) -> String? {
        // 门禁二维码格式：wuye://door/{doorCode}
        let prefix = "wuye://door/"
        
        if qrData.hasPrefix(prefix) {
            let doorCode = qrData.dropFirst(prefix.count)
            if !doorCode.isEmpty {
                return String(doorCode)
            }
        }
        
        return nil
    }
}

// MARK: - 服务内部使用的门禁仓库实现
private class ServiceDoorRepository: DoorRepositoryProtocol {
    private let dbManager = DBManager.shared
    private let apiService = APIService.shared
    
    func getDoors(forPropertyId: Int64) -> AnyPublisher<[Door], Error> {
        return Future<[Door], Error> { promise in
            // 从本地数据库获取
            let result = self.dbManager.fetch { db in
                Door.filter(Column("property_id") == forPropertyId)
                    .filter(Column("sync_status") != "deleted")
                    .order(Column("name").asc)
            }
            
            switch result {
            case .success(let doors):
                promise(.success(doors))
                
                // 在后台刷新数据
                self.refreshData().sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                ).cancel()
                
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func unlockDoor(doorId: Int64, userId: Int64) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 创建一条开锁记录
            let unlockRecord = UnlockRecord(
                doorId: doorId,
                userId: userId,
                unlockTime: Date(),
                unlockMethod: "app",
                isSuccess: false, // 初始状态设为false
                createdAt: Date(),
                updatedAt: Date(),
                syncStatus: "pending"
            )
            
            // 保存到本地数据库
            let saveResult = self.dbManager.save(record: unlockRecord)
            
            switch saveResult {
            case .success(let record):
                // 发送开锁请求到服务器
                self.apiService.request(
                    endpoint: "/doors/unlock",
                    method: .post,
                    parameters: [
                        "door_id": doorId,
                        "user_id": userId
                    ],
                    requiresAuth: true
                ) { (result: Result<UnlockRecord, APIError>) in
                    switch result {
                    case .success(let remoteRecord):
                        // 更新本地记录
                        var updatedRecord = remoteRecord
                        updatedRecord.syncStatus = "synced"
                        let _ = self.dbManager.save(record: updatedRecord)
                        promise(.success(remoteRecord.isSuccess))
                        
                    case .failure(let error):
                        // 更新本地记录状态为失败
                        var failedRecord = record
                        failedRecord.isSuccess = false
                        let _ = self.dbManager.save(record: failedRecord)
                        promise(.failure(error))
                    }
                }
                
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func getUnlockRecords(forUserId: Int64, limit: Int) -> AnyPublisher<[UnlockRecord], Error> {
        return Future<[UnlockRecord], Error> { promise in
            // 从本地数据库获取
            let result = self.dbManager.fetch { db in
                UnlockRecord.filter(Column("user_id") == forUserId)
                    .order(Column("unlock_time").desc)
                    .limit(limit)
            }
            
            switch result {
            case .success(let records):
                promise(.success(records))
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func refreshData() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            self.apiService.request(
                endpoint: "/doors",
                method: .get,
                requiresAuth: true
            ) { (result: Result<[Door], APIError>) in
                switch result {
                case .success(let doors):
                    for var door in doors {
                        door.syncStatus = "synced"
                        let _ = self.dbManager.save(record: door)
                    }
                    promise(.success(true))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func syncPendingChanges() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 获取所有待同步的开锁记录
            let result = self.dbManager.fetch { db in
                UnlockRecord.filter(Column("sync_status") == "pending")
            }
            
            switch result {
            case .success(let pendingRecords):
                if pendingRecords.isEmpty {
                    promise(.success(true))
                    return
                }
                
                // 同步所有待处理的记录
                let group = DispatchGroup()
                var syncError: Error? = nil
                
                for record in pendingRecords {
                    group.enter()
                    
                    self.apiService.request(
                        endpoint: "/doors/unlock/sync",
                        method: .post,
                        parameters: [
                            "door_id": record.doorId,
                            "user_id": record.userId,
                            "unlock_time": ISO8601DateFormatter().string(from: record.unlockTime),
                            "unlock_method": record.unlockMethod,
                            "is_success": record.isSuccess
                        ],
                        requiresAuth: true
                    ) { (result: Result<UnlockRecord, APIError>) in
                        switch result {
                        case .success(let remoteRecord):
                            var syncedRecord = remoteRecord
                            syncedRecord.syncStatus = "synced"
                            let _ = self.dbManager.save(record: syncedRecord)
                        case .failure(let error):
                            syncError = error
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = syncError {
                        promise(.failure(error))
                    } else {
                        promise(.success(true))
                    }
                }
                
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
} 