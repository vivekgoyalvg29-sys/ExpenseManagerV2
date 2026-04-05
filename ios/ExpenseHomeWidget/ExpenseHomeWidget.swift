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
      cardPeriodTitle: "April-26",
      expenseDisplay: "₹94,664",
      calendarDay: 26,
      paceVisible: true,
      paceLabel: "High",
      paceIsHigh: true,
      barProgress: 0.85,
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

// MARK: - Theme (FinTrack light — matches Android widget / app ColorScheme)

private enum WidgetTheme {
  static let primary = Color(red: 0.91, green: 0.51, blue: 0.39)  // #E88363
  static let secondary = Color(red: 0.95, green: 0.64, blue: 0.53)  // #F2A287
  static let surface = Color(red: 1.0, green: 0.949, blue: 0.925)  // #FFF2EC
  static let surfaceSoft = Color(red: 1.0, green: 0.973, blue: 0.957)  // #FFF8F4
  static let onSurface = Color(red: 0.165, green: 0.102, blue: 0.078)  // #2A1A14
  static let pace = Color(red: 0.09, green: 0.50, blue: 0.24)  // green-700, budget pace
  static let track = Color(red: 0.91, green: 0.82, blue: 0.78).opacity(0.45)  // outline tint
}

// MARK: - Linear bar (no `let` in ViewBuilder; avoids widget load failures)

private struct WidgetLinearBar: View {
  var progress: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(WidgetTheme.track)
          .frame(width: max(geometry.size.width, 1), height: 4)
        Capsule()
          .fill(WidgetTheme.primary)
          .frame(
            width: max(geometry.size.width, 1) * CGFloat(min(max(progress, 0), 1)),
            height: 4
          )
      }
      .frame(width: max(geometry.size.width, 1), height: 8, alignment: .leading)
    }
    .frame(height: 8)
  }
}

// MARK: - Main view

struct ExpenseHomeWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
              LinearGradient(
                colors: [WidgetTheme.secondary, WidgetTheme.primary],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(width: 36, height: 36)
          Text("\(entry.calendarDay)")
            .font(.system(size: family == .systemSmall ? 13 : 14, weight: .heavy))
            .foregroundColor(WidgetTheme.onSurface)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.92))
            )
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.cardPeriodTitle)
              .font(.system(size: family == .systemSmall ? 13 : 14, weight: .semibold))
              .foregroundColor(WidgetTheme.onSurface)
              .lineLimit(1)
              .minimumScaleFactor(0.75)

            if entry.paceVisible && !entry.paceLabel.isEmpty {
              HStack(spacing: 3) {
                Image(systemName: entry.paceIsHigh ? "arrow.up.right" : "checkmark.circle.fill")
                  .font(.system(size: 10, weight: .semibold))
                Text(entry.paceLabel)
                  .font(.system(size: 11, weight: .heavy))
              }
              .foregroundColor(WidgetTheme.pace)
            }
          }

          Text(entry.expenseDisplay)
            .font(.system(size: family == .systemSmall ? 17 : 19, weight: .heavy))
            .foregroundColor(WidgetTheme.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      if !entry.modeShort.isEmpty {
        Text(entry.modeShort)
          .font(.system(size: 9, weight: .regular))
          .foregroundColor(WidgetTheme.onSurface.opacity(0.55))
          .lineLimit(1)
          .padding(.top, 4)
      }

      WidgetLinearBar(progress: entry.barProgress)
        .padding(.top, 6)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }
}

/// iOS 17+ requires a widget container background or the system shows "Could not load widget".
private struct WidgetEntryContainer: View {
  var entry: ExpenseEntry

  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      ExpenseHomeWidgetEntryView(entry: entry)
        .containerBackground(for: .widget) {
          LinearGradient(
            colors: [WidgetTheme.surface, WidgetTheme.surfaceSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
    } else {
      ExpenseHomeWidgetEntryView(entry: entry)
        .padding(4)
        .background(
          LinearGradient(
            colors: [WidgetTheme.surface, WidgetTheme.surfaceSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
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
