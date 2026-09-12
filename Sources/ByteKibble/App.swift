import SwiftUI
import ServiceManagement
import AppKit

@main
struct ByteKibbleApp: App {
    @StateObject private var vm: ViewModel

    init() {
        if let out = Self.previewOutputDir {
            Self.renderPreviews(to: out)
            exit(0)
        }
        _vm = StateObject(wrappedValue: ViewModel())
    }

    /// `--render-preview <目录>`：用模拟数据渲染 Clash 客户端场景的面板/菜单栏 PNG 后退出
    private static var previewOutputDir: String? {
        guard let i = CommandLine.arguments.firstIndex(of: "--render-preview"),
              CommandLine.arguments.count > i + 1 else { return nil }
        return CommandLine.arguments[i + 1]
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(vm: vm)
        } label: {
            MenubarLabel(vm: vm)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏标签：整块内容（饼环 + 数值 + ⟳ 倒计时）预渲染为一张位图。
/// SwiftUI 的 MenuBarExtra 标签宿主在真机会丢弃自定义视图与颜色（只剩纯文本），
/// 位图是唯一能完整渲染的路径，故整体离屏绘制后以 NSImage 呈现。
struct MenubarLabel: View {
    @ObservedObject var vm: ViewModel

    var body: some View {
        if let img = MenubarImageRenderer.image(for: vm) {
            Image(nsImage: img)
                .interpolation(.high)
        } else {
            Text(vm.menubarValueText)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

@MainActor
enum MenubarImageRenderer {
    private static var cache: [String: NSImage] = [:]

    static func image(for vm: ViewModel) -> NSImage? {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let ratio = Int(vm.menubarUsedRatio * 100)
        let days = vm.menubarDaysText
        let level = vm.warningLevel
        let key = "\(vm.menubarValueText)|\(days ?? "-")|\(level)|\(dark)|\(ratio)"
        if let hit = cache[key] { return hit }
        guard let img = draw(value: vm.menubarValueText, days: days,
                             ratio: vm.menubarUsedRatio, level: level, dark: dark) else { return nil }
        if cache.count > 12 { cache.removeAll() }
        cache[key] = img
        return img
    }

    private static func levelColor(_ level: WarningLevel, dark: Bool) -> NSColor {
        switch level {
        case .warn: return .systemOrange
        case .danger: return .systemRed
        case .normal: return dark ? .white : NSColor(calibratedWhite: 0.12, alpha: 1)
        }
    }

    private static func draw(value: String, days: String?, ratio: Double,
                             level: WarningLevel, dark: Bool) -> NSImage? {
        let main = levelColor(level, dark: dark)
        // 倒计时用中性色（暗色主题白色 / 浅色主题黑色），与预警色数值形成主次
        let neutral = dark ? NSColor.white : NSColor(calibratedWhite: 0.12, alpha: 1)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        let tailFont = valueFont

        let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: main]
        let valueSize = (value as NSString).size(withAttributes: valueAttrs)

        let pie: CGFloat = 17
        let pieGap: CGFloat = 4.5
        let tailGap: CGFloat = 4
        var width = pie + pieGap + ceil(valueSize.width)
        var dotSize = NSSize.zero, symSize = NSSize.zero, daysSize = NSSize.zero
        var symbolImg: NSImage?
        if days != nil {
            dotSize = ("·" as NSString).size(withAttributes: [.font: tailFont])
            // 手绘 ⟳：弧线粗细与菜单栏饼环一致（3pt）
            symSize = NSSize(width: 15, height: 15)
            daysSize = (days! as NSString).size(withAttributes: [.font: tailFont])
            width += tailGap + ceil(dotSize.width) + 2 + symSize.width + 3 + ceil(daysSize.width)
        }

        let scale: CGFloat = 3
        let h: CGFloat = 22
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(h * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: width, height: h)

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = ctx

        // 饼环：轨道 + 已用比例弧（圆头）
        let r = (pie - 3.2) / 2
        let center = NSPoint(x: pie / 2, y: h / 2)
        let lineWidth: CGFloat = 3
        let track = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        track.lineWidth = lineWidth
        main.withAlphaComponent(0.22).setStroke()
        track.stroke()
        let arc = NSBezierPath()
        let used = min(max(ratio, 0.04), 1)
        arc.appendArc(withCenter: center, radius: r, startAngle: 90,
                      endAngle: 90 - 360 * used, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        main.setStroke()
        arc.stroke()

        // 数值
        var x = pie + pieGap
        let valueY = (h - valueSize.height) / 2
        (value as NSString).draw(at: NSPoint(x: x, y: valueY), withAttributes: valueAttrs)
        x += ceil(valueSize.width)

        // 倒计时：· ⟳ N天
        if let days {
            x += tailGap
            ("·" as NSString).draw(at: NSPoint(x: x, y: (h - dotSize.height) / 2),
                                   withAttributes: [.font: tailFont, .foregroundColor: neutral])
            x += ceil(dotSize.width) + 2
            let arrow = resetArrow(size: 15, color: neutral, lineWidth: 3)
            arrow.draw(in: NSRect(x: x, y: (h - symSize.height) / 2,
                                  width: symSize.width, height: symSize.height),
                       from: .zero, operation: .copy, fraction: 1)
            x += symSize.width + 3
            (days as NSString).draw(at: NSPoint(x: x, y: (h - daysSize.height) / 2),
                                    withAttributes: [.font: tailFont, .foregroundColor: neutral])
        }

        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: rep.size)
        out.addRepresentation(rep)
        return out
    }

    /// 手绘重置箭头 ⟳：开口圆弧 + 切向三角箭头，线宽与菜单栏饼环一致
    private static func resetArrow(size: CGFloat, color: NSColor, lineWidth: CGFloat) -> NSImage {
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        let c = NSPoint(x: size / 2, y: size / 2)
        let r = size / 2 - lineWidth / 2 - 0.5
        let arc = NSBezierPath()
        arc.appendArc(withCenter: c, radius: r, startAngle: 40, endAngle: 40 - 270, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()
        // 箭头：弧终点处沿顺时针切线方向的小三角
        let endAngle = (40.0 - 270.0) * .pi / 180
        let end = NSPoint(x: c.x + r * cos(endAngle), y: c.y + r * sin(endAngle))
        let t = NSPoint(x: sin(endAngle), y: -cos(endAngle))
        let n = NSPoint(x: -t.y, y: t.x)
        let tip = NSPoint(x: end.x + t.x * 5.5, y: end.y + t.y * 5.5)
        let b1 = NSPoint(x: end.x + n.x * 3.0, y: end.y + n.y * 3.0)
        let b2 = NSPoint(x: end.x - n.x * 3.0, y: end.y - n.y * 3.0)
        let head = NSBezierPath()
        head.move(to: tip)
        head.line(to: b1)
        head.line(to: b2)
        head.close()
        color.setFill()
        head.fill()
        out.unlockFocus()
        return out
    }

    private static func tintedSymbol(_ name: String, _ color: NSColor, point: CGFloat) -> NSImage? {
        guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: point, weight: .medium)) else { return nil }
        let size = sym.size
        let out = NSImage(size: size)
        out.lockFocus()
        sym.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        out.unlockFocus()
        return out
    }
}

// MARK: - 预览渲染（--render-preview）：模拟 Clash 客户端数据源

extension ByteKibbleApp {
    private static func mockVM(_ target: SubTarget, _ sample: QuotaSample?) -> ViewModel {
        let vm = ViewModel(preview: true)
        vm.targets = [target]
        vm.selectedID = target.id
        if let sample { vm.samples[target.id] = sample }
        vm.now = Date()
        return vm
    }

    private static func savePNG(_ view: some View, _ path: String, _ name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("!! 渲染失败: \(name)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: path + "/" + name))
        print("已生成 \(name)")
    }

    private static func renderPreviews(to dir: String) {
        PreviewMode.isActive = true
        print("[p] 开始")
        _ = NSApplication.shared
        print("[p] NSApplication OK")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let now = Date()
        // 场景一：Clash Verge 数据源，实时查询，套餐信息/重置日缺失（Clash 标准订阅头没有这些字段）
        let verge = SubTarget(id: "m1", name: "sub.example.com", origin: "Clash Verge",
                              url: "https://sub.example.com/abc", cached: nil)
        let vergeSample = QuotaSample(
            uploaded: 96_600_000_000, downloaded: 521_600_000_000, total: 1_099_511_627_776,
            expireAt: now.addingTimeInterval(86400 * 180), resetDay: nil, planName: nil,
            fetchedAt: now, source: .live)

        // 场景二：ClashX Meta 数据源，余量 15%（橙色预警），同样无重置日
        let clashx = SubTarget(id: "m2", name: "air.example.org", origin: "ClashX Meta",
                               url: "https://air.example.org/sub", cached: nil)
        let warnSample = QuotaSample(
            uploaded: 700_000_000_000, downloaded: 233_000_000_000, total: 1_099_511_627_776,
            expireAt: now.addingTimeInterval(86400 * 45), resetDay: nil, planName: nil,
            fetchedAt: now, source: .live)

        func panel(_ vm: ViewModel, dark: Bool) -> some View {
            MenuView(vm: vm)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, dark ? .dark : .light)
        }

        savePNG(panel(mockVM(verge, vergeSample), dark: false), dir, "panel-verge-light.png")
        print("[p] 面板1 OK")
        savePNG(panel(mockVM(verge, vergeSample), dark: true), dir, "panel-verge-dark.png")
        print("[p] 面板2 OK")
        savePNG(panel(mockVM(clashx, warnSample), dark: false), dir, "panel-clashx-warning.png")
        print("[p] 面板3 OK")

        // 菜单栏标签：有重置日（SNTP）vs 无重置日（Clash），深色菜单栏底
        let sntp = Providers.scanAll().first
        print("[p] scanAll OK: \(sntp?.name ?? "无")")
        let strip = VStack(spacing: 10) {
            if let s = sntp {
                MenubarLabel(vm: mockVM(s, s.cached))
            }
            MenubarLabel(vm: mockVM(verge, vergeSample))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(white: 0.22))
        savePNG(strip, dir, "menubar-labels.png")
        print("[p] 菜单栏 OK")
    }
}

// MARK: - 猫粮图标（用户提供的 SVG，袋身镂空 + 爪印，运行时按预警色着色）

enum CatIconAsset {
    private static var cache: [String: NSImage] = [:]

    private static let base: NSImage? = {
        guard let url = Bundle.module.url(forResource: "catfood", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()

    /// 生成指定点尺寸的着色图标（高分辨率位图 + 小的 NSImage 固有尺寸，
    /// 避免菜单栏标签里 Image(nsImage:) 按原始尺寸撑爆布局）
    static func tinted(_ color: Color, size: CGFloat = 16) -> NSImage? {
        guard let base else { return nil }
        let rgb = NSColor(color).usingColorSpace(.sRGB)
        let key = rgb.map { "\($0.redComponent)|\($0.greenComponent)|\($0.blueComponent)|\(Int(size))" } ?? "default|\(Int(size))"
        if let cached = cache[key] { return cached }

        let scale: CGFloat = 4
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size * scale), pixelsHigh: Int(size * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = ctx
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        // SVG 竖向内容占 viewBox 约 85%，放大不超过 1.12 倍，避免上下截断
        let zoom: CGFloat = 1.12
        let draw = NSRect(x: -size * (zoom - 1) / 2, y: -size * (zoom - 1) / 2,
                          width: size * zoom, height: size * zoom)
        base.draw(in: draw, from: .zero, operation: .copy, fraction: 1.0)
        ctx?.compositingOperation = .sourceAtop
        (rgb ?? .white).setFill()
        rect.fill()
        NSGraphicsContext.restoreGraphicsState()

        let out = NSImage(size: rep.size)
        out.addRepresentation(rep)
        cache[key] = out
        return out
    }
}

struct CatFoodIcon: View {
    var color: Color = .accentColor
    var size: CGFloat = 16

    var body: some View {
        if let ns = CatIconAsset.tinted(color, size: size) {
            Image(nsImage: ns)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "pawprint.fill")
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Liquid Glass 兼容层（macOS 26+ 玻璃质感，旧系统优雅回退）

/// 预览渲染时玻璃材质离屏画不出来，强制走回退卡片样式
enum PreviewMode {
    static var isActive = false
}

extension View {
    /// 面板整体包一层玻璃容器，让相邻玻璃元件相互融合
    @ViewBuilder
    func liquidContainer() -> some View {
        if #available(macOS 26.0, *), !PreviewMode.isActive {
            GlassEffectContainer(spacing: 10) { self }
        } else {
            self
        }
    }

    /// 玻璃卡片；旧系统回退为浅色卡片 + 描边
    @ViewBuilder
    func glassCard<S: InsettableShape>(in shape: S) -> some View {
        if #available(macOS 26.0, *), !PreviewMode.isActive {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(Color.primary.opacity(0.055), in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
        }
    }

    /// 玻璃按钮；旧系统回退为 bordered；预览渲染下用纯文本（AppKit 部件离屏画不出来）
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *), !PreviewMode.isActive {
            self.buttonStyle(.glass)
        } else if PreviewMode.isActive {
            self.buttonStyle(.plain).foregroundStyle(Color.accentColor)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// 面板实色底：macOS 15+ 用系统窗口容器背景（四角按窗口形状精确裁切，无瑕疵）；
    /// 旧系统回退为手绘圆角矩形
    @ViewBuilder
    func panelSolidBackground() -> some View {
        if #available(macOS 15.0, *) {
            self.containerBackground(for: .window) {
                Color(nsColor: .windowBackgroundColor)
            }
        } else {
            self.background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
        }
    }

    /// 数字变化时的滚动过渡（macOS 14+）
    @ViewBuilder
    func numericTransition(value: some Equatable) -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.numericText())
                .animation(.snappy(duration: 0.35), value: value)
        } else {
            self
        }
    }
}

// MARK: - 面板

struct MenuView: View {
    @ObservedObject var vm: ViewModel
    @State private var customURL = ""
    @State private var showAdd = false
    @State private var autostartOn = false

    var body: some View {
        main.liquidContainer()
            .padding(16)
            .frame(width: 380)
            .panelSolidBackground()
            .onAppear {
                vm.menuOpened()
                if !vm.isPreview {
                    let st = SMAppService.mainApp.status
                    autostartOn = (st == .enabled || st == .requiresApproval)
                }
            }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let t = vm.selected, let s = vm.sample(for: t) {
                header(t: t, s: s)
                heroCard(s)
                tileGrid(s)
            } else {
                emptyState
            }
            Divider()
            footer
        }
    }

    private func originDisplay(_ id: String) -> String {
        switch id {
        case "sntp": return L10n.originSntp
        case "custom": return L10n.originCustom
        default: return id
        }
    }

    // MARK: 头部：猫粮碗徽标 + 套餐名 + 重置倒计时胶囊

    private func header(t: SubTarget, s: QuotaSample) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.planName ?? t.name)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("\(originDisplay(t.origin)) · \(s.source.rawValue)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rd = s.resetDay {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text(vm.countdownText(days: rd, now: vm.now))
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .foregroundStyle(vm.warningLevel.color)
                .glassCard(in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: 主卡片：剩余流量大数字 + 渐变进度条

    private func heroCard(_ s: QuotaSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.remainingTraffic)
                .font(.callout)
                .foregroundStyle(.secondary)
            heroLine(s)
            GradientBar(ratio: s.usedRatio, level: vm.warningLevel)
            HStack(spacing: 6) {
                Text(L10n.used(Fmt.bytes(s.used)))
                    .font(.callout)
                    .monospacedDigit()
                Spacer()
                Text(L10n.usedPercent(String(format: "%.1f", min(s.usedRatio, 1) * 100)))
                    .font(.callout.weight(.bold))
                    .foregroundStyle(vm.warningLevel.color)
                    .monospacedDigit()
                    .numericTransition(value: Int(s.usedRatio * 1000))
                Spacer()
                Text(L10n.total(Fmt.bytes(s.total)))
                    .font(.callout)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }


    /// 剩余流量行：大数值 + 小总量的富文本（单 Text 共享基线，规避 HStack 基线传递失效）
    private func heroLine(_ s: QuotaSample) -> Text {
        let desc = NSFont.systemFont(ofSize: 34, weight: .bold).fontDescriptor.withDesign(.rounded)
        let valueFont = desc.flatMap { NSFont(descriptor: $0, size: 34) } ?? .boldSystemFont(ofSize: 34)
        var a = AttributedString(Fmt.bytes(s.remaining))
        a.appKit.font = valueFont
        a.appKit.foregroundColor = NSColor(vm.warningLevel.color)
        var b = AttributedString(" / \(Fmt.bytes(s.total))")
        b.appKit.font = .systemFont(ofSize: 13)
        b.appKit.foregroundColor = .secondaryLabelColor
        a += b
        return Text(a)
    }

    // MARK: 信息磁贴：上行 / 下行 / 流量重置 / 套餐到期

    private func tileGrid(_ s: QuotaSample) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            tile(icon: "arrow.up", label: L10n.uploadTile, value: Fmt.bytes(s.uploaded))
            tile(icon: "arrow.down", label: L10n.downloadTile, value: Fmt.bytes(s.downloaded))
            tile(icon: "arrow.clockwise",
                 label: L10n.resetTile,
                 value: s.resetDay.map { Fmt.date(Fmt.nextReset(days: $0) ?? Date()) } ?? "—",
                 sub: s.resetDay.map { rd -> String in
                     let cd = vm.countdownText(days: rd, now: vm.now)
                     return cd == L10n.today ? L10n.resetToday : L10n.daysAfter(cd)
                 })
            tile(icon: "calendar",
                 label: L10n.expireTile,
                 value: s.expireAt.map { Fmt.date($0) } ?? "—",
                 sub: s.expireAt.map { L10n.inDays(Fmt.daysUntil($0)) })
        }
    }

    private func tile(icon: String, label: String, value: String, sub: String? = nil) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(vm.warningLevel.color)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let sub {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 空状态

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.emptyTitle, systemImage: "tray")
                .font(.headline)
            Text(L10n.emptyBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .glassCard(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: 底部操作区

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if vm.targets.count > 1 {
                Picker("订阅", selection: $vm.selectedID) {
                    ForEach(vm.targets) { t in
                        Text("\(t.name)（\(t.origin)）").tag(t.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.callout)
            }

            if let t = vm.selected, t.origin == "custom" {
                Button(L10n.removeManualSub, role: .destructive) {
                    vm.removeCustom(id: t.id)
                }
                .font(.callout)
                .buttonStyle(.borderless)
            }

            addSubscriptionCard

            HStack(spacing: 8) {
                Button {
                    Task { await vm.refreshLive() }
                } label: {
                    if vm.fetching {
                        ProgressView().controlSize(.small)
                            .frame(width: 62)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text(L10n.refresh)
                        }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(vm.warningLevel.color)
                    }
                }
                .disabled(vm.fetching || vm.selected == nil)
                .glassButton()

                Spacer()

                Button {
                    autostartOn.toggle()
                    do {
                        try autostartOn ? SMAppService.mainApp.register()
                                        : SMAppService.mainApp.unregister()
                    } catch {
                        autostartOn.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: autostartOn ? "power.circle.fill" : "power.circle")
                        Text(L10n.launchAtLogin)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(vm.warningLevel.color)
                }
                .glassButton()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(L10n.quit)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(vm.warningLevel.color)
                }
                .glassButton()
            }

            HStack {
                Spacer()
                Text(AppInfo.versionLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .onTapGesture { AppInfo.openRepo() }
                Spacer()
            }
            .padding(.top, 2)

            if let line = vm.statusLine {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: 添加订阅卡片

    private var addSubscriptionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // 不加动画：MenuBarExtra 窗口对带过渡动画的高度变化可能不重算，导致底部被截断
                showAdd.toggle()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(vm.warningLevel.color)
                        .font(.system(size: 17))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.addSubTitle)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L10n.addSubSubtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdd ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdd {
                HStack(spacing: 8) {
                    TextField("https://sub.example.com/...?token=…", text: $customURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .onSubmit { submitCustom() }
                    Button(L10n.add) { submitCustom() }
                        .buttonStyle(.borderedProminent)
                        .tint(vm.warningLevel.color)
                        .font(.callout.weight(.semibold))
                        .disabled(!customURL.trimmingCharacters(in: .whitespaces).hasPrefix("http"))
                }
                .padding(.top, 10)
            }
        }
        .padding(12)
        .glassCard(in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func submitCustom() {
        let u = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard u.hasPrefix("http") else { return }
        vm.addCustom(url: u)
        customURL = ""
        showAdd = false
    }
}

/// 猫爪印：掌垫 + 三趾（品牌水印元素）
struct PawPrint: View {
    var color: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Ellipse().fill(color)
                    .frame(width: w * 0.54, height: h * 0.40)
                    .position(x: w * 0.5, y: h * 0.70)
                Ellipse().fill(color).frame(width: w * 0.19, height: h * 0.24).position(x: w * 0.20, y: h * 0.32)
                Ellipse().fill(color).frame(width: w * 0.19, height: h * 0.24).position(x: w * 0.50, y: h * 0.22)
                Ellipse().fill(color).frame(width: w * 0.19, height: h * 0.24).position(x: w * 0.80, y: h * 0.32)
            }
        }
    }
}

/// 猫头剪影：圆脸 + 一对尖耳（单 Path 填充，半透明下无叠色）
struct CatHeadShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // 脸
        p.addEllipse(in: CGRect(x: r.width * 0.06, y: r.height * 0.20,
                                width: r.width * 0.88, height: r.height * 0.80))
        // 双耳
        p.move(to: CGPoint(x: r.width * 0.10, y: r.height * 0.34))
        p.addLine(to: CGPoint(x: r.width * 0.15, y: r.height * 0.02))
        p.addLine(to: CGPoint(x: r.width * 0.44, y: r.height * 0.17))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.width * 0.90, y: r.height * 0.34))
        p.addLine(to: CGPoint(x: r.width * 0.85, y: r.height * 0.02))
        p.addLine(to: CGPoint(x: r.width * 0.56, y: r.height * 0.17))
        p.closeSubpath()
        return p
    }
}

/// 猫耳：顶部微圆的三角形，成对放在主卡片顶边
struct CatEarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.3))
        p.closeSubpath()
        return p
    }
}

/// 渐变流量进度条
struct GradientBar: View {
    let ratio: Double
    let level: WarningLevel

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [level.color.opacity(0.65), level.color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, g.size.width * min(max(ratio, 0), 1)))
            }
        }
        .frame(height: 7)
    }
}
