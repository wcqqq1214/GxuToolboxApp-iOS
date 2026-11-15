import WebKit

@MainActor
final class WebSession {
    let dataStore: WKWebsiteDataStore

    init(isolated: Bool) {
        dataStore = isolated ? .nonPersistent() : .default()
    }
}
