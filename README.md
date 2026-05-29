# StopPhone 🛡️

[🇫🇷 Français](#français) · [🇬🇧 English](#english)

---

## Français

**StopPhone** est une application iOS gratuite et open-source qui bloque automatiquement les apps distrayantes pendant que vous conduisez — grâce à la détection de vitesse GPS et à la connexion Bluetooth de votre voiture.

---

### Fonctionnalités

| Fonctionnalité | Description |
|---|---|
| 🚗 **Détection GPS** | S'active automatiquement au-dessus d'un seuil de vitesse configurable (15 km/h par défaut) |
| 🔵 **Déclencheur Bluetooth** | Démarre le blocage dès que le kit mains-libres de votre voiture se connecte |
| 📵 **Blocage Screen Time** | Bloque les apps ou catégories via l'API Family Controls d'Apple |
| 🔴 **Écran d'alerte** | Couvre l'écran d'un avertissement rouge prominent pendant la conduite |
| 🔔 **Notification locale** | Envoie une notification quand une conduite est détectée |
| 🔊 **Alerte vocale** | Annonce l'alerte sur les enceintes de la voiture via Bluetooth audio |
| ⚡ **Raccourcis Siri** | Schéma URL `stopphone://activate` / `stopphone://deactivate` pour les automations Raccourcis |
| 🌍 **Français & Anglais** | Interface entièrement localisée en français et anglais |

---

### Comment ça marche

```
Vitesse GPS > seuil
       OU
Bluetooth voiture connecté
       │
       ▼
┌──────────────────────────────┐
│  BlockingManager             │
│  • Blocage Screen Time       │
│  • Écran d'alerte plein écran│
│  • Notification locale       │
│  • Alerte vocale (BT)        │
└──────────────────────────────┘
```

1. **SpeedMonitor** suit la vitesse GPS en arrière-plan via `CoreLocation` avec `activityType = .automotiveNavigation` et une hystérésis de 5 km/h pour éviter les faux déclenchements.
2. **BluetoothMonitor** écoute les notifications de changement de route `AVAudioSession` pour détecter les connexions HFP / A2DP — aucun appairage CoreBluetooth requis.
3. **BlockingManager** utilise `FamilyControls` + `ManagedSettings` pour appliquer un écran Screen Time, affiche une superposition SwiftUI plein écran, déclenche une notification locale et parle via `AVSpeechSynthesizer`.
4. Quand la vitesse repasse sous `seuil - 5 km/h` (hystérésis) ou que le Bluetooth se déconnecte, la protection est automatiquement levée.

---

### Prérequis

- iOS 17+
- Xcode 15+
- **Entitlement Family Controls** (via Apple) pour le blocage Screen Time  
  > Sans cet entitlement, l'app fonctionne quand même — l'écran d'alerte et les notifications restent actifs.

---

### Installation

```bash
git clone https://github.com/boboul-cloud/StopPhone.git
cd StopPhone
open StopPhone.xcodeproj
```

Sélectionnez votre équipe de développement dans **Signing & Capabilities**, choisissez un vrai appareil (le simulateur ne supporte pas le GPS ni Screen Time) et appuyez sur **⌘R**.

---

### Architecture

```
StopPhone/
├── StopPhoneApp.swift       # Point d'entrée, gestion du schéma URL
├── ContentView.swift        # Dashboard + DrivingOverlay
├── SettingsView.swift       # Réglages : seuil, Bluetooth, sélecteur d'apps, à propos
├── SpeedMonitor.swift       # CLLocationManager, suivi vitesse, hystérésis
├── BluetoothMonitor.swift   # AVAudioSession route change → détection BT voiture
├── BlockingManager.swift    # FamilyControls, ManagedSettings, notifications, TTS
├── Info.plist               # Modes arrière-plan, schéma URL, descriptions permissions
├── StopPhone.entitlements   # com.apple.developer.family-controls
├── en.lproj/Localizable.strings
└── fr.lproj/Localizable.strings
```

---

### Schéma URL

| URL | Action |
|---|---|
| `stopphone://activate` | Active la protection + applique le blocage immédiatement |
| `stopphone://deactivate` | Supprime le blocage + désactive la protection |

---

### Permissions

| Permission | Raison |
|---|---|
| **Localisation (Toujours)** | Surveillance de la vitesse en arrière-plan |
| **Family Controls** | API Screen Time pour bloquer les apps |
| **Notifications** | Alerter quand une conduite est détectée |

---

### Confidentialité

- **Aucune collecte de données** — tout le traitement est 100 % sur l'appareil
- **Aucun compte requis**
- **Aucune requête réseau**

---

### Licence

Licence MIT — voir le fichier [LICENSE](LICENSE).

---

## English

**StopPhone** is a free, open-source iOS app that automatically blocks distracting apps while you're driving — using GPS speed detection and your car's Bluetooth connection.

---

## Features

| Feature | Description |
|---|---|
| 🚗 **GPS Speed Detection** | Activates protection automatically above a configurable speed threshold (default 15 km/h) |
| 🔵 **Car Bluetooth Trigger** | Starts blocking the moment your car's hands-free Bluetooth connects |
| 📵 **Screen Time Blocking** | Blocks selected apps or entire app categories via Apple's Family Controls API |
| 🔴 **Full-screen Overlay** | Covers the screen with a prominent red alert while driving |
| 🔔 **Local Notification** | Sends a notification when driving is detected |
| 🔊 **Voice Alert** | Announces the alert through your car speakers (Bluetooth audio) |
| ⚡ **Shortcuts Automation** | URL scheme `stopphone://activate` / `stopphone://deactivate` for Siri Shortcuts |
| 🌍 **French & English** | Full localisation in French and English |

---

## How It Works

```
GPS speed > threshold
       OR
Car Bluetooth connects
       │
       ▼
┌─────────────────────────┐
│  BlockingManager        │
│  • Screen Time blocking │
│  • Full-screen overlay  │
│  • Local notification   │
│  • Voice alert (BT)     │
└─────────────────────────┘
```

1. **SpeedMonitor** tracks GPS speed in the background using `CoreLocation` with `activityType = .automotiveNavigation` and a hysteresis gap (5 km/h) to prevent flickering.
2. **BluetoothMonitor** listens for `AVAudioSession` route change notifications to detect HFP / A2DP car connections — no CoreBluetooth pairing needed.
3. **BlockingManager** uses `FamilyControls` + `ManagedSettings` to apply a Screen Time shield on selected apps/categories, displays a full-screen SwiftUI overlay, fires a local notification with "Open / Ignore" action buttons, and speaks an alert via `AVSpeechSynthesizer`.
4. When speed drops below `threshold - 5 km/h` (hysteresis), or Bluetooth disconnects, protection is automatically lifted.

---

## Requirements

- iOS 17+
- Xcode 15+
- **Family Controls entitlement** (from Apple) for Screen Time blocking  
  > Without it, the app still works — the full-screen overlay and notifications remain active.

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/boboul-cloud/StopPhone.git
cd StopPhone
```

### 2. Open in Xcode

```bash
open StopPhone.xcodeproj
```

### 3. Configure signing

- Select your development team in **Signing & Capabilities**
- The `com.apple.developer.family-controls` entitlement requires a provisioning profile that includes it (request at [developer.apple.com](https://developer.apple.com))

### 4. Build & Run

Select a device (simulator does not support GPS or Screen Time) and press **⌘R**.

---

## Architecture

```
StopPhone/
├── StopPhoneApp.swift       # App entry point, URL scheme handler
├── ContentView.swift        # Dashboard + DrivingOverlay
├── SettingsView.swift       # Settings: threshold, Bluetooth, app picker, shortcuts
├── SpeedMonitor.swift       # CLLocationManager, speed tracking, hysteresis
├── BluetoothMonitor.swift   # AVAudioSession route change → car BT detection
├── BlockingManager.swift    # FamilyControls, ManagedSettings, notifications, TTS
├── Info.plist               # Background modes, URL scheme, location usage strings
├── StopPhone.entitlements   # com.apple.developer.family-controls
├── en.lproj/Localizable.strings
└── fr.lproj/Localizable.strings
```

---

## URL Scheme

StopPhone registers the `stopphone://` URL scheme to enable Shortcuts automations:

| URL | Action |
|---|---|
| `stopphone://activate` | Enable protection + apply blocking immediately |
| `stopphone://deactivate` | Remove blocking + disable protection |

### Shortcuts Automation (recommended)

1. Open the **Shortcuts** app
2. **Automation → + → Personal Automation**
3. Choose **Bluetooth** → select your car → **Connects**
4. Add action **Open URLs** → enter `stopphone://activate`
5. (Optional) Create a second automation for **Disconnects** → `stopphone://deactivate`

---

## Permissions

| Permission | Reason |
|---|---|
| **Location (Always)** | Background speed monitoring while the app is not in the foreground |
| **Family Controls** | Screen Time API to block apps |
| **Notifications** | Alert the user when driving is detected |

---

## Localisation

The app is fully localised in **English** and **French**.  
Localisation files are in `StopPhone/en.lproj/` and `StopPhone/fr.lproj/`.

---

## Privacy

- **No data collection** — all processing is 100% on-device
- **No account required**
- **No network requests**
- GPS data is used in real-time and never stored

---

## License

MIT License — see [LICENSE](LICENSE) file.

---

## Contributing

Pull requests are welcome. For major changes, open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## Screenshots

> _Coming soon_

---

Made with ❤️ to keep roads safer.
