import Foundation

enum AppEnvironment {
    static var isRunningFromAppBundle: Bool {
        let url = Bundle.main.bundleURL
        if url.path.contains("/.build/") {
            return false
        }
        if url.pathExtension == "app" {
            return true
        }
        return url.path.contains(".app/Contents/")
    }
}
