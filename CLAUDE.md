# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

This repository (`opime`, public) holds no source code. Opime's real source lives in a private repository (`opime-code`, `github.com/Cl3mty/opime-code`) — see that repo's own CLAUDE.md for the actual app architecture.

This repo exists purely because `opime-code` is private, and two things need a public GitHub presence to work:

1. **Update checks** — `UpdateChecker` (`lib/core/updates/update_checker.dart` in the private `opime-code` repo) polls the GitHub Tags/Releases REST API unauthenticated, from every user's install. That API 404s on a private repo, so it's pointed at this repo instead (`_githubOwner`/`_githubRepo` in `opime-code`'s `main.dart`).
2. **Community links** — GitHub stars and the "vote on ideas" Discussions category (`.github/DISCUSSION_TEMPLATE/ideas.yml`) aren't visible to outsiders on a private repo either, so `opime-code`'s landing page (`landing_screen.dart`'s `_githubRepoUrl`/`_githubIdeasUrl`) and its own README point here too.

## Release process

Whenever a new version ships: build it from the private `opime-code` repo, then publish/tag the resulting installers as a Release **on this repo** (manual/CI step, not automated by anything in either repo yet). The web app deploys separately, straight from `opime-code` to Vercel (Vercel supports deploying from a private repo directly — no involvement from this repo).

## License note

This repo's own README deliberately says nothing about licensing (no badge, no section) — that's a content decision made after this file was last updated, not an oversight. Don't reintroduce a License section or a closed-source/all-rights-reserved badge without checking with the user first; the private `opime-code` repo's own `LICENSE`/`CLAUDE.md` remain the actual source of truth on the app's licensing terms if that's ever needed.

## Known repo quirks

- Don't add real source code here — if a feature needs code, it belongs in the private `opime-code` repo. This repo should stay just `README.md`, `CLAUDE.md`, `.github/` (Discussion template, funding link), the handful of images under `assets/` the README embeds (copied from `opime-code`'s own `assets/icon/`/`assets/landing/` — keep them in sync manually if those screenshots change), and published Releases.
