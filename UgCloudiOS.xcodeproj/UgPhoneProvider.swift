import Foundation

/// Networking scaffold only. Configure this with an authorized, documented API.
/// It intentionally does not guess private UgPhone endpoints.
struct UgPhoneProvider {
    enum ProviderError: LocalizedError {
        case invalidBaseURL
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL: return "Địa chỉ máy chủ không hợp lệ."
            case .notConfigured: return "Chưa cấu hình API chính thức của dịch vụ."
            }
        }
    }

    let baseURL: URL?

    init(baseURLString: String? = nil) {
        if let value = baseURLString, let url = URL(string: value),
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            self.baseURL = url
        } else {
            self.baseURL = nil
        }
    }

    func checkConfiguration() throws {
        guard baseURL != nil else { throw ProviderError.notConfigured }
    }
}
