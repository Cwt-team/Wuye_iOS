import Foundation
import Combine
import GRDB


// 数据库管理器类 - 简化版，必须与实际使用的兼容
class DatabaseManager {
    static let shared = DatabaseManager()
    
    let dbQueue: DatabaseQueue
    
    private init() {
        // 创建一个内存数据库用于测试
        let dbPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/wuye.sqlite"
        do {
            dbQueue = try DatabaseQueue(path: dbPath)
            try setupDatabase()
        } catch {
            fatalError("无法初始化数据库: \(error)")
        }
    }
    
    private func setupDatabase() throws {
        try dbQueue.inDatabase { db in
            try db.create(table: "users", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("username", .text).notNull()
                t.column("password", .text).notNull()
                t.column("phone", .text).notNull()
                t.column("email", .text)
                t.column("address", .text)
                t.column("avatar_url", .text)
                t.column("community", .text)
                t.column("sync_status", .text).notNull().defaults(to: "synced")
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
        }
    }
}

// 本地用户存储库协议 - 与UserRepositoryProtocol接口兼容
protocol LocalUserRepositoryProtocol {
    func getCurrentUser() -> AnyPublisher<User?, Error>
    func saveUser(user: User) -> AnyPublisher<User, Error>
    func deleteCurrentUser() -> AnyPublisher<Bool, Error>
    func getAllUsers() -> AnyPublisher<[User], Error>
    var cancellables: Set<AnyCancellable> { get set }
}

// 本地用户存储库实现
class LocalUserRepository: LocalUserRepositoryProtocol {
    // 数据库管理器
    private let dbManager: DatabaseManager
    
    // 用于存储Combine订阅
    var _cancellables = Set<AnyCancellable>()
    
    // 初始化方法
    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }
    
    // 获取当前用户
    func getCurrentUser() -> AnyPublisher<User?, Error> {
        return Future<User?, Error> { promise in
            do {
                // 从数据库获取用户记录
                let user = try self.dbManager.dbQueue.read { db in
                    return try User.fetchOne(db)
                }
                promise(.success(user))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // 保存用户
    func saveUser(user: User) -> AnyPublisher<User, Error> {
        return Future<User, Error> { promise in
            do {
                // 保存到数据库
                try self.dbManager.dbQueue.write { db in
                    // 检查是否存在用户
                    if let existingUser = try User.fetchOne(db, key: user.id) {
                        // 更新现有用户
                        var updatedUser = existingUser
                        updatedUser.update(with: user)
                        try updatedUser.update(db)
                        promise(.success(updatedUser))
                    } else {
                        // 插入新用户
                        try user.insert(db)
                        promise(.success(user))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // 删除当前用户
    func deleteCurrentUser() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            do {
                // 从数据库删除所有用户记录
                try self.dbManager.dbQueue.write { db in
                    _ = try User.deleteAll(db)
                }
                promise(.success(true))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // 获取所有用户
    func getAllUsers() -> AnyPublisher<[User], Error> {
        return Future<[User], Error> { promise in
            do {
                // 从数据库获取所有用户记录
                let users = try self.dbManager.dbQueue.read { db in
                    return try User.fetchAll(db)
                }
                promise(.success(users))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
}

// 扩展LocalUserRepositoryProtocol，添加cancellables属性
extension LocalUserRepositoryProtocol {
    var cancellables: Set<AnyCancellable> {
        get {
            if let repository = self as? LocalUserRepository {
                return repository._cancellables
            }
            return []
        }
        set {
            if var repository = self as? LocalUserRepository {
                repository._cancellables = newValue
            }
        }
    }
}

// 如果LocalRepositoryFactory未定义，添加一个简单的定义
class LocalRepositoryFactory {
    static let shared = LocalRepositoryFactory()
    
    func getUserRepository() -> LocalUserRepositoryProtocol {
        return LocalUserRepository(dbManager: DatabaseManager.shared)
    }
} 
