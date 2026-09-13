import AppKit
import SwiftUI

/// Completing the introduction changes only this app-owned preference.
struct WelcomeState {
    let defaults: UserDefaults
    static let key = "welcomeCompleted.v1"
    var shouldPresent: Bool { !defaults.bool(forKey: Self.key) }
    func complete() { defaults.set(true, forKey: Self.key) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuController: MenuPopoverController?
    func applicationDidFinishLaunching(_ notification: Notification) {
#if !BYTEKIBBLE_ACCEPTANCE
        // An accessory app has no visible app menu, but standard edit commands
        // still need a responder-chain menu for text-field keyboard shortcuts.
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
                                     ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
                                     ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let redo = editMenu.insertItem(withTitle: "Redo", action: Selector("redo:"), keyEquivalent: "z", at: 1)
        redo.keyEquivalentModifierMask = [.command, .shift]
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        menuController = MenuPopoverController(vm: ViewModel())
        if WelcomeState(defaults: .standard).shouldPresent {
            DispatchQueue.main.async { WelcomeController.shared.show() }
        }
#endif
    }
}

@MainActor
final class WelcomeController: NSObject, NSWindowDelegate {
    static let shared = WelcomeController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 660),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.t("欢迎使用字节猫粮")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: WelcomeView { [weak self] in self?.window?.close() })
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        WelcomeState(defaults: .standard).complete()
        window = nil
    }
}

struct WelcomeView: View {
    var finish: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { colorScheme == .dark }
    private var ink: Color { dark ? Color(red: 1, green: 0.94, blue: 0.80) : Color(red: 0.25, green: 0.13, blue: 0.04) }
    private var secondaryInk: Color { dark ? Color(red: 0.78, green: 0.73, blue: 0.65) : Color(red: 0.43, green: 0.34, blue: 0.24) }
    private var amber: Color { Color(red: 1, green: 0.72, blue: 0.25) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text(L10n.t("欢迎使用字节猫粮"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let artwork = resourceImage("WelcomeArtwork") {
                    Image(nsImage: artwork).resizable().scaledToFit()
                        .frame(width: 185, height: 130)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 150)
            Text(L10n.t("剩余流量，抬头就知道。"))
                .font(.system(size: 16)).foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .padding(.bottom, 30)
            VStack(alignment: .leading, spacing: 22) {
                feature("chart.pie", "留在菜单栏", "查看剩余流量、用量与重置倒计时；数据缺失或更新失败时会如实提示。")
                feature("link", "连接已有订阅", "自动查找支持的 Clash 客户端，也可以在面板中粘贴订阅链接。")
                feature("lock.shield", "不改变你的代理设置", "仅读取订阅信息并向订阅地址查询，不切换节点、不修改客户端配置。")
            }
            Spacer(minLength: 20)
            VStack(spacing: 14) {
                Label(L10n.t("点击屏幕顶部的菜单栏图标，打开流量面板。"), systemImage: "menubar.arrow.up.rectangle")
                    .font(.caption).foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: finish) {
                    Text(L10n.t("开始使用"))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(Color(red: 0.25, green: 0.13, blue: 0.04))
                        .background(amber, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                if let logo = resourceImage("MULabsWordmark") {
                    Image(nsImage: logo).resizable().renderingMode(.template)
                        .foregroundStyle(ink.opacity(0.8))
                        .frame(width: 96, height: 43.52)
                        .frame(width: 96, height: 12)
                        .clipped()
                        .accessibilityLabel("MU LABS")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 34)
        .padding(.top, 22)
        .padding(.bottom, 26)
        .frame(width: 520, height: 660)
        .background {
            LinearGradient(colors: dark
                ? [Color(red: 0.17, green: 0.15, blue: 0.12), Color(red: 0.11, green: 0.10, blue: 0.09)]
                : [Color(red: 1, green: 0.97, blue: 0.85), Color(red: 1, green: 0.985, blue: 0.93)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 20).fill(amber.opacity(dark ? 0.06 : 0.13))
                        .frame(width: 68, height: 68).offset(x: -32, y: -12)
                    Spacer()
                    RoundedRectangle(cornerRadius: 24).fill(amber.opacity(dark ? 0.04 : 0.10))
                        .frame(width: 88, height: 88).offset(x: 24, y: 12)
                }
                Spacer()
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
        .clipped()
    }

    private func feature(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.system(size: 23, weight: .medium))
                .frame(width: 50, height: 50).foregroundStyle(ink)
                .background(amber.opacity(dark ? 0.15 : 0.26), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t(title)).font(.headline).foregroundStyle(ink)
                Text(L10n.t(body)).font(.callout).foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func resourceImage(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
