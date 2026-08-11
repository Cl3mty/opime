# Opime

A portfolio and investment management app that is:

- 🆓 **Free** — no subscription, no paywall
- 🔓 **Open-source** — inspect it, fork it, improve it
- 💻 **Multi-platform** — built with Flutter for macOS, Windows, Linux, iOS and Android
- 🔐 **Yours** — your data lives in a folder *you* choose.

Opime helps you track your net worth, plan your budget, and simulate long-term financial decisions — without handing your financial data to a third party.

> **Status:** early-stage / actively developed. Desktop (macOS) is the primary target right now; mobile builds are not yet configured. Expect rough edges.

---

## Features

### 🔒 Local-first, always
Every account's data is stored as plain JSON and Markdown files in a `.opime` folder you pick on first launch. Put it in iCloud Drive, Dropbox, or a local folder — Opime doesn't know or care, and never phones home.

### 👨‍👩‍👧‍👦 Multiple accounts
Create a separate account for your spouse, your kids, a parent, or anyone else you help manage finances for. Each account has its own strategy notes, budget, and (soon) assets & liabilities, fully isolated on disk. Switch between accounts in one click from the sidebar.

### 📝 Strategy notes
A rich-text notes editor (headings, bold/italic/underline, text color, checklists, links) for writing down your investment thesis, plans, and reminders — auto-saved as readable Markdown files.

### 💰 Budget
Track income, expenses, and monthly investments by category, visualized as an interactive Sankey flow diagram. Save and name multiple budget versions and revisit or edit them later.

### 📈 Simulations
- **Wealth projection** — compound-interest growth of your portfolio over time, in either a simple deterministic mode or a Monte Carlo mode (configurable expected return and volatility per asset class) showing a confidence band instead of a single guess.
- **Loan simulator** — amortizing or interest-only ("in fine") loans, optional deferred repayment (partial or total), origination and guarantee fees, full month-by-month amortization table.
- **Tax estimator** — French income tax (*impôt sur le revenu*) and real-estate wealth tax (*IFI*) brackets, with the *quotient familial* and exemption thresholds applied. Uses the 2026 scale; always double-check with a certified professional before relying on it.

### 🎨 Customizable
Light, dark, or system theme. Each account can also choose which asset/liability categories appear in their own sidebar.

### 🔄 Update notifications
Opime checks GitHub Releases on launch and shows a one-click download banner when a newer version is available.

---

## Getting started

Opime is built with [Flutter](https://flutter.dev). To run it locally:

```bash
git clone https://github.com/<your-username>/opime.git
cd opime
flutter pub get
flutter run -d macos   # or -d windows / -d linux
```

On first launch, you'll be asked to choose (or create) the folder where your data will live.

### Requirements
- Flutter SDK (stable channel)
- Xcode + CocoaPods (for macOS builds)
- Windows: Visual Studio with the "Desktop development with C++" workload (for Windows builds)

---

## Tech stack

- **[Flutter](https://flutter.dev)** — single codebase for desktop and mobile
- **[shadcn_flutter](https://pub.dev/packages/shadcn_flutter)** — UI components
- **[flutter_quill](https://pub.dev/packages/flutter_quill)** — rich-text editing for Strategy notes
- Plain **JSON / Markdown files** for storage — no database, no backend

---

## Data & privacy

- All data is stored locally in the folder you select. Nothing is sent anywhere.
- **Encryption is not implemented yet.** Data is currently stored as plain, human-readable JSON/Markdown files. Treat your `.opime` folder like any other sensitive personal document (e.g. don't put it in a publicly-shared folder) until at-rest encryption ships.
- Deleting an account in the app removes it from the account list but does **not** delete its data folder, so you can recover it manually if needed.

---

## Roadmap

- [ ] At-rest encryption of the local vault
- [ ] Assets & liabilities tracking (stocks/funds, private equity, real estate, crypto, precious metals, savings, loans, mortgages) — navigation exists, data model doesn't yet
- [ ] Dashboard with consolidated net worth across accounts
- [ ] Mobile builds (iOS / Android)
- [ ] Native in-app installer flow for updates (instead of opening the browser)

Contributions and ideas welcome — open an issue if you'd like to help with any of these.

---

## License

*No license has been chosen yet.* Until a `LICENSE` file is added to this repository, the "open-source" claim is aspirational — all rights are reserved by default under standard copyright. A permissive license (e.g. MIT or Apache-2.0) is planned before the first public release.