import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareImportView(context: extensionContext))
        addChild(host); view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}

private struct ShareImportView: View {
    let context: NSExtensionContext?
    @State private var link: String?
    @State private var message: String?
    @State private var loading = true
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.badge.plus").font(.largeTitle).foregroundStyle(.orange).accessibilityHidden(true)
                Text("保存订阅链接").font(.title2.bold())
                Text("仅保存到此设备的钥匙串。下次打开 ByteKibble 后，可确认添加；此操作不会联网查询或上传链接。")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if loading { ProgressView() }
                if let message { Text(message).foregroundStyle(.secondary) }
                Spacer()
                Button("保存到 ByteKibble") {
                    guard let link else { return }
                    do {
                        try PendingSharedLink.save(link)
                        context?.completeRequest(returningItems: nil)
                    } catch {
                        message = String(localized: "未能保存。请解锁设备；若已有待添加链接，请先在 ByteKibble 中处理。")
                    }
                }.buttonStyle(.glassProminent).controlSize(.large).disabled(link == nil)
            }.padding(28)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { context?.cancelRequest(withError: CocoaError(.userCancelled)) } } }
        }.task {
            defer { loading = false }
            do {
                let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
                guard providers.count <= 4 else { throw QuotaError.invalidLink }
                var found: Set<String> = []
                for provider in providers {
                    let type = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : UTType.plainText.identifier
                    guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
                    let item = try await provider.loadItem(forTypeIdentifier: type)
                    let text = (item as? URL)?.absoluteString ?? (item as? String)
                    if let text, text.utf8.count <= 16_384, let url = try? SubscriptionLink.parse(text) { found.insert(url.absoluteString) }
                }
                guard found.count == 1 else { throw QuotaError.invalidLink }
                link = found.first
            } catch { message = String(localized: "请选择一条有效的 HTTPS 订阅链接。") }
        }
    }
}
