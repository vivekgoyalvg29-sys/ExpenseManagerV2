# Expense Manager

## Home screen widget support

This repository now includes widget data sync and platform templates for Android/iOS widgets.

### Widget content
The widget shows:
- Budget
- Expense
- Remaining
- Mode (`Selected month`, `Cumulative till selected month`, `Cumulative full year`)

### Widget mode source
The selected mode and month/year come from the Analysis screen selection.

### Android security config
Android manifest now disables cleartext traffic and points to a network security config.

### iOS notes
The project includes an app group entitlement (`group.com.example.expense_manager`) used for widget data sharing.
