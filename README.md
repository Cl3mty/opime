<div align="center">

<img src="assets/icon/icon.png" alt="Opime" width="96" />

# Opime

**Reprends le contrôle de ton patrimoine.**

Chaque compte, chaque investissement, chaque projet financier — au même endroit, 100 % gratuit, sans jamais envoyer tes données ailleurs que sur ton propre appareil.

[![Essayer maintenant](https://img.shields.io/badge/essayer_maintenant-opime.vercel.app-6E56CF?logo=googlechrome&logoColor=white&style=for-the-badge)](https://opime.vercel.app)

[![Dernière version](https://img.shields.io/github/v/release/Cl3mty/opime?label=derni%C3%A8re%20version)](https://github.com/Cl3mty/opime/releases/latest)
[![Plateformes](https://img.shields.io/badge/plateformes-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-informational)](#télécharger-opime)
[![Statut](https://img.shields.io/badge/statut-en--développement--actif-brightgreen)](#feuille-de-route)

<br>

<img src="assets/landing/screenshot_dashboard_light.png#gh-light-mode-only" alt="Tableau de bord Opime" width="800">
<img src="assets/landing/screenshot_dashboard.png#gh-dark-mode-only" alt="Tableau de bord Opime" width="800">

</div>

<br>

> Ce dépôt ne contient aucun code source. Il sert uniquement à publier les nouvelles versions (pour que l'app puisse se mettre à jour et que tu puisses télécharger les installeurs) et à accueillir les Discussions/étoiles de la communauté.

## Pourquoi Opime

- 🆓 **100 % gratuit, pour toujours** — absolument toutes les fonctionnalités, sans palier payant, sans essai, sans carte bancaire.
- 🔒 **Local-first, toujours** — tes données vivent sous forme de fichiers JSON/Markdown, dans un dossier *que tu choisis* (iCloud Drive, Dropbox, ou simplement ton disque). Opime ne contacte jamais de serveur.
- 👨‍👩‍👧‍👦 **Pensé pour tout un foyer** — un compte séparé et totalement isolé pour ton/ta conjoint(e), tes enfants, ou toute autre personne dont tu gères les finances.
- 💻 **Partout** — macOS, Windows, Linux, iOS, Android, et le web.
- 🎨 **Vraiment agréable à utiliser** — une interface moderne et soignée plutôt qu'un tableur avec une UI plaquée dessus.

## Fonctionnalités incluses

Rien n'est verrouillé. Voici l'application dans son intégralité :

| | |
|---|---|
| 📊 **Tableau de bord patrimoine** | Comptes illimités, toutes les classes d'actifs et de passifs |
| 💰 **Budget** | Suivi des revenus/dépenses, visualisé sous forme de flux Sankey |
| 📝 **Notes de stratégie** | Notes en texte enrichi pour ta thèse d'investissement et tes plans |
| 📈 **Simulations** | Projections patrimoniales, amortissement de prêt, estimation fiscale |
| 🔍 **Analyses** | Graphiques avancés d'allocation et de performance |
| 🎯 **Projets** | Suis la progression de tes objectifs financiers |
| 🏢 **Sociétés** | Holdings, sociétés commerciales, SCI immobilières |
| 🤖 **Assistant IA** | Discute avec tes propres données — ta propre clé API, ou entièrement en local avec Ollama |
| 🎓 **Académie** | Parcours guidés : fondamentaux, bourse, crypto, immobilier, structuration |
| 🔗 **Partage de patrimoine** | Donne à un conseiller une vue partielle, protégée par mot de passe et limitée dans le temps |

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
<a href="https://opime.vercel.app"><strong>→ À voir en direct sur opime.vercel.app</strong></a>
</td>
</tr>
</table>
</div>

## Télécharger Opime

- 🌐 **[opime.vercel.app](https://opime.vercel.app)** — le plus rapide : tourne entièrement dans ton navigateur, avec un vrai dossier sur ton disque, pas juste du stockage navigateur.
- 💻 **[Dernière version](https://github.com/Cl3mty/opime/releases/latest)** — installeurs desktop pour macOS, Windows et Linux. L'app consulte elle-même cette page et te prévient quand une nouvelle version sort.

Au premier lancement, il te sera demandé de choisir (ou créer) le dossier où vivront tes données.

## Données & confidentialité

- Tout est stocké localement dans le dossier `Opime` que tu choisis — rien n'est jamais envoyé à un serveur, sur desktop comme sur la version web.
- **Le chiffrement au repos est disponible, en option, depuis les Réglages** — un mot de passe plus une clé de récupération à usage unique. L'activer/désactiver est sûr en cas de coupure : une tentative interrompue est détectée et reprise au lancement suivant.
- Supprimer un profil le retire de la liste mais garde son dossier de données sur le disque, pour pouvoir le récupérer manuellement si besoin.

## Stack technique

Développé avec **[Flutter](https://flutter.dev)** — une seule base de code pour desktop, mobile et web. De simples fichiers **JSON/Markdown** pour le stockage — pas de base de données, pas de backend.

## Feuille de route

- [ ] Tableau de bord consolidé multi-profils (aujourd'hui affiché par profil uniquement)
- [ ] Builds mobiles (iOS / Android) — la structure existe, mais l'app est encore développée et testée desktop en priorité
- [ ] Flux d'installation native pour les mises à jour (plutôt que d'ouvrir le navigateur)

Une idée ? [Vote pour une proposition existante ou propose la tienne](https://github.com/Cl3mty/opime/discussions/categories/ideas).

## Soutenir le projet

Opime n'a aucune publicité et ne coûte rien à utiliser. Si l'app t'est utile, voici comment l'aider à continuer :

- ⭐ **[Mettre une étoile sur ce dépôt](https://github.com/Cl3mty/opime)** — le moyen le plus simple de l'aider à toucher plus de monde.
- 💡 **[Voter pour des idées](https://github.com/Cl3mty/opime/discussions/categories/ideas)** — ça façonne directement ce qui sera développé ensuite.
- ☕ **Buy me a coffee** — si tu veux soutenir le temps passé à développer et maintenir l'app :

  [![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/clemty)
