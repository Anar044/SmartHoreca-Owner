# Smart Horeca Owner — approved UI contract v1.0

Status: DESIGN APPROVED on 2026-10-13. This file is a binding visual acceptance standard for the Flutter mobile app. Do not redesign screens without explicit product approval.

## Fixed product scope
- Owner-only, read-only access to business data. User settings and AI conversation history may be updated; cash, checks, inventory, documents and fiscal data must never be modified by the mobile app.
- Android and iOS using one Flutter codebase.
- Exactly four main navigation tabs: Главная, Кассы, Отчёты, AI.
- Notifications via top-right bell; profile via top-right avatar; inventory nested under Отчёты.
- One selection of authorized restaurants shared by all tabs and AI. Single-restaurant users do not see unnecessary CHAIN selectors.
- Languages: Russian, Azerbaijani, English (complete UI localization required before release).
- Theme options: Light, Dark, System, switching without loss of screen/filter state.
- Existing web Smart Horeca and anarsystem/main are outside the mobile visual theme contract and MUST NOT be restyled.

## Visual tokens (initial implementation baseline)
| Element | Dark | Light |
|---|---|---|
| App background | #0D1728 | #F3F6FC |
| Surface/card | #19283F | #FFFFFF |
| Raised surface | #233650 | #E9F0FA |
| Primary text | #F6F9FF | #132844 |
| Secondary text | #A8BAD0 | #64748B |
| Primary accent | #3B82F6 | #2563EB |
| Success | #4ADE80 | #15803D |
| Warning | #F59E0B | #B45309 |
| Error | #F87171 | #DC2626 |

- Card radii: 14–18dp; outer horizontal padding: 16dp; 8dp baseline spacing grid.
- Low visual noise, card-based KPI layout, vertically scrolling contents, charts that fit phone width.
- Keep title, restaurant selector, date selector, and status of data conspicuous.
- Consistent format for AZN, units, percentages; show a real 'last updated' timestamp.
- Bottom navigation: persistent, four items, highlight active tab in blue.
- Dialogs, charts, keyboard, empty/error/denied states all require both theme variants.
- Keep tap areas at least 44dp, scalable text, accessibility labels, no clipping at 320dp and 390dp widths.
- No hardcoded credentials, server addresses or fake-looking live data.

## Screens — accepted information architecture

### Authorization
Splash, email/password, recovery, workspace selection, authorized restaurant multi-select, session refresh and failure modes. Use existing backend authorization; no mandatory second account registration.

### Home
Today / Yesterday / 7 days / custom range. KPI: revenue, paid checks, avg check, profit ONLY when supported by a trustworthy source. Sales chart, restaurant comparisons and popular dishes; tap KPI to open report. Separate pending orders and returns from collected revenue.

### Cash registers (8 agreed screens)
1. Register list.
2. Search/filter (restaurants, register, shift status).
3. Register summary.
4. Payment methods and amounts.
5. Shift history.
6. Shift detail.
7. Checks list.
8. Check detail with items, discounts and tender splits.

### Reports and OLAP
Catalog; scoped filters; chart view; table view; tree drilldown with one parent row per cashier; OLAP read-only display parameters; export; products/inventory subsection. Persist scope and filters. No saving/changing server OLAP templates in the app.

### Inventory
Overview with inventory value, positions, negatives, below minimum; restaurant+warehouse selection; product search; statuses: positive, zero, negative, below minimum; product detail by warehouse; as-of timestamp, per-unit cost and extended value; only add movement history when contract is verified. Never conflate missing data with zero. Avoid summing incompatible units.

### AI Smart Horeca Assistant
Chat, chart, table, voice input/output, conversation history, report provenance, scope and fresh-data timestamps. No business mutations. Explicitly distinguish AI analytical reports from source records.

### Notifications and profile
List, event detail, filtering, subscription preferences, theme/light/dark/system, language, authorized workspaces/restaurants, security and log out. Push is a future backend milestone, not currently operational.

### Shared states
Loading, empty, offline/stale, forbidden, error/retry; all with complete light/dark presentations.

## Visual validation acceptance
- Compare screenshots side-by-side against the 2026-10-13 approved conversation mockups, screen-by-screen, at matching device dimensions.
- Same order of UI elements, hierarchy, bottom tabs, interaction paths, card density, accent use and theme parity. Treat the generated collages as the visual direction; adjust precise dimensions for usability and mobile accessibility.
- No spontaneous redesign, new tab, mismatched light/dark structure or replacing actual results with sample financial numbers.
- UI preview can use labeled demonstration data only; production data views need API access, correctly restricted to restaurant scope.
- Run visual golden tests when Flutter SDK/CI environment is available. In code review attach both light and dark screenshots for each key screen.

## Security gate before real login/integration
- Existing web uses Supabase Auth, /api/access/me, /api/access/workspaces and /api/iiko/_middleware; mobile requires an explicit supported workspace/restaurant scope contract not dependent on browser cookies.
- Create mobile-specific read-only endpoints or allowlisted operations. Never deliver SH Server credentials, tokens for upstream systems or platform keys to mobile.
- All tenant and restaurant filtering happens server-side and fail-closed; enforce permissions on AI and voice as well as reporting.
- Existing D1 and OLAP integrations remain authoritative. Do not change anarsystem/main without separate approval.

## Development rule
Build on feature branches. No merge to main without a design parity review and passing authorization/scope acceptance tests.
