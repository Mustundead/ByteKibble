import AppKit
import SwiftUI
import Combine

/// AppKit owns the complete rounded surface, including its attached arrow.
/// No separate rectangle, triangle, or border crosses their shared edge.
@MainActor
final class MenuPopoverController: NSObject, NSPopoverDelegate {
    private let vm: ViewModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var updates: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    init(vm: ViewModel, allowsSystemChanges: Bool = true) {
        self.vm = vm
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let host = NSHostingController(rootView: MenuView(vm: vm, nativePopover: true,
                                                         allowsSystemChanges: allowsSystemChanges))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.delegate = self
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.setAccessibilityLabel("ByteKibble")
        }
        updates = vm.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLabel() }
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateLabel() }
        }
        updateLabel()
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }
        button.image = MenubarImageRenderer.image(for: vm)
        button.title = button.image == nil ? vm.menubarValueText : ""
        button.setAccessibilityValue(vm.accessibilitySummary)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            let dark = popover.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            window.backgroundColor = PanelBackdrop.solidColor(dark: dark)
            window.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    func popoverDidShow(_ notification: Notification) {
        // A retained hosting view does not run SwiftUI onAppear on every reopen.
        vm.menuOpened()
    }

#if BYTEKIBBLE_ACCEPTANCE
    func showScreenshotPreview() {
        if !popover.isShown { togglePopover() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
        }
    }

    func setPreviewAppearance(dark: Bool) {
        popover.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        popover.contentViewController?.view.window?.backgroundColor = PanelBackdrop.solidColor(dark: dark)
    }
#endif
}
