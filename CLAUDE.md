# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

This repository (`opime-releases`, public) holds no source code. Opime's real source lives in a private repository (`opime`, `github.com/Cl3mty/opime`) — see that repo's own CLAUDE.md for the actual app architecture.

This repo exists purely because `opime` is private, and two things need a public GitHub presence to work:

1. **Update checks** — `UpdateChecker` (`lib/core/updates/update_checker.dart` in the private `opime` repo) polls the GitHub Tags/Releases REST API unauthenticated, from every user's install. That API 404s on a private repo, so it's pointed at this repo instead (`_githubOwner`/`_githubRepo` in `opime`'s `main.dart`).
2. **Community links** — GitHub stars and the "vote on ideas" Discussions category (`.github/DISCUSSION_TEMPLATE/ideas.yml`) aren't visible to outsiders on a private repo either, so `opime`'s landing page (`landing_screen.dart`'s `_githubRepoUrl`/`_githubIdeasUrl`) and its README point here too.

## Release process

Whenever a new version ships: build it from the private `opime` repo, then publish/tag the resulting installers as a Release **on this repo** (manual/CI step, not automated by anything in either repo yet). The web app deploys separately, straight from `opime` to Vercel (Vercel supports deploying from a private repo directly — no involvement from this repo).

## Known repo quirks

- Don't add real source code here — if a feature needs code, it belongs in the private `opime` repo. This repo should stay just `README.md`, `CLAUDE.md`, `.github/` (Discussion template, funding link), the handful of images under `assets/` the README embeds (copied from `opime`'s own `assets/icon/`/`assets/landing/` — keep them in sync manually if those screenshots change), and published Releases.
