import UIKit
import GRDB  // 如果使用GRDB
import Combine // 如果使用Combine

class UserDetailViewController: UIViewController {
    // MARK: - Properties
    var userId: Int64?
    // 使用RepositoryFactory而不是直接使用Repository
    private let userRepository = RepositoryFactory.shared.getUserRepository()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - IBOutlets
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserDetails()
    }
    
    // MARK: - Private Methods
    private func setupUI() {
        title = "用户详情"
        // 其他UI设置...
    }
    
    private func loadUserDetails() {
        guard let userId = userId else {
            showError("无效的用户ID")
            return
        }
        
        // 使用Combine方式获取用户信息
        userRepository.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.showError(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] user in
                    if let user = user {
                        self?.updateUI(with: user)
                    } else {
                        self?.showError("找不到用户信息")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateUI(with user: User) {
        // 使用username替换name属性
        nameLabel.text = user.username
        phoneLabel.text = user.phone
        emailLabel.text = user.email
        addressLabel.text = user.address
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "错误",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - User Extension (如果需要)
extension User {
    // 修改为使用username而不是name
    var displayName: String {
        return username
    }
} 
