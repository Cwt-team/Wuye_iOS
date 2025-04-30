import UIKit
import GRDB
import Combine

class UserListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    // 使用RepositoryFactory替代Repository
    private let userRepository = RepositoryFactory.shared.getUserRepository()
    private var users: [User] = []
    
    // 添加cancellables属性
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // 注册cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UserCell")
        
        // 加载数据
        loadUsers()
    }
    
    private func loadUsers() {
        // 使用Combine流程获取用户列表
        userRepository.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("加载用户失败: \(error)")
                        // 显示错误提示
                        let alert = UIAlertController(title: "错误", message: "加载用户数据失败", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self?.present(alert, animated: true)
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.users = [user] // 只有当前用户
                        self?.tableView.reloadData()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        
        let user = users[indexPath.row]
        
        // 用username替代name属性，因为User模型中没有name属性
        cell.textLabel?.text = user.username
        cell.detailTextLabel?.text = user.phone
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let user = users[indexPath.row]
        
        // 跳转到用户详情页
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let userDetailVC = storyboard.instantiateViewController(withIdentifier: "UserDetailViewController") as? UserDetailViewController {
            userDetailVC.userId = user.id
            navigationController?.pushViewController(userDetailVC, animated: true)
        }
    }
}

// 使用GRDB的Row类型
func convertRowsToDictionary(rows: [GRDB.Row]) -> [[String: Any]] {
    return rows.map { row in
        var dict: [String: Any] = [:]
        for (columnName, databaseValue) in row {
            dict[columnName] = databaseValue.storage.value
        }
        return dict
    }
}


