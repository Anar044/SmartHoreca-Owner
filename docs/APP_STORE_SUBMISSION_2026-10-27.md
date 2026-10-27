# SH Owner — App Store Production Submission Kit (draft)
Date: 2026-10-27

**Status: draft for production review, NOT submitted to Apple.**
The latest verified TestFlight IPA was uploaded successfully by
[GitHub Actions #40493793871](https://github.com/Anar044/SmartHoreca-Owner/actions/runs/40493793871).
This does **not** mean that the iOS app is approved or publicly released.

## 1. App identity (verified in repository)

- App Store app name: **SH Owner**
- Home screen name: **SH Owner**
- Bundle ID: **com.smarthoreca.owner**
- Product: authenticated, read-only Smart Horeca restaurant-owner companion app
- Target audience: restaurant owners and managers authorized by an organization
- Languages in application: Azerbaijani, Russian, English
- Current Flutter version: **0.1.2**; App Store production marketing version should be reviewed before selecting a version in App Store Connect
- Proposed category: **Business**
- Proposed listing type: **Free download**, access requires an existing authorized organization account (confirm commercial eligibility and any paid outside-the-app service descriptions).
- Proposed first availability: **Azerbaijan** (owner must confirm; this is only a suggestion).
- Suggested primary metadata locale: **English (U.K.)** (Apple does not currently list Azerbaijani as an App Store Connect metadata localization; the app interface may still be in Azerbaijani). Additional listing locale: Russian.

## 2. English (U.K.) — App Store product page copy

**Name** (max 30 chars): SH Owner

**Subtitle** (max 30 chars): Restaurant business insights

**Promotional text** (optional):
Your restaurant network at a glance. View sales, cash shifts, reports, stock information and AI-assisted summaries in a secure owner dashboard.

**Description:**

SH Owner is the mobile companion app for restaurant owners and authorized managers using Smart Horeca.

Stay informed about your restaurant or restaurant group from your iPhone.

Key features:
- View your selected restaurants and key business indicators.
- Review cash-register shifts, transactions and related reports where available.
- Explore sales, inventory information and analytics.
- Ask the Smart Horeca AI assistant questions about authorized restaurant data.
- View charts, copy analytical summaries and export AI answers to PDF.
- Choose Azerbaijani, Russian or English in the app.
- Manage notification preferences for supported cash-register events.

SH Owner provides read-only insight. Creating or editing accounting documents and system configurations through the AI assistant is not supported.

**Important:** An existing Smart Horeca account and access to an authorized organization are required. Available data and features depend on your organization's configuration, permissions and connectivity.

**Keywords** (check ≤100 characters in App Store Connect):
restaurant,owner,analytics,sales,reports,cash register,inventory,business,management

**Support URL** (existing public company website, verify approval for app support):
https://www.smarthoreca.az/

**Privacy Policy URL**: REQUIRED — must be supplied and publicly reachable before submission. Do not invent a URL.

**Marketing URL** (optional, company website subject to confirmation):
https://www.smarthoreca.az/

**What's New for initial 1.0 release**:
Initial release of SH Owner for authorized Smart Horeca restaurant owners, with dashboards, cash-register information, analytics, multilingual AI assistance, charts and PDF export.

## 3. Russian — additional localization (if added in App Store Connect)

**Name**: SH Owner

**Subtitle**: Аналитика для ресторанов

**Description:**

SH Owner — мобильное приложение для владельцев ресторанов и уполномоченных руководителей, подключённых к Smart Horeca.

Контролируйте показатели выбранных ресторанов и ресторанных сетей с iPhone.

Возможности приложения:
- Просмотр выбранных ресторанов и ключевых показателей.
- Информация о кассах, сменах и операциях.
- Отчёты по продажам и остаткам.
- AI Smart Horeca Assistant для вопросов по доступным данным.
- Диаграммы, копирование ответов и экспорт аналитики в PDF.
- Интерфейс на азербайджанском, русском и английском языках.
- Настройка уведомлений о поддерживаемых кассовых событиях.

Приложение предназначено для просмотра данных. Изменение бухгалтерских документов и настроек через AI не поддерживается.

Для работы необходима действующая учётная запись Smart Horeca с предоставленным доступом к организации. Возможности зависят от подключений и разрешений пользователя.

**Keywords**:
ресторан,владелец,аналитика,продажи,касса,отчёты,склад,управление,бизнес

## 4. Review notes — fill in before copying to Apple

SH Owner is a business-focused read-only companion for authorized Smart Horeca customers.

Login is required. Accounts are issued by the organization administrator; public self-registration is not offered inside the app. The app shows only the restaurants and data permitted to the signed-in account. No accounting documents or restaurant settings can be changed through the AI.

Reviewers must receive a **separate, restricted demo/review account** for an isolated sample tenant; never share a real customer's financial data. It must have valid credentials, selected restaurants, sample reporting data, and AI access during review. Enter credentials directly into **App Store Connect → App Review Information**; never add passwords or tokens to GitHub.

Explain where to find:
- Home → business summary
- Cash Registers → shifts and cash details
- Reports → sales, OLAP and stock where enabled
- AI → question, chart, Copy and PDF export
- Profile → language and notification settings

Third-party systems: Supabase authentication, Smart Horeca server, AI voice transcription for explicitly recorded questions, Firebase Cloud Messaging (if configured). Complete accurate App Privacy disclosures including relevant SDKs.

Review contact name, phone and email: REQUIRED — supply privately in App Store Connect.
Production API endpoint / test reviewer tenant: REQUIRED — verify accessible at review time.

## 5. Release blockers / checklist

- [x] App Store Connect identity and Apple distribution signing configured, based on signed TestFlight uploads.
- [x] Signed IPA successfully uploaded to TestFlight in GitHub Actions #40493793871.
- [ ] **Production API confirmed**. The current TestFlight workflow still defaults to
  `https://feature-owner-mobile-readonl.smarthoreca.pages.dev` when
  `SH_OWNER_API_ORIGIN` is missing. The actual GitHub Actions variable's value
  could not be read here. Do not ship a public app using an unverified Preview
  environment. Set and verify a stable owner API domain and fully deploy
  the mobile routes before creating a production IPA.
- [ ] Verify read-only tenant/workspace/restaurant isolation with two independent organizations; include AI, cash, reports, PDF and push.
- [ ] Verify full live-device login, AI and PDF and no errors with both active and empty restaurant accounts.
- [ ] Publish an accurate **public privacy policy**, linking within the app and in App Store Connect, covering authorized financial data, device/push identifiers, account email, third-party SDKs, voice uploads, retention/deletion and contact.
- [ ] Review the account/data deletion process and whether Apple in-app deletion rules apply to your account-creation flow; document the data-request contact.
- [ ] Fill out App Privacy nutrition labels and age-rating questionnaire truthfully.
- [ ] Supply genuine clean screenshots on a supported iPhone size; **do not show real customer financial information**. iPad screenshots are required if iPadOS is supported.
- [ ] Confirm sales region(s), free/paid setup and tax category and complete agreements if applicable.
- [ ] Prepare and validate a least-privilege App Review login linked to synthetic/approved sample tenant.
- [ ] Fill in review contact details, export-compliance questions, Content Rights and other conditional App Store Connect fields.
- [ ] Confirm iOS push configuration or accurately disclose that it is unavailable.
- [ ] Check whether the intended App Store version should be 1.0.0 rather than the present 0.1.2; upload a matching signed IPA if needed.
- [ ] In App Store Connect choose version + processed build → **Add for Review** → **Submit for Review**.
- [ ] Choose manual public release after approval for controlled rollout.

## 6. Explicit restrictions

**Do not**:
- submit an app to Apple with demo auth enabled or a Preview server hardcoded;
- upload screenshots containing customer sales or personally identifying data;
- put App Review credentials in a public GitHub file;
- mark the privacy nutrition label as 'No data collected' without confirming the actual implementation;
- claim an App Store review submission happened just because TestFlight upload succeeded.

This is a release plan and copy draft, not an Apple submission or approval.
