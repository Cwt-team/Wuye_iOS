struct User: Codable {
    let id: Int
    let name: String
    let avatarURL: String?
    let community: String?   // 新增：小区/房号
    // …其它字段
}
