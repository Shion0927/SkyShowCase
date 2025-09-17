import Foundation

enum WeatherError: LocalizedError {
    case invalidURL
    case decodingFailed
    case serverError(status: Int)
    case emptyResult
    case cancelled
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "不正なURLです。"
        case .decodingFailed: return "データの解析に失敗しました。"
        case .serverError(let s): return "サーバーエラー（\(s)）。"
        case .emptyResult: return "該当する結果がありません。"
        case .cancelled: return "リクエストはキャンセルされました。"
        case .other(let e): return e.localizedDescription
        }
    }
}
