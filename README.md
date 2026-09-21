<div align="center">

<img src="assets/icon/icon.png" alt="Opime" width="96" />

# Opime

**Take back control of your net worth.**

Every account, every investment, every financial project — in one place, 100% free, and without ever sending your data anywhere but your own device.

[![Try it now](https://img.shields.io/badge/try_it_now-opime.vercel.app-6E56CF?logo=googlechrome&logoColor=white&style=for-the-badge)](https://opime.vercel.app)

[![Latest release](https://img.shields.io/github/v/release/Cl3mty/opime-releases?label=latest%20release)](https://github.com/Cl3mty/opime-releases/releases/latest)
[![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-informational)](#get-opime)
[![Status](https://img.shields.io/badge/status-actively--developed-brightgreen)](#roadmap)
[![License](https://img.shields.io/badge/license-all--rights--reserved-lightgrey)](#license)

<br>

<img src="assets/landing/screenshot_dashboard_light.png#gh-light-mode-only" alt="Opime dashboard" width="800">
<img src="assets/landing/screenshot_dashboard.png#gh-dark-mode-only" alt="Opime dashboard" width="800">

</div>

<br>

> This repository doesn't hold any source code — Opime's app is closed-source. It exists to publish Releases (so the app can check for updates and you can download installers) and to host the community Discussions/stars a private repo can't.

## Why Opime

- 🆓 **100% free, forever** — every single feature, no paid tier, no trial, no credit card.
- 🔒 **Local-first, always** — your data lives as plain JSON/Markdown files in a folder *you* pick (iCloud Drive, Dropbox, or just your disk). Opime never phones home.
- 👨‍👩‍👧‍👦 **Built for a whole household** — a separate, fully isolated account for your spouse, your kids, or anyone else you help manage money for.
- 💻 **Everywhere** — macOS, Windows, Linux, iOS, Android, and the web.
- 🎨 **Actually pleasant to use** — a modern, polished interface instead of a spreadsheet with a UI bolted on.

## What's included

Nothing is locked. This is the entire app:

| | |
|---|---|
| 📊 **Net worth dashboard** | Unlimited accounts, every asset & liability class |
| 💰 **Budget** | Income/expense tracking, visualized as a Sankey flow |
| 📝 **Strategy notes** | Rich-text notes for your investment thesis and plans |
| 📈 **Simulations** | Wealth projections, loan amortization, tax estimation |
| 🔍 **Analyses** | Advanced allocation & performance charts |
| 🎯 **Projets** | Track progress toward your financial goals |
| 🏢 **Sociétés** | Holdings, commercial companies, real-estate SCIs |
| 🤖 **AI Assistant** | Chat about your own data — your API key, or fully local with Ollama |
| 🎓 **Académie** | Guided courses: fundamentals, stocks, crypto, real estate, structuring |
| 🔗 **Patrimoine sharing** | Hand an advisor a partial, password-protected, time-limited view |

<div align="center">
<table>
<tr>
<td width="50%">
<img src="assets/landing/screenshot_budget_light.png#gh-light-mode-only" alt="Budget">
<img src="assets/landing/screenshot_budget.png#gh-dark-mode-only" alt="Budget">
</td>
<td width="50%">
<img src="assets/landing/screenshot_simulation_light.png#gh-light-mode-only" alt="Simulations">
<img src="assets/landing/screenshot_simulation.png#gh-dark-mode-only" alt="Simulations">
</td>
</tr>
<tr>
<td width="50%">
<img src="assets/landing/screenshot_projects_light.png#gh-light-mode-only" alt="Projets">
<img src="assets/landing/screenshot_projects.png#gh-dark-mode-only" alt="Projets">
</td>
<td width="50%" align="center" valign="middle">
<a href="https://opime.vercel.app"><strong>→ See it running live at opime.vercel.app</strong></a>
</td>
</tr>
</table>
</div>

## Get Opime

- 🌐 **[opime.vercel.app](https://opime.vercel.app)** — the fastest way in: runs entirely in your browser, backed by a real folder on your disk, not browser-only storage.
- 💻 **[Latest release](https://github.com/Cl3mty/opime-releases/releases/latest)** — desktop installers for macOS, Windows, and Linux. The app checks this page itself and prompts you when a newer version is out.

On first launch, you'll be asked to choose (or create) the folder where your data will live.

## Data & privacy

- Everything lives locally in the `Opime` folder you choose — nothing is ever sent to a server, on desktop or on the web version.
- **At-rest encryption is available, opt-in, from Settings** — a password plus a one-time recovery key. Toggling it is crash-safe: an interrupted attempt is detected and resumed on next launch.
- Deleting a profile removes it from the list but keeps its data folder on disk, so you can recover it manually if needed.

## Tech stack

Built with **[Flutter](https://flutter.dev)** — one codebase for desktop, mobile, and web. Plain **JSON/Markdown files** for storage — no database, no backend.

## Roadmap

- [ ] Consolidated net worth dashboard across profiles (currently shown per profile only)
- [ ] Mobile builds (iOS / Android) — scaffolding exists, but the app is still built and tested desktop-first
- [ ] Native in-app installer flow for updates (instead of opening the browser)

Got an idea? [Vote on existing proposals or post your own](https://github.com/Cl3mty/opime-releases/discussions/categories/ideas).

## Support the project

Opime has no ads and costs nothing to use. If it's useful to you, here's how to help it keep going:

- ⭐ **[Star this repo](https://github.com/Cl3mty/opime-releases)** — the easiest way to help it reach more people.
- 💡 **[Vote on ideas](https://github.com/Cl3mty/opime-releases/discussions/categories/ideas)** — it directly shapes what gets built next.
- ☕ **Buy me a coffee** — if you'd like to support the time spent building and maintaining it:

  [![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/clemty)

## License

Opime is free to use but closed-source — all rights reserved. This repository ships no code, so there's nothing here to license; it only distributes official builds and hosts the community space around them.
