# moni — Offline Expense Tracker for iOS

> Privacy-first personal finance, built natively for iOS 18. No backend, no bank linking, no network calls. All data stays on device.

`moni` is a SwiftUI + SwiftData expense tracker designed for fast manual entry. Its core interaction is a **drag-scrub + radial category picker** that lets you log an expense in ~2 seconds, plus **Siri / Shortcuts / SMS automations** for hands-free entry.

**Repo:** `vatsa31/moni` · **Platform:** iOS 18.5+ · **Xcode:** 16.4 · **Language:** Swift 5.0

---

### Demo / Screenshots

> Add screenshots or a 10s screen recording here for portfolio reviewers.

| Dashboard (Budget Hero) | Quick Expense (Scrubber → Radial) | Shortcuts Snippet | Theme Builder |
|---|---|---|---|
| Budget progress + state colors, today's transactions | Upward drag → scrub amount ladder → drop on category | Siri / Back Tap category picker | Custom hex palette |
| `BudgetHeroCard` | `BottomActionBar` + `QuickCategoryPickerOverlay` | `BackTapExpenseIntent` | `ThemeBuilderView` |

---

### Features

- **Accounts** — Cash / Bank / Credit Card with opening balances. Credit cards support negative opening balance (debt). Archiving.
- **Transactions** — Expense / Income / Transfer with payee, note, date, category. Edit + swipe delete.
- **Budgets** — Monthly total + per-category budgets with traffic-light state (`green <75%`, `yellow 75-99%`, `red ≥100%`). Progress bar & `Budget signals` panel.
- **Categories** — 8 defaults (`Food, Groceries, Transport, Shopping, Bills, Health, Entertainment, Travel`) + user-managed. Created on-the-fly for Shortcuts/SMS.
- **Quick Expense** — Center `+` button: upward drag scrubs a non-linear amount ladder (`[10,20,50,100,200,500,1000,...5000]` with `pow(p,1.35)` easing), blur/dim + haptics (`0.08s` throttle), on release radial picker with `AnnularSector` shape + distance-based highlight (`hypot <=96pt`).
- **Voice & Shortcuts** — Siri phrases `"Add debit in moni"` / `"Add credit in moni"` via `AppShortcutsProvider`. Back Tap → "Quick Expense" snippet with category grid (no app open). All `AppIntents` with `openAppWhenRun=false`.
- **SMS Import** — Regex parser for Indian bank SMS (`₹/Rs/INR` amounts, `debited/credited` detection, payee extraction, category inference). Triggered via iOS Shortcuts **Message Automation** (`ImportTransactionFromSMSIntent` + optional review snippet `SaveImportedSMSTransactionIntent`).
- **Theming** — Custom `AppColorTheme` token system (`canvas,surface,mist,ink,leaf,lime,sky,amber,coral`) with light/dark presets, hex `Color` init + `UIColor.hexString`, JSON persistence in `UserDefaults`, `ThemeBuilderView` with live preview.
- **Dashboard** — `BudgetHeroCard` with state-aware gradient + shadow, `SectionPanel` cards, `Today's transactions` filter (`Calendar.isDateInToday`), staggered entrance animations `Motion.entrance 0.42s`.

---

### Tech Stack

| Layer | Tech | Notes |
|---|---|---|
| UI | **SwiftUI** | 100% declarative, `matchedGeometryEffect` tabs, `contentTransition(.numericText())` |
| Persistence | **SwiftData** | 4 `@Model` types, `ModelContainer`, `@Query`, `#Predicate` |
| Money | **Int paise + Decimal** | Avoids `Double` errors. `MoneyFormatting.paise(from:)` uses `Decimal *100` |
| System Integration | **AppIntents** | 6 intents + `AppShortcutsProvider`, `ShowsSnippetView` / `ProvidesDialog` |
| Parsing | **NSRegularExpression** | 4 amount patterns, keyword dictionaries for type/payee/category |
| Motion | **SwiftUI Animation** | Central `Motion` enum (`micro 0.16s`, `snappy 0.28s`, `bouncy 0.34s`, `entrance 0.42s`) + `MicroPressButtonStyle` |
| Haptics | **UIKit** | `UISelectionFeedbackGenerator`, `UIImpactFeedbackGenerator` with intensity |
| Testing | **Swift Testing** | `FinanceCalculatorTests` - 5 tests for balances/budgets |

No third-party dependencies.

---

### Architecture

```
moni/
├── App/              ContentView (coordinator), moniApp (entry), BottomActionBar, AppState (Tab/Theme/Sheet)
├── Models/           FinanceModels.swift — Account, SpendingCategory, MoneyTransaction, MonthlyBudget
├── Domain/           Pure logic — FinanceCalculator, FinanceCommands, MoneyFormatting, TransactionSMSParser
├── Persistence/      FinanceStore — Schema, ModelContainer, UserDefaults bridge, Shortcut/SMS write paths
├── DesignSystem/     Theme.swift (AppColorTheme + Color+hex), PaynoDesignSystem.swift (panels, cards, buttons, Motion)
├── Features/
│   ├── Dashboard/    DashboardView, FinanceRows
│   ├── QuickExpense/ QuickExpenseCoordinator, QuickCategoryPickerOverlay (AnnularSector)
│   ├── Transactions/ TransactionFormView
│   ├── Accounts/     AccountFormView, FirstAccountSetupView
│   ├── Budgets/      BudgetFormView
│   ├── Categories/   CategoryManagerView
│   ├── History/      HistoryView
│   └── Theme/        ThemeBuilderView
└── Shortcuts/        BackTapExpenseIntent, VoiceTransactionIntent, SMSImportIntent
```

**Pattern:** Feature-sliced + Domain/Persistence separation. `ContentView` holds live `@Query` arrays and exposes computed `activeAccounts`, `totalBudget(for:)`, `quickExpenseCategories`. `Domain` is stateless `enum` with `static func`. `FinanceCommands` is the command layer for mutations (`upsertBudget` with identity `===` check). `FinanceStore` is the boundary for `AppIntents` (`@MainActor` fetches `FetchDescriptor` + `context.save()`).

---

### Domain Details

**Balance calculation** — `FinanceCalculator.swift:60`
```swift
expense:  source === account ? -amount : 0
income:   source === account ? +amount : 0
transfer: source === account ? -amount : dest === account ? +amount : 0
```
Monthly expenses filtered by `calendar.isDate(_:inSameMonthAs:)`.

**SMS Parser** — `TransactionSMSParser.swift:52`
- Amount: `/(?:inr|rs\.?|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)/i` (4 patterns, comma stripping, `Double` -> paise)
- Type: `debitWords=[debited, spent, paid, charged...]` vs `creditWords=[credited, received, refund...]`
- Payee: `/(?:paid to|to|at)\s+([a-z0-9 &._-]{2,48})/i` with stop-word trim (` refno`, ` txn`, ` on date`...)
- Category: rule engine `swiggy|zomato->Food`, `uber|ola->Transport`, `amazon|flipkart->Shopping` etc.

**Money** — `MoneyFormatting.swift:14` `Decimal(string: cleaned) * 100 -> intValue`, `display` uses `.currency(code:"INR").precision(0...2)`.

---

### Getting Started

**Requirements**
- Xcode 16.4+, iOS 18.5 SDK, iPhone/iPad simulator or device, Apple Developer Team (for signing - `vatsasorg.moni`).

**Run**
```bash
git clone https://github.com/vatsa31/moni.git
open moni.xcodeproj
# Select scheme "moni" > Run (⌘R)
```

**Tests**
```bash
# In Xcode: Product > Test (⌘U)
# or
xcodebuild test -project moni.xcodeproj -scheme moni -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Build config**
- `IPHONEOS_DEPLOYMENT_TARGET = 18.5` (`project.pbxproj:325`), `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`.

---

### Shortcuts Automation Setup (optional but key for demo)

1.  **Back Tap:** Settings > Accessibility > Touch > Back Tap > Assign Shortcut > `Quick Expense` (AddBackTapExpenseIntent). Double-tap back of phone, enter amount, pick category in snippet.
2.  **Siri:** `“Add debit in moni 250”` / `“Add credit in moni 1000”` (no confirmation, `openAppWhenRun=false`).
3.  **SMS Import:** Shortcuts app > Automation > Message > When message from `[BANK]` contains `debited` > Run `Import Transaction from SMS` with `Message Text = Shortcut Input`, toggle `Review Expense Category`. Handles HDFC, ICICI, SBI, Axis formats etc. via regex.

> iOS does not allow direct SMS reading — the Shortcuts automation is the App Store-safe workaround.

---

### Project Structure (file count)

~26 Swift files. Key paths:
- `moni/Models/FinanceModels.swift` — schema
- `moni/Domain/*` — calculator, commands, formatting, parser
- `moni/Persistence/FinanceStore.swift` — persistence + Shortcuts bridge
- `moni/DesignSystem/*` — theming + design tokens
- `moni/Features/**/*` — 7 feature modules
- `moni/Shortcuts/*` — 3 intent families

---

### What Makes It Portfolio-Worthy

- **Modern native iOS** — SwiftData over CoreData, AppIntents over SiriKit, Swift Testing, iOS 18 target.
- **Interaction engineering** — Non-linear scrubber + radial picker + haptic throttling + spring choreography vs. basic form.
- **Precision finance** — `Int` paise storage, `Decimal` conversion, correct transfer/credit-card debt accounting, test-covered.
- **System integration without backend** — Voice, Back Tap, SMS automation all work offline, privacy-first (no network, no bank API, no permissions prompt).
- **Design system** — Token-driven theming with JSON persistence, `Color(hex:)` 3/6/8-digit support, motion system.

---

### Roadmap / Ideas

- [ ] Swift Charts for spend trends
- [ ] CSV export / import
- [ ] CloudKit sync (`ModelConfiguration(cloudKitDatabase: .automatic)`)
- [ ] Widget + Live Activity for budget
- [ ] Recurring transactions
- [ ] Biometrics lock + App Group for extensions

---

### License

MIT — do what you want, attribution appreciated.

---

**For portfolio side-projects list:**

> **moni — Offline Expense Tracker (iOS 18, SwiftUI + SwiftData)** — Fast, private finance with gesture-driven expense entry (drag-scrub + radial picker), monthly/category budgets, and Siri/Shortcuts/SMS automations. No backend, all data on device, amounts stored as paise. Features regex bank-SMS parser and custom hex-theming engine.
