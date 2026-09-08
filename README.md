# Opime Free

The free, open-source edition of **Opime** — a portfolio and investment management app that is:

- 🆓 **Free** — no subscription, no paywall, no account required
- 🔓 **Open-source** — AGPL-3.0, inspect it, fork it, improve it
- 💻 **Multi-platform** — built with Flutter for macOS, Windows, Linux, iOS and Android
- 🔐 **Yours** — your data lives in a folder *you* choose.

Opime helps you track your net worth, plan your budget, and simulate long-term financial decisions — without handing your financial data to a third party.

🔗 **[opime.vercel.app](https://opime.vercel.app)** — try it right in your browser, no install needed.

> **Status:** early-stage / actively developed. Desktop (macOS) is the primary target right now; mobile builds are not yet configured. Expect rough edges.

---

## Free vs. Opime Premium

This edition covers everything under the **Dashboard**, with **no limit** on the number of accounts or on which asset/liability classes you track:

- Net worth dashboard, unlimited accounts, all asset & liability categories
- Budget (allocation + tracking)
- Strategy notes
- All four simulations (wealth projection, real estate, taxation, transmission)
- Académie — Fondamentaux & Enveloppes

A few features are reserved for **[Opime Premium](https://opime.vercel.app)**:

- **Analyses** (advanced allocation/performance charts)
- **Projets** (goal tracking)
- **Entités** (holdings, sociétés commerciales, SCI — professional accounts)
- **Assistant IA** (conversational assistant on your own data)
- **Académie > Formation** (guided courses on stocks, crypto, real estate, wealth structuring)

Those tabs stay visible in the navigation, greyed out — clicking one shows a frozen, non-interactive preview of the real screen (see `lib/core/premium/locked_feature_screen.dart`) so you know exactly what you'd get, with a link to upgrade.

---

## Features

### 🔒 Local-first, always
Every profile's data is stored as plain JSON and Markdown files in an `Opime` folder you pick on first launch. Put it in iCloud Drive, Dropbox, or a local folder — Opime doesn't know or care, and never phones home.

### 👨‍👩‍👧‍👦 Multiple accounts
Create a separate account for your spouse, your kids, a parent, or anyone else you help manage finances for. Each account has its own strategy notes, budget, and assets & liabilities, fully isolated on disk, with no limit on the number of accounts. Switch between accounts in one click from the sidebar.

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
git clone https://github.com/<your-username>/opime-free.git
cd opime-free
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

- All data is stored locally in the `Opime` folder you select — on desktop or in the web version (via a real folder on your disk, not browser-only storage) — nothing is ever sent to a server.
- **At-rest encryption is available, opt-in, from Settings.** Your vault is protected by a password plus a separate one-time recovery key; enabling/disabling it is crash-safe, so an interrupted toggle is detected and can be resumed on next launch rather than left half-encrypted. Until you turn it on, data stays as plain, human-readable JSON/Markdown files — don't put an unencrypted `Opime` folder in a publicly-shared location.
- Deleting a profile in the app removes it from the profile list but does **not** delete its data folder, so you can recover it manually if needed.

---

## Roadmap

- [ ] Dashboard with consolidated net worth across profiles (currently shown per profile, not combined)
- [ ] Mobile builds (iOS / Android) — default Flutter scaffolding exists, but the app is still built and tested desktop-first
- [ ] Native in-app installer flow for updates (instead of opening the browser)

Contributions and ideas welcome — have a look at the [Ideas discussions](https://github.com/Cl3mty/opime-free/discussions/categories/ideas) to vote on existing proposals or post your own.

---

## Support the project

Opime Free has no ads and never will — if it's useful to you, here's how to help it keep going:

- ⭐ **[Star the repo](https://github.com/Cl3mty/opime-free)** — the easiest way to help it reach more people.
- 💡 **[Vote on ideas](https://github.com/Cl3mty/opime-free/discussions/categories/ideas)** or post your own — it directly shapes what gets built next.
- 💎 **[Upgrade to Opime Premium](https://opime.vercel.app)** for Analyses, Projets, Entités, the AI Assistant, and the Académie Formation courses — this is what funds development of the free edition too.
- ☕ If you'd like to support the time spent maintaining it and shipping new features:

  [![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/clemty)

---

## License

Opime Free is licensed under the **[GNU Affero General Public License v3.0](LICENSE)** (AGPL-3.0). In short: you're free to use, study, modify, and redistribute this code — including running a modified version as a network service — as long as you make your source (including your modifications) available under the same license to anyone who interacts with it over a network.

Opime Premium (the paid tier referenced above) is a separate, proprietary codebase and is not covered by this license.
