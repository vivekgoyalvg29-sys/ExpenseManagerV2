import WidgetKit
import SwiftUI

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let title: String
    let modeLabel: String
    let periodLabel: String
    let budget: String
    let expense: String
    let remaining: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseEntry {
        ExpenseEntry(
            date: Date(),
            title: "Budget vs Expense",
            modeLabel: "Selected month",
            periodLabel: "",
            budget: "₹0",
            expense: "₹0",
            remaining: "₹0"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }

    private func loadEntry() -> ExpenseEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.expense_manager")
        let title = userDefaults?.string(forKey: "title") ?? "Budget vs Expense"
        let modeLabel = userDefaults?.string(forKey: "modeLabel") ?? "Selected month"
        let periodLabel = userDefaults?.string(forKey: "periodLabel") ?? ""

        let budget = userDefaults?.double(forKey: "budget") ?? 0
        let expense = userDefaults?.double(forKey: "expense") ?? 0
        let remaining = userDefaults?.double(forKey: "remaining") ?? 0

        return ExpenseEntry(
            date: Date(),
            title: title,
            modeLabel: modeLabel,
            periodLabel: periodLabel,
            budget: "₹\(Int(budget))",
            expense: "₹\(Int(expense))",
            remaining: "₹\(Int(remaining))"
        )
    }
}

struct ExpenseHomeWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
            Text(entry.modeLabel)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(entry.periodLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Budget: \(entry.budget)")
                .foregroundColor(.green)
            Text("Expense: \(entry.expense)")
                .foregroundColor(.red)
            Text("Remaining: \(entry.remaining)")
                .foregroundColor(.blue)
                .fontWeight(.semibold)
        }
        .padding()
    }
}

struct ExpenseHomeWidget: Widget {
    let kind: String = "ExpenseHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ExpenseHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget vs Expense")
        .description("Shows budget, expense, and remaining totals.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct ExpenseHomeWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ExpenseHomeWidget()
    }
}
