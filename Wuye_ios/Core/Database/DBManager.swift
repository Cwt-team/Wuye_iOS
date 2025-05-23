import Foundation
import GRDB

// MARK: - 数据库错误类型
enum DatabaseError: Error, LocalizedError {
    case initializationError(Error)
    case migrationError(Error)
    case queryError(Error)
    case saveError(Error)
    case deleteError(Error)
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .initializationError(let error):
            return "数据库初始化错误: \(error.localizedDescription)"
        case .migrationError(let error):
            return "数据库迁移错误: \(error.localizedDescription)"
        case .queryError(let error):
            return "数据库查询错误: \(error.localizedDescription)"
        case .saveError(let error):
            return "数据库保存错误: \(error.localizedDescription)"
        case .deleteError(let error):
            return "数据库删除错误: \(error.localizedDescription)"
        case .notFound:
            return "未找到相关数据"
        }
    }
}

// MARK: - 数据库管理器
class DBManager {
    // 单例
    static let shared = DBManager()
    private var dbQueue: DatabaseQueue?
    
    // 版本管理
    private let schemaVersion: Int = 1
    
    // 错误类型
    enum DBError: Error {
        case setupFailed
        case migrationFailed
        case notInitialized
        case saveFailed
        case fetchFailed
        case deleteFailed
        case transactionFailed
        case clearFailed
    }
    
    // 私有初始化方法
    private init() {
        let _ = setupDatabase()
    }
    
    // MARK: - 数据库设置
    private func setupDatabase() -> Result<Void, DBError> {
        do {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let dbPath = documentsPath + "/wuye.sqlite"
            print("Database path: \(dbPath)")
            
            // 使用var声明configuration使其可变
            var configuration = Configuration()
            configuration.label = "Wuye Database"
            
            // 现在可以修改configuration的属性
            configuration.prepareDatabase { db in
                // 启用外键约束
                try db.execute(sql: "PRAGMA foreign_keys = ON")
            }
            
            // 创建数据库队列
            dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
            
            // 执行数据库迁移
            try migrateDatabase()
            
            return .success(())
        } catch {
            print("Database setup error: \(error)")
            return .failure(.setupFailed)
        }
    }
    
    // MARK: - 数据库迁移
    private func migrateDatabase() throws {
        let schemaVersion = 1
        
        // 读取当前数据库版本
        var currentVersion = 0
        try dbQueue?.read { db in
            // 使用PRAGMA user_version读取当前数据库版本
            currentVersion = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        }
        
        // 如果当前版本小于目标版本，需要进行迁移
        if currentVersion < schemaVersion {
            try dbQueue?.write { db in
                // 创建初始表
                try createInitialTables(db: db)
                
                // 设置新版本
                try db.execute(sql: "PRAGMA user_version = \(schemaVersion)")
            }
        }
    }
    
    // 创建初始表结构
    private func createInitialTables(db: Database) throws {
        // 用户表
        try db.create(table: "users") { table in
            table.column("id", .integer).primaryKey()
            table.column("username", .text).notNull()
            table.column("password", .text).notNull()
            table.column("phone", .text).notNull().unique()
            table.column("email", .text)
            table.column("address", .text)
            table.column("avatar_url", .text)
            table.column("community", .text)
            table.column("created_at", .datetime).notNull()
            table.column("updated_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 物业表
        try db.create(table: "properties") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("name", .text).notNull()
            table.column("address", .text).notNull()
            table.column("user_id", .integer).notNull()
                .references("users", onDelete: .cascade)
            table.column("created_at", .datetime).notNull()
            table.column("updated_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 工单表
        try db.create(table: "work_orders") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("title", .text).notNull()
            table.column("description", .text).notNull()
            table.column("status", .text).notNull()
            table.column("property_id", .integer).notNull()
                .references("properties", onDelete: .cascade)
            table.column("assigned_to", .integer)
                .references("users")
            table.column("created_by", .integer).notNull()
                .references("users")
            table.column("created_at", .datetime).notNull()
            table.column("updated_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 付款记录表
        try db.create(table: "payments") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("amount", .double).notNull()
            table.column("status", .text).notNull()
            table.column("payment_date", .datetime)
            table.column("property_id", .integer).notNull()
                .references("properties", onDelete: .cascade)
            table.column("user_id", .integer).notNull()
                .references("users", onDelete: .cascade)
            table.column("created_at", .datetime).notNull()
            table.column("updated_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 通知表
        try db.create(table: "notifications") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("title", .text).notNull()
            table.column("content", .text).notNull()
            table.column("read", .boolean).notNull()
            table.column("user_id", .integer).notNull()
                .references("users", onDelete: .cascade)
            table.column("created_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 门禁表
        try db.create(table: "doors") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("name", .text).notNull()
            table.column("code", .text).notNull().unique()
            table.column("property_id", .integer).notNull()
                .references("properties", onDelete: .cascade)
            table.column("created_at", .datetime).notNull()
            table.column("updated_at", .datetime).notNull()
            table.column("sync_status", .text).notNull()
        }
        
        // 开锁记录表
        try db.create(table: "unlock_records") { table in
            table.autoIncrementedPrimaryKey("id")
            table.column("door_id", .integer).notNull()
                .references("doors", onDelete: .cascade)
            table.column("user_id", .integer).notNull()
                .references("users", onDelete: .cascade)
            table.column("unlock_time", .datetime).notNull()
            table.column("status", .text).notNull()
            table.column("sync_status", .text).notNull()
        }
    }
    
    // MARK: - 通用CRUD操作
    
    // 保存记录
    func save<T: PersistableRecord>(record: T) -> Result<T, DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            var savedRecord = record
            try dbQueue.write { db in
                try savedRecord.save(db)
            }
            return .success(savedRecord)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    // 批量保存记录
    func saveAll<T: PersistableRecord>(records: [T]) -> Result<[T], DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            var savedRecords: [T] = []
            try dbQueue.write { db in
                for var record in records {
                    try record.save(db)
                    savedRecords.append(record)
                }
            }
            return .success(savedRecords)
        } catch {
            return .failure(.saveError(error))
        }
    }
    
    // 查询记录
    func fetch<T: FetchableRecord & TableRecord>(
        _ requestMaker: @escaping (Database) throws -> QueryInterfaceRequest<T>
    ) -> Result<[T], DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            let records = try dbQueue.read { db in
                try requestMaker(db).fetchAll(db)
            }
            return .success(records)
        } catch {
            return .failure(.queryError(error))
        }
    }
    
    // 查询单条记录
    func fetchOne<T: FetchableRecord & TableRecord>(
        _ requestMaker: @escaping (Database) throws -> QueryInterfaceRequest<T>
    ) -> Result<T, DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            let record = try dbQueue.read { db in
                if let record = try requestMaker(db).fetchOne(db) {
                    return record
                } else {
                    throw DatabaseError.notFound
                }
            }
            return .success(record)
        } catch let error as DatabaseError {
            return .failure(error)
        } catch {
            return .failure(.queryError(error))
        }
    }
    
    // 删除记录
    func delete<T: TableRecord>(
        _ requestMaker: @escaping (Database) throws -> QueryInterfaceRequest<T>
    ) -> Result<Int, DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            let count = try dbQueue.write { db in
                try requestMaker(db).deleteAll(db)
            }
            return .success(count)
        } catch {
            return .failure(.deleteError(error))
        }
    }
    
    // 执行事务
    func transaction<T>(_ block: @escaping (Database) throws -> T) -> Result<T, DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            let result = try dbQueue.write { db in
                var value: T?
                try db.inTransaction {
                    value = try block(db)
                    return .commit
                }
                // 返回事务内获取的值
                return value!
            }
            return .success(result)
        } catch {
            return .failure(.queryError(error))
        }
    }
    
    // 获取数据库路径
    func getDatabasePath() -> String? {
        do {
            let fileManager = FileManager.default
            let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            return documentsPath.appendingPathComponent("wuye.sqlite").path
        } catch {
            return nil
        }
    }
    
    // 清空数据库
    func clearDatabase() -> Result<Void, DatabaseError> {
        guard let dbQueue = dbQueue else {
            return .failure(.initializationError(NSError(domain: "DBManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])))
        }
        
        do {
            try dbQueue.write { db in
                try db.execute(sql: """
                    DELETE FROM unlock_records;
                    DELETE FROM doors;
                    DELETE FROM notifications;
                    DELETE FROM payments;
                    DELETE FROM work_orders;
                    DELETE FROM properties;
                    DELETE FROM users;
                """)
            }
            return .success(())
        } catch {
            return .failure(.deleteError(error))
        }
    }
    
    // MARK: - 公共方法
    
    /// 测试数据库连接
    /// 在控制台中打印数据库连接测试结果
    func testDatabaseConnection() {
        print("\n============ 数据库连接测试开始 ============")
        
        // 检查数据库路径
        if let dbPath = getDatabasePath() {
            print("📁 数据库文件路径: \(dbPath)")
            
            // 检查文件是否存在
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: dbPath) {
                print("✅ 数据库文件存在")
                
                // 检查文件大小
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: dbPath)
                    if let fileSize = attributes[.size] as? UInt64 {
                        let sizeInKB = Double(fileSize) / 1024.0
                        print("📊 数据库文件大小: \(String(format: "%.2f", sizeInKB)) KB")
                    }
                } catch {
                    print("⚠️ 无法获取文件属性: \(error.localizedDescription)")
                }
            } else {
                print("❌ 数据库文件不存在!")
                print("🔍 可能原因: 数据库尚未初始化或路径错误")
                print("============ 数据库连接测试结束 ============\n")
                return
            }
        } else {
            print("❌ 无法获取数据库路径")
            print("============ 数据库连接测试结束 ============\n")
            return
        }
        
        print("🔄 正在尝试连接数据库...")
        
        do {
            guard let dbQueue = self.dbQueue else {
                print("❌ 数据库连接失败: 数据库队列未初始化")
                print("🔍 可能原因: DBManager初始化失败或setupDatabase方法出错")
                print("============ 数据库连接测试结束 ============\n")
                return
            }
            
            print("✅ 数据库队列已初始化")
            print("🔄 正在执行测试查询...")
            
            // 尝试执行一个简单的SQL查询来测试连接
            try dbQueue.read { db in
                // 检查数据库版本
                print("🔄 查询数据库版本...")
                let version = try Int.fetchOne(db, sql: "PRAGMA user_version")
                print("✅ 版本查询成功: \(version ?? 0)")
                
                print("🔄 统计数据库表数量...")
                let tableCount = try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master WHERE type='table'")
                print("✅ 表数量查询成功: \(tableCount ?? 0)")
                
                print("🔄 获取表列表...")
                let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
                print("✅ 表列表查询成功: \(tables.joined(separator: ", "))")
                
                print("\n📋 数据库连接测试结果摘要:")
                print("✅ 数据库连接成功")
                print("📊 数据库信息:")
                print("   - 版本: \(version ?? 0)")
                print("   - 表数量: \(tableCount ?? 0)")
                print("   - 表列表: \(tables.joined(separator: ", "))")
                
                // 测试用户表记录数
                if tables.contains("users") {
                    print("🔄 统计用户表记录数...")
                    let userCount = try Int.fetchOne(db, sql: "SELECT count(*) FROM users")
                    print("✅ 用户表记录数: \(userCount ?? 0)")
                } else {
                    print("⚠️ 未找到用户表，可能数据库结构不完整")
                }
            }
        } catch {
            print("❌ 数据库连接失败: \(error.localizedDescription)")
            print("🔍 详细错误信息: \(error)")
        }
        
        print("============ 数据库连接测试结束 ============\n")
    }
}
