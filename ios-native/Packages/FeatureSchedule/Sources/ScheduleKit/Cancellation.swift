import Foundation

extension Error {
    /// 任务被取消（页面重建、切换学期等）。这不是故障，UI 不应当作错误展示。
    /// 包含 Swift 并发取消、URLSession 的 `.cancelled`，以及被它们包装的情形。
    public var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error { return underlying.isCancellation }
        return false
    }
}
