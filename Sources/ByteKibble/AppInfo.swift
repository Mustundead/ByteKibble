import Foundation
import AppKit

enum AppInfo {
    /// 开源仓库地址（版本号点击跳转）
    static let repoURL = URL(string: "https://github.com/mustundead/ByteKibble")!

    static var versionLine: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        return "version \(short) build \(build)"
    }

    static func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }
}
