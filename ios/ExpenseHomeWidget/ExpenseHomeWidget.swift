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
      ?? "₹\(Int(ud?.double(forKey: "expense") ?? 0))"
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

  private func intFromDefaults(_ ud: UserDefaults?, key: String, default d: Int) -> Int {
    guard let obj = ud?.object(forKey: key) else { return d }
    if let n = obj as? NSNumber { return n.intValue }
    if let i = obj as? Int { return i }
    return d
  }
}

// MARK: - Gauge

private struct SemicircleGauge: View {
  var progress: CGFloat

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ArcPath(progress: 1.0)
          .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        ArcPath(progress: progress)
          .stroke(
            AngularGradient(
              colors: [Color(red: 0.98, green: 0.45, blue: 0.09), Color(red: 0.92, green: 0.70, blue: 0.03), Color(red: 0.13, green: 0.77, blue: 0.37)],
              center: .center
            ),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
          )
      }
    }
  }
}

private struct ArcPath: Shape {
  var progress: CGFloat

  func path(in rect: CGRect) -> Path {
    var p = Path()
    let c = CGPoint(x: rect.midX, y: rect.maxY * 0.92)
    let r = min(rect.width, rect.height) * 0.38
    let start = Angle.degrees(180)
    let end = Angle.degrees(180 + 180 * Double(progress.clamped(to: 0...1)))
    p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
    return p
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

// MARK: - Main view

struct ExpenseHomeWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.white)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

      VStack(spacing: 0) {
        SemicircleGauge(progress: CGFloat(entry.gaugeProgress))
          .frame(height: 36)

        HStack(alignment: .top) {
          ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [Color(red: 0.37, green: 0.92, blue: 0.83), Color(red: 0.05, green: 0.58, blue: 0.53)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .frame(width: 44, height: 44)
            Text("\(entry.calendarDay)")
              .font(.system(size: 16, weight: .heavy))
              .foregroundColor(.white)
              .padding(.top, 4)
          }

          Spacer(minLength: 4)

          if entry.paceVisible && !entry.paceLabel.isEmpty {
            VStack(alignment: .trailing, spacing: 2) {
              Image(systemName: entry.paceIsHigh ? "arrow.up.right" : "checkmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.09, green: 0.50, blue: 0.24))
              Text(entry.paceLabel)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(Color(red: 0.09, green: 0.50, blue: 0.24))
            }
          }
        }
        .padding(.top, 2)

        Text(entry.cardPeriodTitle)
          .font(.system(size: 15, weight: .heavy))
          .foregroundColor(Color(white: 0.07))
          .padding(.top, 4)

        if !entry.modeShort.isEmpty {
          Text(entry.modeShort)
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(Color.black.opacity(0.45))
        }

        Text(entry.expenseDisplay)
          .font(.system(size: 22, weight: .heavy))
          .foregroundColor(Color(red: 0.86, green: 0.15, blue: 0.15))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .padding(.top, 2)
          .padding(.bottom, 6)

        GeometryReader { g in
          let w = g.size.width
          let t = CGFloat(entry.barProgress.clamped(to: 0...1))
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.black.opacity(0.08))
              .frame(height: 5)
            Capsule()
              .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
              .frame(width: max(0, w * t), height: 5)
            if t > 0.001 {
              Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color(red: 0.13, green: 0.77, blue: 0.37), lineWidth: 2))
                .offset(x: (w * t) - 5, y: 0)
            }
          }
        }
        .frame(height: 12)
      }
      .padding(12)
    }
    .padding(6)
  }
}

struct ExpenseHomeWidget: Widget {
  let kind: String = "ExpenseHomeWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ExpenseHomeWidgetEntryView(entry: entry)
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
