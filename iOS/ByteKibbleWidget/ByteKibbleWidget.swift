import SwiftUI
import WidgetKit

struct QuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct QuotaTimeline: TimelineProvider {
    func placeholder(in context: Context) -> QuotaEntry { QuotaEntry(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
        completion(QuotaEntry(date: .now, snapshot: WidgetSnapshotFile.url.flatMap { WidgetSnapshotFile.read(from: $0) }))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshotFile.url.flatMap { WidgetSnapshotFile.read(from: $0) }
        var entries = [QuotaEntry(date: now, snapshot: snapshot)]
        if let snapshot, !snapshot.isStale(at: now) {
            entries.append(QuotaEntry(date: snapshot.observed.addingTimeInterval(3600), snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }
}

struct QuotaWidgetView: View {
    let entry: QuotaEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label {
                    if let value = entry.snapshot?.remaining {
                        Text("\(Double(value) / 1_073_741_824, specifier: "%.1f") GiB").privacySensitive()
                    } else { Text("暂无读数") }
                } icon: { Image(systemName: entry.snapshot?.isStale(at: entry.date) == false ? "chart.pie" : "clock") }
            case .accessoryCircular:
                if let snapshot = entry.snapshot, let remaining = snapshot.remaining, let total = snapshot.total, total > 0 {
                    Gauge(value: Double(remaining) / Double(total)) {
                        Image(systemName: snapshot.isStale(at: entry.date) ? "clock" : "chart.pie")
                    } currentValueLabel: {
                        Text("\(Int(Double(remaining) / Double(total) * 100))%")
                    }.gaugeStyle(.accessoryCircular).privacySensitive()
                } else {
                    Image(systemName: "chart.pie").accessibilityLabel(Text("暂无读数"))
                }
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Label("剩余流量", systemImage: "chart.pie").font(.caption)
                    if let value = entry.snapshot?.remaining {
                        Text("\(Double(value) / 1_073_741_824, specifier: "%.1f") GiB").font(.headline).privacySensitive()
                        Text(entry.snapshot?.isStale(at: entry.date) == false ? String(localized: "上次读取") : String(localized: "旧读数 · 打开 App 更新")).font(.caption2)
                    } else { Text("暂无读数").font(.caption) }
                }
            default: homeContent
            }
        }.containerBackground(.background, for: .widget)
    }
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("剩余流量", systemImage: "pawprint.fill").font(.caption).foregroundStyle(.secondary)
            if let snapshot = entry.snapshot {
                if let remaining = snapshot.remaining {
                    Text("\(Double(remaining) / 1_073_741_824, specifier: "%.1f") GiB")
                        .font(.system(.title2, design: .rounded, weight: .bold)).minimumScaleFactor(0.7)
                        .lineLimit(1).privacySensitive()
                } else { Text("暂无读数").font(.headline) }
                if let remaining = snapshot.remaining, let total = snapshot.total, total > 0 {
                    ProgressView(value: Double(remaining) / Double(total)).tint(.primary).privacySensitive()
                }
                Spacer(minLength: 0)
                Text(snapshot.isStale(at: entry.date) ? String(localized: "旧读数 · 打开 App 更新") : String(localized: "上次读取"))
                    .font(.caption2).foregroundStyle(.secondary)
                Text(snapshot.observed, style: .time).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("选择一个订阅").font(.headline)
                Text("打开 App，在设置中选择小组件订阅。已有订阅需先查询流量。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main struct ByteKibbleQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotFile.kind, provider: QuotaTimeline()) { QuotaWidgetView(entry: $0) }
            .configurationDisplayName("剩余流量")
            .description("查看本机保存的流量快照。打开 App 查询最新读数。")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
