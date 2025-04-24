struct AuthResponse: Codable {
    let token: String
    let user: User
}