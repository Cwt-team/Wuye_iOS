import Combine
import Foundation

class LoginViewModel: ObservableObject {
    @Published var phone = ""
    @Published var code = ""
    @Published var password = ""
    @Published var isSendingCode = false

    private var auth = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()

    func sendCode() {
        guard !phone.isEmpty else { return }
        isSendingCode = true
        auth.sendCode(to: phone)
            .sink(receiveCompletion: { _ in self.isSendingCode = false },
                  receiveValue: { })
            .store(in: &cancellables)
    }

    func login() {
        auth.login(phone: phone, password: password)
    }
}
