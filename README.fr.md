# Splynek

> **Version française condensée.** Pour la documentation complète, consultez [README.md](README.md) (en anglais).

Splynek est un gestionnaire de téléchargements pour macOS qui regroupe toutes les connexions réseau de votre Mac — Wi-Fi, Ethernet, partage de connexion iPhone — pour télécharger des fichiers plus rapidement que ce que permet une seule connexion.

## Ce qui distingue Splynek

- **Plus rapide** — cumule le débit de tous les réseaux connectés simultanément. En tests, 1,8× à 3,5× plus rapide que Safari sur une seule connexion.
- **Honnête** — chaque téléchargement est vérifié par rapport à la somme de contrôle de l'éditeur. Rien n'est conservé sur disque avant que l'intégrité ne soit confirmée.
- **Privé** — rien ne quitte votre Mac. Aucun compte. Aucune télémétrie. Aucun journal.
- **Souverain** — découvrez d'où viennent les apps de votre Mac, et lesquelles ont des alternatives européennes ou open source.

## Les onglets principaux

| Onglet | Fonction |
|--------|----------|
| **Téléchargements** | URL, somme de contrôle optionnelle, choisissez les réseaux, téléchargez. |
| **Torrents** | Support natif de BitTorrent v1+v2 (DHT, PEX, magnet, multifichier). |
| **En Direct** | Visualisez en temps réel le débit par réseau pendant un téléchargement. |
| **Souveraineté** | Analysez les apps installées et proposez des alternatives européennes / open source. Local ; rien ne quitte l'appareil. |
| **Confiance** | Audit des registres publics de vos apps — étiquettes de confidentialité App Store, amendes réglementaires, CVE, fuites HIBP. Sans éditorialisation. Chaque affirmation cite sa source. |
| **Agents** | Serveur MCP — permet à Claude, ChatGPT ou d'autres agents IA de piloter Splynek. Désactivé par défaut. |
| **File** | File d'attente persistante d'URL à télécharger plus tard. |
| **Flotte** | Coordination entre plusieurs Mac sur le même réseau local. |
| **Historique** | Tous vos téléchargements passés. Recherchable, indexé dans Spotlight. |

## Comment installer

**Mac App Store** (en cours de validation pour la v1.0) : https://apps.apple.com/app/splynek

**DMG direct** (gratuit, signé Developer ID, notarié) :
- [GitHub Releases](https://github.com/Splynek/splynek/releases) — téléchargez le `.dmg` le plus récent

**Homebrew** :
```bash
brew tap Splynek/splynek
brew install --cask splynek
```

## Confidentialité — le contrat

- Splynek **n'envoie jamais** de données à nos serveurs. Nous n'avons pas de serveurs.
- Splynek **n'ouvre jamais** le contenu de vos apps. Les analyses Souveraineté et Confiance ne lisent que la liste des bundles installés — la même chose que Spotlight.
- Splynek **ne télécharge jamais** votre historique ou liste d'apps vers le cloud.
- Le serveur web local (utilisé pour afficher la progression ou s'intégrer aux extensions du navigateur) n'écoute que sur `127.0.0.1` par défaut.

## Langues prises en charge

Splynek est disponible en **anglais**, **portugais (Portugal)**, **espagnol**, **français**, **allemand** et **italien**. Voir [LOCALIZATION.md](LOCALIZATION.md) pour le flux de contribution (PRs avec traductions bienvenues).

## Contribuer

- Le catalogue Souveraineté (1 100+ apps, alternatives européennes / OSS) est maintenu dans [`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json) — voir [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).
- Le catalogue Confiance (60 apps, avec sources primaires) est dans [`Scripts/trust-catalog.json`](Scripts/trust-catalog.json).
- Bugs, suggestions : [github.com/Splynek/splynek/issues](https://github.com/Splynek/splynek/issues).

## Licence

[BSD 3-Clause](LICENSE).
