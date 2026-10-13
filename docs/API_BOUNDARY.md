# Mobile API integration contract — pending (no live connection)

Purpose: Smart Horeca Owner renders existing system analytics and does not perform business mutations.

## Existing server functions reviewed
- GET /api/access/me — existing Supabase authentication and access context.
- GET/POST /api/access/workspaces — existing workspace listing / selection. Native mobile selection must not rely solely on browser cookies.
- GET /api/iiko/state — existing connection and access state; its complete payload is NOT a mobile credential endpoint.
- POST /api/iiko/dashboard-summary /dashboard — summary and OLAP data for dashboard.
- POST /api/iiko/cash-shifts and /cash-shift-detail — cash shifts, with explicit CHAIN scope checks.
- POST /api/iiko/olap — fields/query with middleware permission reports.olap.
- POST /api/iiko/stock-balances — inventory by warehouses.
- POST /api/iiko/stock-movements — movements.
- GET/POST /api/ai-assistant — chat and history; existing responses readOnly for business data.
- POST /api/ai-assistant-speech /ai-assistant-transcribe — speech endpoints.
- GET /api/plugin/data and /api/plugin/order-history — upstream plugin data (only where scoped and authorized).

## Security findings requiring implementation before mobile use
1. Implement a server-validated workspace context passed explicitly in mobile requests; avoid implicit web-browser cookie assumptions.
2. Use an allowlist of read-only mobile business endpoints and reject all mutations, even if a user's web role has write permissions.
3. Audit and enforce assistant.use and appropriate restaurant/role permissions for AI and both speech endpoints. Do not expose another owner's conversations.
4. Filter all CHAIN restaurant data on server, fail closed for missing/ambiguous department mappings, verify cross-workspace access attempts.
5. Do not send credentials for SH Server or integration/VPS API keys to Flutter. Audit upstream state endpoints to return mobile-safe projections only.
6. Implement controlled tokens/refresh/revocation and avoid user credentials/financial content in logs.
7. Define consistent metrics: gross, net, returns, paid checks, open orders, cash movement, cost/stock values.
8. No production dataset should be rendered in demo unless connection and permissions are successfully verified.

## Proposed mobile routes (not implemented yet)
GET /api/mobile/v1/me
GET /api/mobile/v1/workspaces
POST /api/mobile/v1/context/select
GET /api/mobile/v1/summary
GET /api/mobile/v1/cash-registers
GET /api/mobile/v1/shifts?from=YYYY-MM-DD&to=YYYY-MM-DD (implemented in backend feature branch; max 7 days)
GET /api/mobile/v1/shift?id=<shift-id> (implemented in backend feature branch; checked department before serialization)
GET /api/mobile/v1/checks
GET /api/mobile/v1/checks/:id
POST /api/mobile/v1/reports/query (query only)
GET /api/mobile/v1/inventory/balances
GET /api/mobile/v1/inventory/products/:id
GET /api/mobile/v1/notifications
POST /api/mobile/v1/notifications/subscriptions (per-user settings only)

The workspaces, bootstrap, summary, shifts and shift routes exist **only in the separate backend feature branch** until reviewed and deployed. Cash checks/list/receipt details and stock/AI mobile endpoints are not yet implemented. No endpoint is production-ready without tenant isolation and CHAIN integration testing.

## Acceptance
- Authorized selected restaurants never leak unselected ones.
- No cross-owner/cross-workspace access on any endpoint.
- Values agree with web SH for identical scopes and time periods.
- Missing fields are represented as unavailable; not zero or sample data.
- Offline data has an explicit timestamp and stale status.
