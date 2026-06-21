# IOS-Karacabey

Native iOS application for Karacabey Gross Market.

## Project

- Xcode project: `Karacabey Gross Market.xcodeproj`
- Main app target: `Karacabey Gross Market`
- Widget extension: `KGMWidgets`
- Notification service extension: `KGMNotificationService`
- Backend API: `https://api.karacabeygrossmarket.com/api/v1`

## Local setup

1. Open `Karacabey Gross Market.xcodeproj` in Xcode.
2. Select the `Karacabey Gross Market` scheme.
3. Configure signing with the correct Apple Developer team.
4. Add private runtime files locally only when needed:
   - `GoogleService-Info.plist`
   - provisioning profiles
   - signing certificates
   - private `.env` or local config files

These files are intentionally ignored by git and must not be committed to the public repository.

## Production notes

- Payment, checkout, cart, account, push, widgets, telemetry, and support flows are implemented against the live Karacabey Gross Market API surface.
- Secrets and provider credentials must stay in Apple/Firebase/CI secret stores, never in source control.
- Release builds should be validated with code signing, API connectivity, push/Firebase configuration, and checkout/payment smoke tests before App Store upload.
