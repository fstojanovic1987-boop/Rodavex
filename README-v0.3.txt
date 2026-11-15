RODAVEX v0.3.1 BETA — VEHICLE CATALOG + CLOUD FOUNDATION

CONTENTS
- index.html: Rodavex app, Supabase connection/auth/cloud panel, and cascading category/brand/model catalog.
- Vehicle catalog includes cars, trucks, motorcycles, vans, tractors, construction machinery, trailers, buses and boats. Brand/model can also be typed manually.
- sw.js: service worker cache bumped to v0.3.0.
- manifest.webmanifest, icon.svg: PWA metadata and icon.
- supabase-setup.sql: database schema, organization creation RPC, and RLS policies.

IMPORTANT MIGRATION NOTES
1. Existing browser data remains in localStorage under the original key vehiclog_mvp_01.
2. The app does NOT automatically overwrite cloud or local data during login.
3. Create a Supabase project, run supabase-setup.sql in SQL Editor, then in Rodavex open Cloud / Firma.
4. Enter Supabase Project URL and anon/publishable key only. NEVER enter service_role or secret keys in the browser. The make/model catalog is bundled in the app and does not require a database migration.
5. Register/login, create an organization, export a JSON backup, then explicitly use "Prenesi lokalne podatke u cloud".
6. "Učitaj cloud podatke" replaces local data with cloud snapshot; export a backup first.

BETA LIMITATIONS
- This is a first cloud foundation using one JSONB snapshot per organization, not yet a complete multi-user fleet product.
- Member invitation and role-based screens are not implemented yet. SQL policies already limit snapshot writes to owner/admin/manager roles.
- Do not use with real business-critical records until tested with separate test accounts and a reviewed privacy/security setup.
- Supabase Auth email confirmation may need to be enabled/disabled in the Supabase Auth settings for your desired onboarding flow.
