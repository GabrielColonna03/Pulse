# Pulse Native iOS

Fully native SwiftUI remake of the Pulse mobile experience. Open this on your Mac in Xcode — it talks to the same Pulse backend as the web app.

## Open the project

```bash
open native-ios/Pulse/Pulse.xcodeproj
```

1. Select the **Pulse** target.
2. Set your **Team** under Signing & Capabilities.
3. Pick an iPhone simulator or your device.
4. Run (⌘R).

**Requirements:** Xcode 15+, iOS 17+ deployment target.

## First launch

1. Tap the server icon on the login screen.
2. Enter your API base URL (HTTPS, no trailing slash), e.g. `https://your-pulse-api.onrender.com`.
3. Optionally tap **Test connection**.
4. Enter your 4-digit PIN.

The app stores the session token in the Keychain and sends `Authorization: Bearer …` on API calls. The backend on this branch accepts Bearer tokens (and still supports cookies for the web app).

## What was replicated

| Web / Capacitor mobile | Native iOS |
| --- | --- |
| PIN login | Native PIN pad + Keychain session |
| Home / Insights / Calendar / Settings tabs | Custom tab bar + center Quick Add |
| Quick Add + keyword category hints | Sheet with type, categories, trips, recurrence |
| Month switcher, metrics, recent rows | Same IA with Swift Charts donut |
| Trips CRUD + summary | Native list, swipe rename/delete |
| Global search | Search sheet with sort |
| Onboarding category builder | Full-screen SwiftUI onboarding |
| Savings goal (local) | UserDefaults-backed goal sheet |
| Export / backup / clear | Share Sheet exports + confirm clear |
| Admin user management | Native admin sheet |

## iOS-native behavior included

- Face ID / Touch ID app lock (Settings toggle; locks on background)
- Haptics on PIN, tab changes, save/delete
- Pull-to-refresh on Home / Insights / Calendar
- Swipe actions + context menus on transactions
- Bottom sheet Quick Add with drag indicator
- Keychain session persistence
- Share Sheet for Excel / CSV exports
- Safe-area aware custom tab bar
- Dark Pulse visual language (purple/pink accents, serif titles)

## Backend notes

Deploy / run the server from this branch so native auth works:

- `POST /api/login` returns `{ displayName, token, expiresAt }`
- Authenticated routes accept `Authorization: Bearer <token>` or the `pulse_session` cookie
- Cookies use `SameSite=None; Secure` for cross-origin clients

Set `CLIENT_ORIGINS` for any web/Capacitor clients as before. Native Bearer auth does not require CORS.

## Project layout

```
native-ios/Pulse/
  Pulse.xcodeproj
  Pulse/
    PulseApp.swift
    Models/
    Services/          # APIClient, AppState, Keychain
    Theme/
    Views/             # Login, Home, Insights, Calendar, Settings, …
    Resources/Assets.xcassets
    Info.plist
```

The older Capacitor shell under `/ios` remains available; this native app is the intended iPhone client going forward.
