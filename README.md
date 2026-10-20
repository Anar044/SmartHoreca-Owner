# Smart Horeca Owner

Native mobile app for Smart Horeca restaurant owners (Flutter, Android/iOS).

## Project status

**Approved UI foundation + connected authentication code (feature branch only). This is NOT production-ready.**

- Approved light and dark themes plus System theme mode.
- Exact fixed navigation layout: Главная, Кассы, Отчёты, AI.
- Preview: sign-in layout, CHAIN multi-restaurant selection, overview, cash register and shift/check detail, OLAP and stock views, AI conversation UI, notifications and profile.
- Supabase email/password login, owner workspaces and scope-aware summary use new **feature-branch** mobile API routes. They require separately deployed backend changes. When logged in, missing API data is shown as an error, never silently replaced with sample money values.
- Cash register, remaining reports, stock and AI screens are still clearly labeled design previews. Real endpoints for those sections are next milestones.
- Mobile server branch: `Anar044/anarsystem` → `feature/owner-mobile-readonly-api-v1` (draft PR #104). Verify isolation/security with real CHAIN before merging.
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

The login form uses Supabase when initialized with compile-time configuration. **Do not** add server-side secret keys. The design demo remains enabled by default during development.

## Run with authorized account (after mobile API deployment)

```bash
flutter run --dart-define=SH_ENABLE_DEMO=false --dart-define=SH_API_BASE_URL=https://smarthoreca.pages.dev --dart-define=SH_SUPABASE_URL=YOUR_PUBLIC_SUPABASE_URL --dart-define=SH_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
```

These are public client parameters. Never pass service-role credentials or upstream SH Server passwords. Until the server feature branch is reviewed and deployed, real login will not be able to load its mobile routes.

## Test Android preview

The Flutter CI workflow builds a labeled **design preview APK** (no real credentials). Open the latest successful GitHub Actions run and download the `Smart-Horeca-Owner-Android-Preview` artifact under Artifacts.

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
