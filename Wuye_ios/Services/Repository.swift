import Foundation
import Combine
import Alamofire
import GRDB

// MARK: - 数据仓库协议
protocol RepositoryProtocol: AnyObject {
    // 通用方法
    func refreshData() -> AnyPublisher<Bool, Error>
    func syncPendingChanges() -> AnyPublisher<Bool, Error>
}

// MARK: - 用户数据仓库协议
protocol UserRepositoryProtocol: RepositoryProtocol {
    func getCurrentUser() -> AnyPublisher<User?, Error>
    func saveUser(user: User) -> AnyPublisher<User, Error>
    func updateUserProfile(user: User) -> AnyPublisher<User, Error>
    func deleteCurrentUser() -> AnyPublisher<Bool, Error>
}

// MARK: - 物业数据仓库协议
protocol PropertyRepositoryProtocol: RepositoryProtocol {
    func getProperties(forUserId: Int64) -> AnyPublisher<[Property], Error>
    func getProperty(id: Int64) -> AnyPublisher<Property?, Error>
    func saveProperty(property: Property) -> AnyPublisher<Property, Error>
}

// MARK: - 工单数据仓库协议
protocol WorkOrderRepositoryProtocol: RepositoryProtocol {
    func getWorkOrders(forUserId: Int64, status: String?) -> AnyPublisher<[WorkOrder], Error>
    func getWorkOrder(id: Int64) -> AnyPublisher<WorkOrder?, Error>
    func createWorkOrder(workOrder: WorkOrder) -> AnyPublisher<WorkOrder, Error>
    func updateWorkOrderStatus(id: Int64, status: String) -> AnyPublisher<WorkOrder, Error>
}

// MARK: - 支付数据仓库协议
protocol PaymentRepositoryProtocol: RepositoryProtocol {
    func getPayments(forUserId: Int64) -> AnyPublisher<[Payment], Error>
    func createPayment(payment: Payment) -> AnyPublisher<Payment, Error>
    func updatePaymentStatus(id: Int64, status: String) -> AnyPublisher<Payment, Error>
}

// MARK: - 通知数据仓库协议
protocol NotificationRepositoryProtocol: RepositoryProtocol {
    func getNotifications(forUserId: Int64) -> AnyPublisher<[Notification], Error>
    func markNotificationAsRead(id: Int64) -> AnyPublisher<Notification, Error>
    func deleteNotification(id: Int64) -> AnyPublisher<Bool, Error>
}

// MARK: - 门禁数据仓库协议
protocol DoorRepositoryProtocol: RepositoryProtocol {
    func getDoors(forPropertyId: Int64) -> AnyPublisher<[Door], Error>
    func unlockDoor(doorId: Int64, userId: Int64) -> AnyPublisher<Bool, Error>
    func getUnlockRecords(forUserId: Int64, limit: Int) -> AnyPublisher<[UnlockRecord], Error>
}

// MARK: - 用户数据仓库实现
class UserRepository: UserRepositoryProtocol {
    private let dbManager = DBManager.shared
    private let apiService = APIService.shared
    
    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return Future<User?, Error> { promise in
            // 尝试从本地数据库获取当前用户
            let result = self.dbManager.fetchOne { db in
                User.filter(GRDB.Column("sync_status") != "deleted")
                    .order(GRDB.Column("updated_at").desc)
                    .limit(1)
            }
            
            switch result {
            case .success(let user):
                promise(.success(user))
            case .failure(let error):
                if case .notFound = error {
                    promise(.success(nil))
                } else {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func saveUser(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            let result = self.dbManager.save(record: user)
            switch result {
            case .success(let savedUser):
                promise(.success(savedUser))
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func updateUserProfile(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            // 首先保存到本地数据库
            var updatedUser = user
            updatedUser.syncStatus = "pending"
            
            let saveResult = self.dbManager.save(record: updatedUser)
            switch saveResult {
            case .success(let localUser):
                // 然后同步到服务器
                self.apiService.request(
                    endpoint: "/users/\(user.id)",
                    method: HTTPMethod.put,
                    parameters: self.userToParameters(user),
                    requiresAuth: true
                ) { (result: Result<User, APIError>) in
                    switch result {
                    case .success(let remoteUser):
                        // 更新本地状态
                        var syncedUser = remoteUser
                        syncedUser.syncStatus = "synced"
                        let finalSaveResult = self.dbManager.save(record: syncedUser)
                        
                        switch finalSaveResult {
                        case .success(let finalUser):
                            promise(.success(finalUser))
                        case .failure(let error):
                            promise(.failure(error))
                        }
                        
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
                
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteCurrentUser() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 使用dbManager.delete方法删除所有用户
            let result = self.dbManager.delete { db in
                User.all()
            }
            
            switch result {
            case .success(_):
                promise(.success(true))
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    func refreshData() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            self.apiService.request(
                endpoint: "/users/me",
                method: HTTPMethod.get,
                requiresAuth: true
            ) { (result: Result<User, APIError>) in
                switch result {
                case .success(let user):
                    let saveResult = self.dbManager.save(record: user)
                    switch saveResult {
                    case .success:
                        promise(.success(true))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func syncPendingChanges() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 获取所有待同步的记录
            let result = self.dbManager.fetch { db in
                User.filter(GRDB.Column("sync_status") == "pending")
            }
            
            switch result {
            case .success(let pendingUsers):
                if pendingUsers.isEmpty {
                    promise(.success(true))
                    return
                }
                
                // 创建一个组来同步所有挂起的更改
                let group = DispatchGroup()
                var syncError: Error? = nil
                
                for user in pendingUsers {
                    group.enter()
                    
                    self.apiService.request(
                        endpoint: "/users/\(user.id)",
                        method: HTTPMethod.put,
                        parameters: self.userToParameters(user),
                        requiresAuth: true
                    ) { (result: Result<User, APIError>) in
                        switch result {
                        case .success(let remoteUser):
                            var syncedUser = remoteUser
                            syncedUser.syncStatus = "synced"
                            let _ = self.dbManager.save(record: syncedUser)
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
    
    // MARK: - Helper methods
    private func userToParameters(_ user: User) -> [String: Any] {
        return [
            "username": user.username,
            "phone": user.phone,
            "email": user.email,
            "address": user.address,
            "community": user.community ?? ""
        ]
    }
}

// MARK: - 物业数据仓库实现
class PropertyRepository: PropertyRepositoryProtocol {
    private let dbManager = DBManager.shared
    private let apiService = APIService.shared
    
    func getProperties(forUserId: Int64) -> AnyPublisher<[Property], Error> {
        return Future<[Property], Error> { promise in
            // 先从本地数据库获取
            let result = self.dbManager.fetch { db in
                Property.filter(GRDB.Column("user_id") == forUserId)
                    .filter(GRDB.Column("sync_status") != "deleted")
                    .order(GRDB.Column("name").asc)
            }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let properties):
                    promise(.success(properties))
                    
                    // 在后台刷新数据
                    self.refreshData().sink(
                        receiveCompletion: { _ in },
                        receiveValue: { _ in }
                    ).cancel()
                    
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func getProperty(id: Int64) -> AnyPublisher<Property?, Error> {
        return Future<Property?, Error> { promise in
            let result = self.dbManager.fetchOne { db in
                Property.filter(GRDB.Column("id") == id)
            }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let property):
                    promise(.success(property))
                case .failure(let error):
                    if case .notFound = error {
                        promise(.success(nil))
                    } else {
                        promise(.failure(error))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func saveProperty(property: Property) -> AnyPublisher<Property, Error> {
        return Future<Property, Error> { promise in
            // 保存到本地
            var localProperty = property
            localProperty.syncStatus = "pending"
            
            let result = self.dbManager.save(record: localProperty)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let localProperty):
                    // 同步到服务器
                    self.apiService.request(
                        endpoint: "/properties",
                        method: HTTPMethod.post,
                        parameters: self.propertyToParameters(localProperty),
                        requiresAuth: true
                    ) { (result: Result<Property, APIError>) in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let remoteProperty):
                                // 更新本地状态
                                var syncedProperty = remoteProperty
                                syncedProperty.syncStatus = "synced"
                                let finalSaveResult = self.dbManager.save(record: syncedProperty)
                                
                                switch finalSaveResult {
                                case .success(let finalProperty):
                                    promise(.success(finalProperty))
                                case .failure(let error):
                                    promise(.failure(error))
                                }
                                
                            case .failure(let error):
                                promise(.failure(error))
                            }
                        }
                    }
                    
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func refreshData() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            self.apiService.request(
                endpoint: "/properties",
                method: HTTPMethod.get,
                requiresAuth: true
            ) { (result: Result<[Property], APIError>) in
                switch result {
                case .success(let properties):
                    for var property in properties {
                        property.syncStatus = "synced"
                        let _ = self.dbManager.save(record: property)
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
            // 获取所有待同步的记录
            let result = self.dbManager.fetch { db in
                Property.filter(GRDB.Column("sync_status") == "pending")
            }
            
            switch result {
            case .success(let pendingProperties):
                if pendingProperties.isEmpty {
                    promise(.success(true))
                    return
                }
                promise(.success(true)) // 简化实现
            case .failure(let error):
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Helper methods
    private func propertyToParameters(_ property: Property) -> [String: Any] {
        return [
            "name": property.name,
            "address": property.address,
            "user_id": property.userId
        ]
    }
}

// MARK: - 门禁仓库实现
class RepositoryDoorRepository: DoorRepositoryProtocol {
    // 简单实现
    func getDoors(forPropertyId: Int64) -> AnyPublisher<[Door], Error> {
        return Future<[Door], Error> { promise in
            promise(.success([]))
        }.eraseToAnyPublisher()
    }
    
    func unlockDoor(doorId: Int64, userId: Int64) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            promise(.success(true))
        }.eraseToAnyPublisher()
    }
    
    func getUnlockRecords(forUserId: Int64, limit: Int) -> AnyPublisher<[UnlockRecord], Error> {
        return Future<[UnlockRecord], Error> { promise in
            promise(.success([]))
        }.eraseToAnyPublisher()
    }
    
    func refreshData() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            promise(.success(true))
        }.eraseToAnyPublisher()
    }
    
    func syncPendingChanges() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            promise(.success(true))
        }.eraseToAnyPublisher()
    }
}

// MARK: - 数据仓库工厂
class RepositoryFactory {
    static let shared = RepositoryFactory()
    private init() {}

    private var userRepository: UserRepository?
    private var propertyRepository: PropertyRepository?
    private var doorRepository: RepositoryDoorRepository?
    
    func getUserRepository() -> UserRepositoryProtocol {
        if userRepository == nil {
            userRepository = UserRepository()
        }
        return userRepository!
    }
    
    func getPropertyRepository() -> PropertyRepositoryProtocol {
        if propertyRepository == nil {
            propertyRepository = PropertyRepository()
        }
        return propertyRepository!
    }
    
    func getDoorRepository() -> DoorRepositoryProtocol {
        if doorRepository == nil {
            doorRepository = RepositoryDoorRepository()
        }
        return doorRepository!
    }
}

