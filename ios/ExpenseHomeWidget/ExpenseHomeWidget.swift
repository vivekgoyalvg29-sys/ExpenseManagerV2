import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ExpenseEntry: TimelineEntry {
  let date: Date
  let cardPeriodTitle: String
  let expenseDisplay: String
  let calendarDay: Int
  let paceVisible: Bool
  let paceLabel: String
  let paceIsHigh: Bool
  let barProgress: Double
  let gaugeProgress: Double
  let modeShort: String
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> ExpenseEntry {
    sampleEntry()
  }

  func getSnapshot(in context: Context, completion: @escaping (ExpenseEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseEntry>) -> Void) {
    let entry = loadEntry()
    let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
    completion(timeline)
  }

  private func sampleEntry() -> ExpenseEntry {
    ExpenseEntry(
      date: Date(),
      cardPeriodTitle: "Apr-26",
      expenseDisplay: "₹94,664",
      calendarDay: 26,
      paceVisible: true,
      paceLabel: "High",
      paceIsHigh: true,
      barProgress: 0.85,
      gaugeProgress: 0.85,
      modeShort: "Month"
    )
  }

  private func loadEntry() -> ExpenseEntry {
    let ud = UserDefaults(suiteName: "group.com.example.expense_manager")

    let cardPeriodTitle = ud?.string(forKey: "widget_card_period_title") ?? "—"
    let expenseDisplay = ud?.string(forKey: "widget_expense_display")
      ?? fallbackExpenseString(ud: ud)
    let calendarDay = intFromDefaults(ud, key: "widget_calendar_day", default: 1)
    let paceVisible = intFromDefaults(ud, key: "widget_pace_visible", default: 0) == 1
    let paceLabel = ud?.string(forKey: "widget_pace_label") ?? ""
    let paceIsHigh = intFromDefaults(ud, key: "widget_pace_is_high", default: 0) == 1
    let barThousandths = intFromDefaults(ud, key: "widget_bar_progress_thousandths", default: 0)
    let gaugeThousandths = intFromDefaults(ud, key: "widget_gauge_progress_thousandths", default: barThousandths)
    let modeShort = ud?.string(forKey: "widget_mode_short") ?? ""

    return ExpenseEntry(
      date: Date(),
      cardPeriodTitle: cardPeriodTitle,
      expenseDisplay: expenseDisplay,
      calendarDay: max(1, min(31, calendarDay)),
      paceVisible: paceVisible,
      paceLabel: paceLabel,
      paceIsHigh: paceIsHigh,
      barProgress: Double(barThousandths) / 1000.0,
      gaugeProgress: Double(gaugeThousandths) / 1000.0,
      modeShort: modeShort
    )
  }

  private func fallbackExpenseString(ud: UserDefaults?) -> String {
    guard let ud else { return "₹0" }
    if let n = ud.object(forKey: "expense") as? NSNumber {
      return "₹\(Int(n.doubleValue.rounded()))"
    }
    return "₹0"
  }

  private func intFromDefaults(_ ud: UserDefaults?, key: String, default d: Int) -> Int {
    guard let obj = ud?.object(forKey: key) else { return d }
    if let n = obj as? NSNumber { return n.intValue }
    if let i = obj as? Int { return i }
    return d
  }
}

// MARK: - Gauge (solid stroke only — avoids WidgetKit issues with AngularGradient on arcs)

private struct SemicircleGauge: View {
  var progress: CGFloat

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ArcPath(progress: 1.0)
          .stroke(Color.black.opacity(0.14), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        ArcPath(progress: progress)
          .stroke(gaugeStrokeColor(progress: progress), style: StrokeStyle(lineWidth: 4, lineCap: .round))
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
  }

  private func gaugeStrokeColor(progress: CGFloat) -> Color {
    let t = CGFloat(min(max(Double(progress), 0), 1))
    let r = 0.98 + (0.13 - 0.98) * t
    let g = 0.45 + (0.77 - 0.45) * t
    let b = 0.09 + (0.37 - 0.09) * t
    return Color(red: r, green: g, blue: b)
  }
}

private struct ArcPath: Shape {
  var progress: CGFloat

  func path(in rect: CGRect) -> Path {
    var p = Path()
    guard rect.width > 1, rect.height > 1 else { return p }
    let c = CGPoint(x: rect.midX, y: rect.maxY * 0.92)
    let r = min(rect.width, rect.height) * 0.38
    let prog = min(max(Double(progress), 0), 1)
    let start = Angle.degrees(180)
    let end = Angle.degrees(180 + 180 * prog)
    p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
    return p
  }
}

// MARK: - Linear bar (no `let` in ViewBuilder; avoids widget load failures)

private struct WidgetLinearBar: View {
  var progress: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.black.opacity(0.08))
          .frame(width: max(geometry.size.width, 1), height: 5)
        Capsule()
          .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
          .frame(
            width: max(geometry.size.width, 1) * CGFloat(min(max(progress, 0), 1)),
            height: 5
          )
        if min(max(progress, 0), 1) > 0.02 {
          Circle()
            .fill(Color.white)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color(red: 0.13, green: 0.77, blue: 0.37), lineWidth: 2))
            .offset(
              x: max(geometry.size.width, 1) * CGFloat(min(max(progress, 0), 1)) - 4.5,
              y: 0
            )
        }
      }
      .frame(width: max(geometry.size.width, 1), height: 12, alignment: .leading)
    }
    .frame(height: 12)
  }
}

// MARK: - Main view

struct ExpenseHomeWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  var entry: Provider.Entry

  var body: some View {
    VStack(spacing: 0) {
      SemicircleGauge(progress: CGFloat(entry.gaugeProgress))
        .frame(height: family == .systemSmall ? 28 : 34)

      HStack(alignment: .top) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color(red: 0.37, green: 0.92, blue: 0.83),
                  Color(red: 0.05, green: 0.58, blue: 0.53),
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(width: 40, height: 40)
          Text("\(entry.calendarDay)")
            .font(.system(size: family == .systemSmall ? 14 : 15, weight: .heavy))
            .foregroundColor(.white)
            .padding(.top, 3)
        }

        Spacer(minLength: 4)

        if entry.paceVisible && !entry.paceLabel.isEmpty {
          VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: entry.paceIsHigh ? "arrow.up.right" : "checkmark.circle")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color(red: 0.09, green: 0.50, blue: 0.24))
            Text(entry.paceLabel)
              .font(.system(size: 11, weight: .heavy))
              .foregroundColor(Color(red: 0.09, green: 0.50, blue: 0.24))
          }
        }
      }
      .padding(.top, 2)

      Text(entry.cardPeriodTitle)
        .font(.system(size: family == .systemSmall ? 13 : 14, weight: .heavy))
        .foregroundColor(Color(white: 0.07))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.top, 4)

      if !entry.modeShort.isEmpty {
        Text(entry.modeShort)
          .font(.system(size: 9, weight: .regular))
          .foregroundColor(Color.black.opacity(0.45))
          .lineLimit(1)
      }

      Text(entry.expenseDisplay)
        .font(.system(size: family == .systemSmall ? 18 : 20, weight: .heavy))
        .foregroundColor(Color(red: 0.86, green: 0.15, blue: 0.15))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .padding(.top, 2)
        .padding(.bottom, 6)

      WidgetLinearBar(progress: entry.barProgress)
    }
    .padding(10)
  }
}

/// iOS 17+ requires a widget container background or the system shows "Could not load widget".
private struct WidgetEntryContainer: View {
  var entry: ExpenseEntry

  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      ExpenseHomeWidgetEntryView(entry: entry)
        .containerBackground(for: .widget) {
          Color.white
        }
    } else {
      ExpenseHomeWidgetEntryView(entry: entry)
        .padding(4)
        .background(Color.white)
    }
  }
}

struct ExpenseHomeWidget: Widget {
  let kind: String = "ExpenseHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      WidgetEntryContainer(entry: entry)
    }
    .configurationDisplayName("Expense summary")
    .description("Shows expenses for the period you configure in Analysis, with optional budget pace.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct ExpenseHomeWidgetBundle: WidgetBundle {
  @WidgetBundleBuilder
  var body: some Widget {
    ExpenseHomeWidget()
  }
}
