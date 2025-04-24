import Combine
import Foundation

enum APIError: Error { case network, decoding }

class APIService {
    static let shared = APIService()
    private init() {}

    func post<T: Codable, U: Codable>(url: URL, body: T) -> AnyPublisher<U, APIError> {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)

        return URLSession.shared.dataTaskPublisher(for: req)
            .mapError { _ in .network }
            .flatMap { data, _ in
                Just(data)
                  .decode(type: U.self, decoder: JSONDecoder())
                  .mapError { _ in .decoding }
            }
            .eraseToAnyPublisher()
    }
}
