import Foundation

final class DeepSeekBalanceClient {
    private let apiKeyLoader: () -> String?

    init(apiKeyLoader: @escaping () -> String? = DeepSeekBalanceClient.loadAPIKey) {
        self.apiKeyLoader = apiKeyLoader
    }

    func fetchBalance() async throws -> DeepSeekBalance {
        guard let apiKey = apiKeyLoader() else {
            throw QuotaBarError.deepSeekNotConfigured
        }

        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaBarError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw QuotaBarError.appServer("DeepSeek API key is invalid")
            }
            throw QuotaBarError.appServer("DeepSeek HTTP \(httpResponse.statusCode)")
        }

        return try DeepSeekBalanceParser.decode(data)
    }

    static func loadAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            return key
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/.config/quota-bar/deepseek_api_key",
            "\(home)/.quota-bar/deepseek_api_key"
        ]

        for path in paths {
            guard let value = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                continue
            }
            return value
        }

        return nil
    }
}

enum DeepSeekBalanceParser {
    static func decode(_ data: Data) throws -> DeepSeekBalance {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isAvailable = json["is_available"] as? Bool,
              let infos = json["balance_infos"] as? [[String: Any]],
              let info = infos.first,
              let currency = info["currency"] as? String,
              let totalBalance = info["total_balance"] as? String else {
            throw QuotaBarError.invalidResponse
        }

        return DeepSeekBalance(
            isAvailable: isAvailable,
            currency: currency,
            totalBalance: totalBalance,
            grantedBalance: info["granted_balance"] as? String,
            toppedUpBalance: info["topped_up_balance"] as? String
        )
    }
}
