import Foundation

protocol ChaportWebViewDataSource: AnyObject {
    var webViewURL: URL? { get }
//    var visitorData: VisitorData? { get }
//    var hashStr: String { get }
    
    func restoreWebView(completion: @escaping (Result<Any?, Error>) -> Void)
    func getTeamIdAsync(completion: @escaping (String) -> Void)
    func onWebViewDidDisappear()
    
//    var onRestoreCompleted: (() -> Void)? { get }
}
