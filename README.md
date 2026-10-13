# Smart Horeca Owner

Native mobile app for Smart Horeca restaurant owners (Flutter, Android/iOS).

## Project status

**Approved UI foundation — design preview, not a production application.**

- Approved light and dark themes plus System theme mode.
- Exact fixed navigation layout: Главная, Кассы, Отчёты, AI.
- Preview: sign-in layout, CHAIN multi-restaurant selection, overview, cash register and shift/check detail, OLAP and stock views, AI conversation UI, notifications and profile.
- UI shows labeled illustrative data only; **the real Smart Horeca API is NOT connected**.
- Real auth, backend authorization, privacy and CHAIN scope must pass the security gate before entering production.
- Full Russian/Azerbaijani/English localization, high-fidelity visual parity review, and Android/iOS generated runner projects remain to be completed.

## Design is locked

Read [docs/DESIGN_LOCK.md](docs/DESIGN_LOCK.md) before changing widgets, colors, typography, screen order, route navigation or behavior. The approved conversation mockups from 2026-10-13 are the reference. No independent redesign is allowed.

Server integration review: [docs/API_BOUNDARY.md](docs/API_BOUNDARY.md).

## Preview locally

Install the stable Flutter SDK, Android tooling, and (for iOS) Xcode on macOS.

```bash
git clone https://github.com/Anar044/SmartHoreca-Owner.git
cd SmartHoreca-Owner
git checkout feature/approved-ui-foundation
flutter create . --platforms=android,ios
flutter pub get
flutter run
```

The login view intentionally opens a **design demo** instead of authenticating. No real data or connection settings are bundled.

## Validation

```bash
flutter analyze
flutter test
```

Repository CI is configured to run those checks on feature branches. This environment does not have Flutter SDK installed; local/CI validation must complete before release.

## Repository boundaries

- This is a separate Flutter application repository.
- Never commit private server credentials, Supabase service-role keys, OpenAI API keys, or restaurant financial exports.
- Never change `Anar044/anarsystem/main` just to adjust the mobile app visual theme.
- Future backend changes belong in a separate feature branch, review and test before merge.
