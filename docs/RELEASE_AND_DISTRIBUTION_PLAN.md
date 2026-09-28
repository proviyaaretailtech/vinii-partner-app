# Proviyaa Master — Release & Distribution: foundation plan
### Custom client builds from sales requirements, with module control (the "version-control OS")

**Status:** proposal for founder review · **Date:** 2026-09-21 · **Scope:** the Master Control Plane (not One Local)
**Where this belongs:** in the OS repository (`Repo-1-`) next to the Master code. It sits in the workspace `docs/` folder because that repository is not checked out on this machine.
**Built from:** the founder architecture documents (copies in `proviyaa-pos/docs/sources/`), the POS PRD and decision record (D01–D10), two questions to the founder notebook (AI summaries, treated as context), your three screen sets, the POS repository's CI, and the table names visible in the shared Supabase project. Appendix B rates the confidence of each source.

---

## 0. The answer on one page

### 0.1 What this is
A capability of the Master Control Plane that takes a won deal and its confirmed requirements, turns them into a configured, licensed app for that client, gets it onto the client's devices, and keeps every client on a known, supported version afterwards. Every setting can be traced back to the requirement that caused it. It is **not** a separate OS with its own database: clients, branches, modules, people and plans come from Master's existing tables. It adds only releases, builds, devices, rollouts and issue-to-fix links.

```
Existing OS (sales & CS)       Deal won → Create organization → requirements, each with a disposition:
        │                      Confirmed — configuration │ Ask Sales (blocks publishing) │ product gap → backlog
        ▼
Master: commercial             Subscription (plan + packs + add-ons) → entitlements
        │
        ▼
Master: configuration          Client app (from the business-type template)
        │                      → configuration draft: modules, branding, roles, workflows, rules
        │                      → validate → preview → approve → publish (versioned, signed)
        ▼
Master: release management     One release per platform → signed installers → rollouts (rings, deadlines, rollback)
        │
        ▼
Client devices                 Enroll by QR → licence + configuration → heartbeat every 60 s
        │                      → updates install at shift close → device reports its versions
        ▼
Master: support & dashboards   Client versions · adoption · distribution log · issue → fix → targeted rollout
```

### 0.2 Seven principles
1. **One release, many configurations.** A client's "custom build" is the shared release plus that client's signed configuration and licence. A per-client compile happens only for paid white-label identity (own app name, icon, store listing). Your documents already say this: *Build Once → Register Once → Release Once → … Configure per organization* (viyaa routes §40), and the POS PRD §8: both restaurants *"run the same POS application… [the OS] does not inject client-specific code or schema."*
2. **Module control = Feature Store + entitlement + configuration.** The server enforces it on every call; the device mirrors it for display and offline use.
3. **Every setting is traceable to a reason:** a sales requirement, the template, or a named person's change.
4. **Five version numbers, one compatibility matrix.** Master refuses to ship any combination that has not been declared compatible (§7).
5. **Updates never cost a merchant data or a sale in progress.** Updates wait for the shift to close; unsynced records survive every update; a missed deadline or expired licence blocks *new* sales, never evidence upload (PRD §11).
6. **A download is not an install.** Only a device's own heartbeat proves which version it runs.
7. **Reuse, don't duplicate.** Clients are organizations, branches are locations, modules come from the Feature Store, people come from memberships and roles. New tables point at them.

### 0.3 What to build first
**Windows-only release control** (Phase 1). The POS is Windows-first (D01) and CI already builds Windows on every push to `main`. Phase 1 covers a signed installer, release approval, device enrollment and heartbeat, an auto-update that waits for shift close, and the Client Versions, Version Adoption and Distribution Log screens. Configuration-driven module control follows in Phase 2. Neither needs a per-client compile.

### 0.4 Decisions needed from you
| # | Decision | My default if you say "your call" | Needed by |
|---|---|---|---|
| R1 | Name: your screens call this "Proviyaa Commerce OS"; your documents use Commerce OS for the transactional core and Master for the control plane | Keep **Master**; call this module **Release & Distribution** | P0 |
| R2 | Approve the core rule: one release, many configurations; per-client compiles only for paid white-label | Yes | P0 |
| R3 | Where the code lives and in which stack; read access to `Repo-1-` (or a schema-only dump) so the table map can be confirmed | Master code in `Repo-1-`, on the documented stack (NestJS modular monolith per the notebook) | P0 |
| R4 | Windows installer/updater technology and a code-signing service (2-day spike, small budget) | Spike MSIX with App Installer first; cloud signing service | P0 |
| R5 | Offline grace for the device licence | 7 days, renewed by every heartbeat; expiry blocks new sales only | P1 |
| R6 | What a missed mandatory-update deadline does to a POS | Blocks starting a new shift; never blocks sync; support can issue an extension code | P1 |
| R7 | Who approves: release to stable, configuration to a live client, mandatory rollout, production signing | Two people each time (engineering lead + release manager or CS lead) | P1 |
| R8 | iOS for the POS in v1? | No (D01 is Windows first); App Store route when needed | P4 |
| R9 | White-label as a paid add-on? (the documented add-on list has no such item) | Yes, priced add-on | P4 |
| R10 | Product-gap policy: who triages, and may sales promise dates? | Product owner triages weekly; sales never promises dates | P2 |
| R11 | Make the POS repository private before signing and deployment secrets are attached (it is public today) | Yes | P1 |
| R12 | May merchant owners enroll devices and press "Update now" for their own branches? | Yes, own organization only; Proviyaa support can do both | P1 |

---

## 1. What your documents already decide

| # | Source | What it says | Consequence here |
|---|---|---|---|
| G1 | viyaa routes §40 | Build Once → Register Once → Release Once → package or sell → subscribe → entitlement → configure per organization → activate → measure | One release train; customization is configuration |
| G2 | POS PRD §8 | Sales requirement → confirmed disposition → organization/location → permitted features → approved preset → settings preview → approved version → device enrollment → test sale and kitchen output → training evidence → go-live. No client-specific code or schema | The lifecycle in §4 |
| G3 | Product Flow §6 "Version control model" | Every capability has FEATURE, FEATURE VERSION, ENTITLEMENT, CONFIGURATION, ROLLOUT STATE; no database redesign between versions | Modules are versioned features with a rollout state (§7) |
| G4 | viyaa routes §27; Product Flow Phase 2 | Release Management: features, versions, environments (dev, staging, prod), feature flags, beta releases, rollouts, approvals, UAT, deployment, rollback — built in the Master Control phase | Releases, rings, approvals |
| G5 | Product Architecture PAGE-MST-014; viyaa routes §35 | Plan + Pack + Add-on + Market + Business Type + Role = actual feature access; Feature Store → Subscription → Entitlement → Permission → Application | The module-control chain (§6) |
| G6 | viyaa routes §36 | Configuration hierarchy: platform default → region → plan → organization → location → role → user; the most specific valid value wins | How a snapshot is resolved |
| G7 | POS source understanding §6; PRD §8 | Configuration can never disable tenant isolation, authorization, financial evidence, audit, valid state transitions or idempotency. An open order keeps the configuration and price version it began with | Non-configurable invariants; orders record their configuration version |
| G8 | Product Architecture §70, PAGE-ORG-008; PRD §7, §10 | Device registry: DEVICE → ORGANIZATION → LOCATION → USER → CAPABILITY → STATUS → LAST SEEN. Secure online enrollment binds device, organization and location; bootstrap returns a device grant, configuration version and initial sync scope | Devices and enrollment (§10) |
| G9 | Decisions D01, D04, D05, D06, D10 | Windows first with an 80 mm printer; heartbeat every 60 s; offline staff grant 24 h; OneCity reachability timeout 5 min; PowerSync direction; the OS repository owns central migrations; Drift/SQLite with numbered forward migrations; never delete unsynced records | Platform order, heartbeat, update safety, governance |
| G10 | PRD §11 | Suspension reaches an offline device only on reconnect or grant expiry; new-sale permission is separate from uploading historic evidence; an expired grant preserves data | Licence and mandatory-update behaviour |
| G11 | Product Architecture §97; Product Flow Phase 0 | Every feature traceable Figma → PAGE-ID → route → component → action → API-ID → PERMISSION-ID → rule → EVENT-ID → database → … → QA; no domain without a registry entry | Appendix A proposes the IDs |
| G12 | Founder notebook (test script) | Each requirement carries a decision and disposition: *Confirmed — configuration*, *Ask Sales* (routes a question back to the sales rep as work), *product gap* (left out of the demo plan; "no product backlog for it to land in" is a known limit). "Create organization" runs about eight steps automatically (organization linked to the deal, onboarding workflow, customer record, requirements carried over, handoff logged, first work item queued, team notified, timelines written). Customer Success runs seven fixed readiness checks | The requirement → configuration link; the product-gap backlog; the go-live gate |
| G13 | Founder notebook (stack) | Turborepo + Melos monorepo; NestJS modular monolith; GitHub Actions with shadow-database migration dry runs; web on Vercel, API on Railway or Fly; Flutter builds to store internal tracks with Fastlane. **Silent** on Windows auto-update, device management and offline licence keys | §8–§10 fill these gaps |
| G14 | `proviyaa-pos/.github/workflows/build.yml`, `tool/run_local.sh` | Every push to `main` and every pull request: format, analyze, test; web build; Windows build published as an unsigned folder; settings injected with `--dart-define`; app version `0.1.0+1` | The starting point of the build pipeline |

---

## 2. Where the screens and the documents disagree, and the resolution

| Your screens show | Your documents say | Resolution |
|---|---|---|
| "Generate Build … includes only selected modules", and a Modules checklist on New Build | Modules are features switched on by entitlement and configuration on one release (G1–G3) | Modules move from the build form to the client's configuration. A release contains every generally available module; each client's configuration switches on only what it is entitled to |
| A build per client in the Build Queue, about 5 minutes each | Release once | Real compiles happen once per release per platform. Per-client work becomes *packaging* (attach configuration and licence), which takes seconds. Your own card "Move to Auto-Updates — avoid rebuilding and resending zips for every client" says the same |
| A drag-and-drop Visual Flow builder | UI/UX Studio, Workflow Studio and Rule Engine edit schemas inside pre-built application shells; the notebook finds no from-scratch app builder | The flow editor changes order, visibility, conditions and approvals between screens that modules already provide. It never creates screens or code |
| The distribution console inside a "Restaurant — Vendor Panel" showing "POS: Open & Accepting Orders" and "Active Cashier" | Master Admin (Proviyaa staff) and the Organization Portal (merchant) are separate applications (viyaa routes §29) | The console belongs in Master Admin without merchant chrome. Merchants get a small Devices & Updates page (PAGE-ORG-008) for their own devices, versions and tickets |
| "Proviyaa Commerce OS" as the name of the whole control plane | Commerce OS is the shared transactional core; the control plane is Master (Product Architecture §109; D07) | Decision R1 |
| iOS (.ipa) "send to client" by link or QR | Flutter builds ship to store tracks (notebook) | An .ipa cannot be handed to arbitrary businesses to install. iOS reaches clients through the App Store (unlisted, or Custom Apps via Apple Business Manager), or TestFlight for pilots |
| macOS on the New Build form | The POS targets Windows, Android and iOS | Leave macOS out unless a client needs it |

**Your key components, mapped**

| Component (workflow screen) | Lives in Master as | Status |
|---|---|---|
| Module Library | Feature Store (PAGE-MST-020) over the `modules` table | documented; `modules` exists live |
| Template Engine | Templates per business type (Restaurant, Store, Service) = the PRD's "approved preset" | documented as presets |
| Visual Flow Builder | Workflow Studio (PAGE-MST-023) + navigation in UI/UX Studio (PAGE-MST-022) | documented |
| Configuration Engine | Configuration service with the hierarchy in G6 | documented |
| Build Orchestrator | New — built on the POS CI | **new** |
| Runtime Frameworks | Flutter (POS on Windows, Android, iOS); web apps | documented |
| Update & Release | Release Management + a device updater | documented + **new updater** |
| Analytics & Support | Analytics platform; Support PAGE-SUP-001 to 007 | documented, support not built |

---

## 3. The core decision: what a "custom build" is

### 3.1 Three ways to do it
| | A. Compile per client | B. One build + runtime configuration | C. Hybrid (**recommended**) |
|---|---|---|---|
| Builds per release | clients × platforms (24 × 3 = 72 today) | one per platform (3) | one per platform + white-label clients |
| Change a module or setting | rebuild, re-sign, reinstall | publish configuration; live within about a minute | as B |
| Preview before building (workflow step 4) | needs a build | instant: same app + draft configuration | as B |
| Hotfix for everyone | 72 builds | 3 builds | 3 + white-label |
| Bugs only one client sees | common (different binaries) | rare (same binary) | rare |
| Unpaid module code on the device | not shipped | shipped but locked (server refuses; signed licence) | as B |
| Client's own app name, icon, store listing | yes | no | yes, via a thin wrapper |
| Matches your documents | no (G1, G2) | yes | yes |

**Recommendation: C.** B is the default for every client. A white-label wrapper build (same code, the client's name, icon, bundle id and installer publisher, with its organization id built in) exists only for clients who pay for their own app identity (R9). Even then, modules and settings arrive at runtime.

### 3.2 What needs a compile, and what is configuration
| Change | Delivered as |
|---|---|
| Switch a module on or off; change its settings | Configuration |
| Branding inside the app: logo, colours, fonts, receipt header | Configuration |
| Roles, permissions, navigation, labels, fields | Configuration |
| Workflows, approvals, rules (tax, pricing, routing) | Configuration |
| Receipt and KOT print templates, report definitions, custom fields | Configuration (extension points) |
| A new screen, module, bug fix or integration adapter | A new release, for every client |
| The client's own app name, icon, store listing or installer publisher | White-label wrapper build |
| Anything only one client would ever run | Not allowed: becomes a generic feature behind a flag, or is declined |

### 3.3 What sales may promise (the "custom functionality" ladder)
| Level | What it covers | Lead time | How it is delivered |
|---|---|---|---|
| 0 Configuration | anything in the client's plan that the Feature Store already has | same day | configuration version |
| 1 Extension | custom fields, print templates, report definitions, workflow rules, webhooks | days | configuration version |
| 2 Product feature | a capability the Feature Store does not have | a roadmap date from product, never from sales | product gap → backlog → feature in a release → available to every eligible client |
| 3 Integration | connecting a client's other system | weeks | a reusable connector in a release; the client's credentials stay on the server |
| Never | client-only code, a client branch, a client schema | — | — |

---

## 4. The lifecycle: from a sales requirement to a running, updating app

| # | Step (screen) | What happens | Owner | Reads (existing) | Writes (new) |
|---|---|---|---|---|---|
| 1 | Deal won | "Create organization" runs the existing automatic steps (G12) | Sales → CS | `deal_events`, organizations, `customers`, activities, work items | — |
| 2 | Requirements | CS gives each requirement a disposition: *Confirmed — configuration*, *Ask Sales*, *product gap* | CS | requirements (table name to confirm) | `config_item_sources`, `product_gaps` |
| 3 | Subscribe | Plan + packs + add-ons → entitlements (G5) | Commercial | plans, packs, add-ons, subscriptions, entitlements | — |
| 4 | Create (workflow 1) | Choose the template for the business type, name the app, pick platforms and update channel | Solutions | organizations, locations, `modules` | `client_apps` |
| 5 | Configure (workflow 2) | Branding, modules, features, roles, workflows, integrations. Only entitled modules can be switched on | Solutions | configurations, UI schema, organization settings | configuration draft |
| 6 | Visual flow (workflow 3) | Adjust navigation and workflows inside what modules provide | Solutions | workflows, workflow versions, rules | draft |
| 7 | Preview (workflow 4) | The same release runs the draft on a sandbox organization with demo data, in web, desktop and phone frames | Solutions + client | — | `preview_sessions` |
| 8 | Approve and publish | A second person approves; the version is frozen, hashed and signed | CS lead | audit approvals | `config_versions` |
| 9 | Package (workflow 5) | Pair the current release for each platform with the configuration and licence; white-label wrapper only if bought | System | releases, artifacts | `client_packages` |
| 10 | Distribute (workflow 6) | Expiring download link or QR; store invite for mobile | Support | — | `download_links`, `distribution_events` |
| 11 | Enroll (workflow 7) | Device scans the branch QR → gets its grant, configuration, licence and first sync | Client + support | device registry | `devices`, `enrollment_codes`, `licenses` |
| 12 | Go-live gate | CS's seven readiness checks plus system checks: device online, printer test, test sale, KOT printed, sync healthy | CS | `readiness_checks` | system check rows |
| 13 | Use | Heartbeat every 60 s reports versions and health (D04) | Device | — | device state |
| 14 | Manage & evolve (workflow 8) | New configuration versions, modules added or removed through the subscription, releases, rollouts, mandatory updates, rollback | Master | feature rollouts | `app_releases`, `rollouts`, `rollout_targets` |
| 15 | Support | Issue → fix (configuration or release) → deploy to affected clients → verified by heartbeat | Support | support pages (documented, not built) | issue tables |

### How "connecting" a requirement to the build works (worked example)
1. Sales records for Annapurna Main: *"Dine-in and takeaway only; the kitchen needs printed KOTs; no inventory for now; want WhatsApp loyalty."*
2. CS marks the first three parts *Confirmed — configuration* and maps them to configuration items:
   `channels = [dine_in, takeaway]` · `modules.kot.enabled = true` · `modules.kot.output = printer_80mm` · `modules.inventory.enabled = false`.
   Each item gets a source row pointing at that requirement.
3. "WhatsApp loyalty" is not in the Feature Store → marked *product gap* → a backlog row, linked to the client. It no longer disappears (today's known limit).
4. Configuration v1 is approved and published; Annapurna's POS picks it up on its next heartbeat.
5. Months later, anyone looking at the POS can see: *KOT is on because of requirement R-3, confirmed by CS on 12 Sep.*
6. When WhatsApp loyalty ships in a later release, every client whose gap is linked to it is listed for CS, who switch it on by configuration. No rebuild.

---

## 5. Data model, built on the existing tables

### 5.1 Rules
- **No second copy** of clients, branches, modules, people or plans. New tables hold foreign keys to Master's tables.
- New tables live in a **`release` schema owned by Master**. Migrations go through the OS repository (D06). The schema is not exposed through the Supabase Data API. Row-level security is on everywhere: Proviyaa staff see what their role allows, merchant owners see only their own organization, devices reach only the device endpoints.
- Logs, events and audit rows are append-only (Product Architecture §80).
- Key types follow whatever Master already uses (uuid or text) — to confirm in Phase 0.

### 5.2 Existing tables this plan reuses
**LIVE** = the name is visible in the shared Supabase project (columns not inspected) · **DOC** = specified in your documents, not verified live · **PLAN** = in our earlier plans.

| Screen concept | Existing table(s) | Status | Used for |
|---|---|---|---|
| Client ("Annapurna Main") | organizations (+ brands) | DOC | client list, business type, suspension |
| Branch ("Ausa Road, Latur") | locations | DOC | per-branch configuration and devices |
| Business type (Restaurant, Store, Service) | the organization's business type (PAGE-MST-002) | DOC | template choice |
| Owner / contact person | `customers` — the notebook says "Create organization" creates the customer as an individual, separate from the business | LIVE | contacts; **not** the client itself |
| Modules (POS, Billing, KOT, Inventory, CRM) | `modules`; features, feature versions, feature dependencies, feature rollouts | `modules` LIVE; rest DOC | module control, compatibility |
| Plans, packs, add-ons, subscription | plans, packs, add-ons, subscriptions (earlier plan: `plans`, `organization_subscriptions`) | DOC / PLAN | entitlements |
| Entitlements | entitlements | DOC | what a client may switch on |
| Configuration, UI schema, settings | configurations, UI schema, organization settings | DOC | configuration snapshots |
| Workflows (Visual Flow) | workflows, workflow versions, workflow nodes, rules | DOC | flow editor |
| People (Rahul, Neha) and roles | `org_users`, `roles`; memberships, permissions, role permissions | `org_users`, `roles` LIVE; rest DOC | assignees, approvals, permissions |
| Deal and requirements | `deal_events`; the demo's requirements table (name unknown); activities, work items | `deal_events` LIVE; rest notebook | requirement links, work queues |
| Go-live readiness | `readiness_checks` | LIVE | go-live gate |
| Devices | the device registry (G8) | DOC | installations |
| Support | tickets, ticket 360, incidents, SLA, escalations (PAGE-SUP-001 to 007) | DOC, not built | issue tracker |
| Audit | audit logs, audit changes, audit approvals | DOC | every approval, publish, deploy |
| Events | the event registry and bus (viyaa routes §26); outbox (PLAN) | DOC / PLAN | release and device events |
| Files | the document/media platform; Storage (PLAN) | DOC / PLAN | installers, logs, attachments |

### 5.3 New tables (only what nothing existing covers)

**Release and build**
| Table | Purpose | Key columns |
|---|---|---|
| `apps` | the applications Master releases | code (`vinii-pos`, `onlatur-rider`, `organization-portal`…), name, framework, platforms, repository |
| `app_releases` | one versioned release of an app | app, version (2.4.2), build number, channel (internal / pilot / stable), status (draft → building → testing → approved → published → deprecated / withdrawn), commit, notes, priority (normal / urgent / security), minimum supported version, configuration-schema range, API contract, central migration, device database schema, created by, approved by, published at |
| `release_modules` | which modules a release changes | release, module, module version, change (added / changed / fixed / removed) |
| `build_jobs` | one compile of a release for one platform (or one white-label wrapper) | release, platform, white label, status, attempt, runner, CI run link, queued / started / finished, error class, error message, log file |
| `build_steps` | the pipeline steps on the build screen | build job, step (source, dependencies, compile, package, sign, publish), status, started, finished |
| `build_artifacts` | immutable signed outputs | build job, platform, kind (MSIX / EXE / APK / AAB / IPA / web), file, size, SHA-256, signature, certificate fingerprint, SBOM, build provenance |
| `white_labels` | a client's own app identity (only if bought) | organization, app, display name, bundle id, icon and splash, store listing, signing identity reference |

**Client apps and configuration**
| Table | Purpose | Key columns |
|---|---|---|
| `templates`, `template_versions` | presets per business type | business type, version, default modules, default configuration, default workflows, demo data |
| `client_apps` | one client's application (workflow step 1) | organization, app, template version, name, platforms, channel, auto-update, update window, pinned version, white label, status |
| `config_versions` | immutable, signed configuration snapshots (reuse `configurations` instead if it already versions immutably) | client app, location (empty = all), version, parent version, schema version, content, content hash, signature, key id, status (draft → validated → in review → approved → published → superseded), created by, approved by, published at |
| `config_item_sources` | why each setting is on | configuration version, path (`modules.kot.enabled`), source (requirement / template / entitlement / manual), source id, note |
| `product_gaps` | requirements the product cannot meet yet | requirement, organization, title, status (new → triaged → planned → shipped / declined), feature, target release, number of clients asking |
| `preview_sessions` | a draft running on a sandbox organization | configuration version, sandbox organization, address, expiry |
| `client_packages` | what was prepared for a client | client app, release, platform, artifact, configuration version, optional provisioning file, created by |

**Devices and licensing**
| Table | Purpose | Key columns |
|---|---|---|
| `devices` (extend the documented registry if it exists) | one installed app on one machine, current state | organization, location, client app, platform, hardware, public key, status (pending / active / suspended / retired), enrolled at / by, last seen, app version, build, configuration version, device database schema, licence expiry, pending uploads, last sync, peripherals (printer, scanner, drawer), update state, last error |
| `enrollment_codes` | single-use QR or code for a branch | client app, location, code hash, expiry (15 min), created by, used by device |
| `device_rollups` | hourly history instead of a row per heartbeat | device, hour, minutes online, versions seen, error count |
| `licenses` | signed, device-bound grant for offline use | device, organization, modules, limits, issued, expires, grace until, key id, signature, revoked at |

**Distribution and rollouts**
| Table | Purpose | Key columns |
|---|---|---|
| `rollouts` | delivering a release to clients | release, scope (all / selected / new installs only / affected by an issue), rings, mandatory, deadline, enforcement (warn / block new shifts), status (draft → scheduled → running → paused → completed / rolled back), reason, created by, approved by |
| `rollout_targets` | progress per client and branch | rollout, client app, location, ring, from version, state (pending / offered / downloading / installed / failed / deferred / skipped), updated |
| `download_links` | the "send to client" link or QR | artifact, client app, token hash, expiry, maximum uses, uses, created by |
| `distribution_events` | append-only log (screen 8) | time, client app, device, release, artifact, method (auto-update / download / manual / store), actor (system / admin / support / client), result, error |

**Support loop** (only if the documented support tables do not exist yet; otherwise add these columns to them)
| Table | Purpose | Key columns |
|---|---|---|
| `issues` | client problems ("TK-1042") | organization, location, device, client app, reported version, configuration version, module, category, priority, blocking, status (open → triaged → in progress → waiting for client → fix ready → resolved → closed), assignee, SLA due |
| `issue_events` | the timeline (append-only) | issue, time, actor, kind (comment / status / assignment / link), body |
| `issue_affected` | which clients and devices are hit | issue, client app, device, version |
| `issue_fixes` | where it is fixed | issue, fix type (release / configuration), release or configuration version, verified at |

### 5.4 Dashboard figures, defined once
| Figure on your screens | Definition |
|---|---|
| Total clients | organizations with an active client app and at least one device seen in the last 7 days |
| Latest version | newest published release per app and channel |
| Auto-update enabled | client apps with auto-update on ÷ active client apps |
| Up to date / Update available / Outdated | every active device on the channel's latest release / some device behind, all at or above the minimum supported version / any device below the minimum supported version |
| Clients on old versions | clients that are *Update available* or *Outdated* |
| Builds failed (7 days) | build jobs whose final attempt failed |
| Open issues | issues not resolved or closed |
| Average build time | median duration of successful builds over 30 days, per platform |
| Version adoption | active devices by version (per-client view as a toggle) |
| Distribution log | `distribution_events` as recorded; "installed" is confirmed only by a heartbeat |

### 5.5 To confirm against the live database (Phase 0)
- What `modules`, `customers`, `deal_events`, `readiness_checks`, `org_users` and `roles` contain, and whether organizations, locations, plans, subscriptions, entitlements, configurations, devices and support tables exist under other names.
- Whether configurations are already versioned immutably (if so, reuse them and drop `config_versions`).
- Where requirements and their dispositions are stored.

This needs read access to `Repo-1-` or a schema-only dump. The POS decision record (Q04) says no schema inspection until access is approved, so I did not probe beyond the table names already seen.

---

## 6. Module control and configuration

### 6.1 The chain, and where it is enforced
Feature Store (*what exists*) → subscription (*what was bought*) → entitlement (*what is allowed*) → configuration (*what is switched on here*) → permission (*what this person may do*) → application (*what they see*).

Enforced in three places:
1. **In Master's studios:** a module the client is not entitled to cannot be switched on, and dependencies are checked (KOT needs POS; Loyalty needs CRM).
2. **On the server (the authority):** every API call checks entitlement and permission. Your documents require every call to carry request, tenant, user and authorization context (Product Architecture §82).
3. **On the device:** navigation hides disabled modules and locks unpaid ones. Offline, the signed licence decides.

### 6.2 What every module declares (its manifest in the Feature Store)
Id and version · business types it applies to · dependencies and conflicts · minimum app version · the settings it accepts (a piece of the configuration schema) · the permissions it defines · the events it emits · the data it syncs to devices (the PowerSync scope, D05) · where it appears in navigation · maturity (internal, beta, generally available, deprecated).

Switching a module off hides it and makes its data read-only. It never deletes data.

### 6.3 What a configuration snapshot contains
| Section | Examples | Edited in |
|---|---|---|
| Identity and branding | display name, logo, colours, fonts, receipt header | UI/UX Studio (PAGE-MST-022) |
| Modules and features | on/off, per-module settings | Feature Store + configuration |
| Navigation and UI | order, visibility, labels, fields | UI/UX Studio |
| Permissions | role → allowed actions, location scope | Roles and Permissions (PAGE-MST-005/006) |
| Workflows and rules | triggers, approvals, SLAs; pricing, tax and routing rules | Workflow Studio, Rule Engine (PAGE-MST-023/024) |
| Service model | dine-in, takeaway, delivery; pay-first or pay-later (the PRD §8 example) | configuration |
| Integrations | which connectors are on; credentials stay on the server, referenced by id | Integrations |
| Device policy | heartbeat 60 s, offline staff grant 24 h (D04), printer profile 80 mm (D01) | configuration |
| Update policy | channel, auto-update, update window, pinned version | Release & Distribution |
| Locale | currency, tax regime reference, time zone, language | Global Configuration (PAGE-MST-021) |

**Not in the schema at all**, so nothing can switch them off: tenant isolation, authorization, audit, financial evidence, valid state transitions, idempotency (G7).
**Resolution:** platform default → region → plan → organization → location → role → user (G6). The published snapshot is resolved per organization and location; role and user layers are resolved on the device from maps inside the snapshot.

### 6.4 Lifecycle and signing
Draft (*Save Draft*) → validate (schema, entitlements, dependencies, every workflow path ends properly) → preview → review by a second person → publish (*Publish Live*): frozen, hashed and signed → assigned to the organization or branch → devices pick it up on their next heartbeat → **rollback = re-assign an earlier version**, instantly, with no reinstall.

- Every order records the configuration version it started under (G7).
- Snapshots and licences are signed with a Master key held in a key-management service, with key ids for rotation. The app carries the public keys, so editing the cached file on a POS laptop cannot unlock a module.
- A device keeps its last good snapshot and refuses one with a bad signature or an unsupported schema.

### 6.5 What the studios are, and are not
- Figma node `275:304` (App Builder: sections, theme, phone preview, *Save Draft* / *Publish Live*) is the UI/UX Studio for the customer-facing app.
- The **Visual Flow** screen is Workflow Studio plus the navigation editor, working with screens and node types that modules provide. Rules keep flows valid: for example, while Billing is on, Payment → Receipt cannot be removed.
- It is **not** a from-scratch app builder. Your documents never describe one, and building one would be a separate product.

---

## 7. Versioning: the "version control" in version-control OS

### 7.1 Five version numbers, and how they must fit together
| What | Example | Owner | Compatibility rule |
|---|---|---|---|
| App release | VINII POS 2.4.2, build 241 | engineering | declares the configuration-schema range, API contract, central migration and device database schema it needs |
| Module (feature version) | KOT 1.3 | Feature Store | declares the minimum app version |
| Configuration snapshot | Annapurna v17, schema 3 | Solutions / CS | Master refuses to assign a snapshot outside the app's schema range; the app keeps its last good one |
| API contract | v1 with additive changes | backend | the server supports the latest and previous minor app release; a breaking change needs a new version and a mandatory-update window |
| Databases | central migration id; device (Drift) schema number | OS repository; app | central: expand → migrate → contract, and the contract step waits until no device still needs the old shape. Device: forward-only migrations (D10) |

### 7.2 Numbering and channels
- Releases use semantic versions (2.4.2) plus an ever-increasing build number: Windows `2.4.2.241`, Android version code, iOS build number, `pubspec` `2.4.2+241`. "BLD-0241" on your screens is that build number.
- Each app in the monorepo gets its own tags (`vinii-pos@2.4.2`).
- Channels: internal → pilot → stable.
- Support policy: the latest and previous minor releases are supported; each release sets the minimum supported version.

### 7.3 Rules Master enforces
- No rollout may put a device on a combination that has not been declared compatible.
- An app can be rolled back only to a release with the same device database schema; otherwise the fix goes forward.
- A release reaches stable only after the pilot ring, unless it is a security release with two approvers.
- Deprecating a release sets a date; the minimum supported version moves on that date.

---

## 8. Build pipeline

### 8.1 Today
The POS repository's workflow runs format, analyze and tests on every push to `main`, then builds web and Windows. The Windows output is an unsigned `Release` folder: no installer, no version stamp (`0.1.0+1`). Settings are injected with `--dart-define`. GitHub keeps workflow artifacts only for a limited time (90 days by default), so they are a CI by-product, not a distribution store. The POS journal also notes that the Windows build has never been run on a real Windows machine.

### 8.2 Target
1. **Merge to `main`** → CI: format, analyze, unit and contract tests, central-migration dry run on a shadow database (as the notebook describes) → an internal-channel build.
2. **Create a release in Master** (version, notes, priority) → tag → the orchestrator queues one build job per platform.
3. **Runners:**
   - Windows: build, then an installer (MSIX or EXE, decided by the R4 spike), then sign.
   - Android: app bundle or APK, then sign.
   - iOS: macOS runner with Fastlane to App Store Connect / TestFlight.
   - Web: build, then deploy to a versioned path.
4. **Stamp only non-client values at build time** with `--dart-define`, the mechanism the POS already uses: version, build number, commit, channel, API address, update-feed address, configuration-signing public keys. No client data is ever built in, except the organization id in a white-label wrapper.
5. **Store artifacts** in private storage with SHA-256, signature, SBOM and build provenance. CI reports each step to Master through a signed webhook; that feeds the build-detail screen and its live log.
6. **Internal ring gets it automatically** → QA/UAT on real hardware (a Windows POS laptop with the 80 mm printer; D01, Q03) → a second person approves → published.

### 8.3 Signing
- **Windows:** sign every installer and executable. Code-signing keys must be held in a hardware security module under CA/Browser Forum rules in force since 2023, so CI calls a cloud signing service or cloud HSM; no key file ever sits on a laptop. SmartScreen trust builds over time for a consistent publisher, so expect warnings on the first installs.
- **Android:** one signing key per app identity (one per white-label wrapper), kept in the CI secret store or HSM; Google Play App Signing when distributed through Play.
- **iOS:** distribution certificate and profiles managed by Fastlane with App Store Connect API keys.
- The configuration and licence signing keys are separate from all code-signing keys.

### 8.4 Failures and logs
- Failures are classified: dependency, compile, test, signing, upload, infrastructure. Only infrastructure failures retry automatically, once.
- The build screen shows the first error line and the full log (your screen 9: *"missing dependency (package xyz)"*). *Retry Build* is a new attempt on the same commit.
- The pinned toolchain (`FLUTTER_VERSION` is already pinned) and committed lockfiles make failures reproducible.
- Queue priority: security > urgent > normal.

### 8.5 Packaging for one client takes seconds, not minutes
- **Default:** the universal installer, plus an enrollment QR or code on first run. No per-client file exists.
- **Optional:** a pre-provisioned bundle (the installer plus a provisioning file holding a single-use enrollment token) for clients who want setup with no typing.

---

## 9. Distribution and updates

| Platform | How a client gets it | How it updates | Notes |
|---|---|---|---|
| Windows POS (Phase 1) | signed installer through an expiring link or QR | downloads in the background, checks the signature, installs at shift close or in the update window | R4 spike: MSIX with App Installer vs an updater framework |
| Android | managed Google Play (private app) or a Play closed track for pilots | Play updates; in-app prompt below the minimum version | side-loaded APKs only for special cases |
| iOS | App Store, unlisted or as a Custom App through Apple Business Manager; TestFlight for pilots (builds expire after 90 days) | App Store updates; in-app prompt below the minimum version | each white-label iOS app is reviewed separately |
| Web | a per-client address serving a release, with configuration at runtime | new version on the next load; a client can be pinned to a release | rollback by re-pointing |

**Rules for an offline-first POS**
- Never install during an open shift or a sale in progress; wait for shift close or the update window.
- Unsynced records survive every update. The device database migrates forward on the next start, with interruption recovery (D10; PRD §7).
- **Mandatory update** (your screen 10): after the deadline the app will not start a new shift until updated. It never blocks syncing, reading or exporting existing records (PRD §11). Support can issue a one-time extension code.
- **Rollback:** configuration rollback is instant. App rollback re-publishes the earlier code under a new build number when the device database schema allows it; otherwise the fix goes forward.
- *"Full build / Incremental update"* on the New Build form becomes **App update (new version)** vs **Configuration update (no reinstall)**.
- Every offer, download, install and failure is logged. "Installed" is recorded only when the device's heartbeat reports the new version.

---

## 10. Devices, enrollment and licensing

### 10.1 Enrollment
1. Proviyaa staff (or the merchant owner, R12) create an enrollment code or QR for a branch: single use, valid 15 minutes.
2. On first run the device scans or types it, creates a key pair in the operating system's secure store (Windows TPM/DPAPI, Android Keystore, iOS Keychain) and registers its public key and hardware details.
3. Master checks the plan's device limit, then returns the device grant, configuration snapshot, licence and first sync scope (the PRD §10 "device bootstrap").
4. Staff sign in. The POS already has local-first staff sign-in with a 24-hour offline grant (POS journal, 15 Sep).
5. The system records its readiness checks: device online, printer test, test sale, KOT printed, sync healthy.

### 10.2 Heartbeat (every 60 seconds, D04)
- **Device sends:** app version and build, configuration version, device database schema, licence expiry, pending uploads, last sync, printer and scanner status, update state, recent errors.
- **Master replies:** a newer configuration version, a licence renewal, an update offer with any deadline, commands (collect logs, retire), server time.
- **Master stores** one current-state row per device plus hourly rollups, not a row per heartbeat. 1,000 devices is about 17 requests a second.
- The same signal tells One Latur whether a restaurant can take online orders (the 5-minute reachability rule, D04).

### 10.3 Licence
Signed and bound to the device key. It holds the organization, client app, modules, limits and a short expiry that every heartbeat renews, plus an offline grace period (R5). The grace is separate from the 24-hour staff grant.

### 10.4 Suspension and expiry (PRD §11)
- A suspension reaches an offline device only when it reconnects or its grant expires; remote shutdown of an offline device is impossible, and the plan does not pretend otherwise.
- On expiry: no new sales or shifts. Finishing open work and uploading evidence stay allowed. Nothing is deleted.
- Retiring a device revokes its credential, so a lost laptop cannot renew its licence.

---

## 11. Support loop: issue → fix → release → affected clients

1. **Intake.** The merchant raises an issue from the app's Help screen, which attaches device, version, configuration version, module and recent logs automatically, or support raises it. Repeated crash signatures can open issues on their own.
2. **Triage: configuration or code?** Your own example, TK-1042 (*"GST shows 5% instead of 18% on dine-in"*), is most likely a tax-rule configuration. It is fixed by publishing a configuration version to the affected clients in minutes, with no build.
3. **Code fix.** A branch named after the issue → patch release → pilot ring → the fix is linked to the issue → status moves to *Fix Ready* automatically.
4. **Deploy the fix** (your screen 7). Master pre-selects the affected clients (those below the fixed version that use the module); a person confirms; the rollout starts.
5. **Verify.** Heartbeats show the fixed version → *Resolved*; the client confirms → *Closed*.

The status workflow follows your screen 6. SLA timers per priority come from the documented SLA engine (PAGE-SUP-005).

---

## 12. API surface and events

Conventions carry over from the One Local plan (error envelope, `Idempotency-Key`, request ids, rate-limit classes, audit, outbox) and from Product Architecture §82 (every call carries request id, tenant id, user id and authorization context).

| Area | Routes (Master API) | Used by |
|---|---|---|
| Apps and templates | `GET/POST /apps` · `/templates` · `/templates/{id}/versions` | platform admin |
| Client apps | `POST /client-apps` · `GET/PATCH /client-apps/{id}` (channel, auto-update, window, pin) | CS / Solutions |
| Configuration | `POST /client-apps/{id}/config-drafts` · `PATCH /config-versions/{id}` · `POST /config-versions/{id}/validate`, `/preview`, `/submit`, `/approve`, `/publish` · `POST /client-apps/{id}/config/rollback` · `GET /config-versions/{id}/diff` | Solutions; approver |
| Requirements | `GET /organizations/{id}/requirements` (existing OS) · `POST /config-versions/{id}/sources` · `GET/POST /product-gaps` | CS; product |
| Releases and builds | `POST /releases` · `POST /releases/{id}/builds` · `GET /builds`, `/builds/{id}`, `/builds/{id}/logs` (streamed) · `POST /builds/{id}/retry`, `/cancel` · `POST /releases/{id}/approve`, `/publish`, `/deprecate` | engineering; approver |
| Distribution | `POST /artifacts/{id}/download-links` · `GET /distribution-events` | support |
| Rollouts | `POST /rollouts` · `POST /rollouts/{id}/start`, `/pause`, `/resume`, `/rollback` · `GET /rollouts/{id}/targets` | release manager |
| Devices (device credential) | `POST /devices/enroll` · `POST /devices/heartbeat` · `GET /devices/config` · `POST /devices/license/renew` · `GET /devices/updates` · `POST /devices/update-events` · `POST /devices/error-reports` | the device |
| Devices (staff) | `GET /devices` · `POST /devices/{id}/suspend`, `/retire` · `POST /locations/{id}/enrollment-codes` | support; merchant owner (R12) |
| Issues | `GET/POST/PATCH /issues` · `POST /issues/{id}/events`, `/fixes`, `/deploy-fix` | support |
| Dashboards | `GET /release/kpis`, `/release/version-adoption`, `/release/client-versions` | staff |
| Inbound | `POST /webhooks/ci` (signed) | CI |

**Events** (outbox, versioned, in your documents' naming style): `release.created`, `build.started`, `build.succeeded`, `build.failed`, `release.approved`, `release.published`, `release.deprecated`, `rollout.started`, `rollout.paused`, `rollout.completed`, `rollout.rolled_back`, `config.published`, `config.rolled_back`, `device.enrolled`, `device.version_changed`, `device.retired`, `license.issued`, `license.revoked`, `issue.created`, `issue.status_changed`, `issue.fix_linked`, `product_gap.created`.

**Rate limits:** heartbeat at most once per 30 s per device (bursts allowed after a reconnect) · enrollment 5 per minute per IP, codes single-use · download links expire and count their uses · build triggers 10 per hour per person · CI webhook accepted only with a valid signature.

---

## 13. Security and governance
- **Two-person approval** for: publishing a release to stable, publishing configuration to a live client, starting a mandatory rollout, and using production signing. (Master's dashboard already lists "approve configuration" as an action, PAGE-MST-001; the documented Approval Engine covers sensitive actions.)
- **Supply chain:** pinned toolchain and lockfiles, clean runners, an SBOM and build provenance for every artifact, secrets reaching the signing service through the CI secret store or short-lived credentials, no client data in any build.
- **Keys:** code signing in an HSM or cloud signing service; configuration and licence keys in a key-management service with rotation; device keys never leave the device.
- **Access:** row-level security on the release schema; merchants see only their own organization; impersonation only "with controlled audit" (PAGE-MST-003); devices can call device endpoints only.
- **Audit:** every create, approve, publish, deploy, rollback and retire is an append-only audit record (Product Architecture §80).
- **Distribution:** installers live in private storage; download links expire, are tied to one client and are logged.
- **Repositories:** the POS repository is public. Make it private, or keep every signing and deployment secret away from workflows that untrusted pull requests can trigger, before signing is added (R11).

---

## 14. Roadmap

| Phase | Goal | What it delivers (your screens) | Done when | Size |
|---|---|---|---|---|
| **P0** Reconcile and decide | Know what already exists | Answers to R1–R12; map of Master's live tables (from `Repo-1-` or a dump); 2-day spike on the Windows installer, updater and signing service | the §5.2 table is confirmed column by column; spike result recorded | S |
| **P1** Windows release control | A real version-control loop for the POS | Apps, releases, builds, signed artifacts; client apps with channel and auto-update; enrollment and heartbeat; shift-safe auto-update; rollouts including mandatory; Overview (2.1), Build detail (2.3), Client versions (2.4), Distribution logs (2.8), Mandatory update (2.10), Client Builds (screen 3) | a POS laptop updates itself outside business hours with nobody touching it; the dashboard shows it; unsynced records survive | L |
| **P2** Module control and configuration | "Custom build" = configuration | Templates for the three business types; signed configuration snapshots; entitlement-gated modules in the POS; requirement → configuration links; product-gap backlog; preview; approvals; configuration rollback; licences | the requirement "KOT + Billing, no Inventory" reaches the client's POS as exactly those modules within a minute, with no reinstall, and the POS can show why each one is on | L |
| **P3** Support loop | Issue → fix → deploy | Issues, timeline, attachments, affected clients, fix links, deploy-fix rollouts, SLA timers, crash reports, build-failure handling; screens 2.5, 2.6, 2.7, 2.9 | an issue goes Open → Fix Ready → deployed to the affected clients → Resolved, with heartbeat evidence | M |
| **P4** More platforms and white-label | Android, web, iOS; own-brand apps | Managed Play or closed track; per-client web address; iOS through the App Store; white-label wrapper builds; the Workflow Studio flow editor; UI/UX Studio for the customer app (Figma 275:304) | one white-label client live on two platforms from the shared release | L |
| **P5** Scale | Safer and self-serve | Percentage rings that halt automatically on error spikes; module usage analytics; merchant self-service upgrades; developer marketplace | — | M |

Sizes are relative (S < M < L), not calendar promises.

---

## 15. How we will know it works
- **Updater:** interrupted download, bad signature, full disk, power loss mid-install, failed first start rolls back to the previous version, update deferred during an open shift, unsynced records intact afterwards (D10 interruption tests).
- **Configuration:** schema validation; the server rejects calls to a switched-off module; a tampered snapshot is refused; hierarchy resolution; an open order keeps its version.
- **Compatibility:** each release is tested against the oldest supported configuration schema and the previous API minor version.
- **Rollouts:** target selection, deadline behaviour, pause, resume, rollback.
- **Isolation:** merchant A never sees merchant B's devices, builds or issues.
- **Load:** heartbeats from 10,000 devices (about 170 requests a second) with current-state writes.
- **Real hardware:** Phase 1 needs one reference Windows POS laptop with the 80 mm printer, because the Windows build has never run on a real machine.

---

## 16. Risks
| Risk | Mitigation |
|---|---|
| Sales pressure for one-off builds | The ladder in §3.3 and the product-gap backlog; per-client compiles only for paid white-label |
| The live database differs from the documents | Phase 0 mapping before any migration |
| iOS review and distribution rules | App Store routes only; allow for review time; Windows and Android first |
| Windows SmartScreen or antivirus warnings | Signed builds from one publisher; trust builds up; pilot clients first |
| Forced updates disrupting trade | Shift-safe installs; a deadline blocks only new shifts; extension codes |
| An expired licence stopping an offline POS | Grace period; expiry never blocks evidence upload |
| Two sources of truth for clients or modules | Foreign keys to Master's tables, never copies |
| CI artifacts expiring | Release artifacts kept in our own storage |
| Public repository plus signing secrets | R11 before signing is set up |
| Running costs (macOS runners, signing service, store accounts) | Budget agreed in Phase 0 |

---

## Appendix A — Screen traceability (Product Architecture §97), with proposed registry IDs
These are proposals for the registry that Product Flow Phase 0 requires. The notebook calls Release Management **PAGE-MST-028**; that id does not appear in the local copies of the documents, so confirm it.

| Screen | PAGE-ID (proposed) | Main APIs | Permission | Tables | Events |
|---|---|---|---|---|---|
| Overview dashboard (2.1, screen 3) | PAGE-MST-028 | API-REL-KPIS, API-REL-ADOPTION | PERM-RELEASE-VIEW | `app_releases`, `devices`, `client_apps` | — |
| New build / release (2.2) | PAGE-MST-028-A | API-REL-CREATE, API-BUILD-ENQUEUE | PERM-RELEASE-CREATE | `app_releases`, `build_jobs` | `release.created`, `build.started` |
| Build detail and logs (2.3), build failed (2.9) | PAGE-MST-028-B | API-BUILD-GET, API-BUILD-LOGS, API-BUILD-RETRY | PERM-BUILD-RUN | `build_jobs`, `build_steps`, `build_artifacts` | `build.succeeded`, `build.failed` |
| Client versions (2.4) | PAGE-MST-028-C | API-REL-CLIENT-VERSIONS, API-CLIENTAPP-UPDATE | PERM-CLIENTAPP-MANAGE | `client_apps`, `devices` | — |
| Issue tracker, ticket detail (2.5, 2.6) | PAGE-SUP-002, PAGE-SUP-003 | API-ISSUE-* | PERM-SUPPORT-TICKET | `issues`, `issue_events`, `issue_affected` | `issue.created`, `issue.status_changed` |
| Deploy fix (2.7) | PAGE-SUP-003-A | API-ISSUE-DEPLOY-FIX, API-ROLLOUT-START | PERM-ROLLOUT-START | `rollouts`, `rollout_targets`, `issue_fixes` | `issue.fix_linked`, `rollout.started` |
| Download and distribution logs (2.8) | PAGE-MST-028-D | API-DIST-EVENTS | PERM-RELEASE-VIEW | `distribution_events` | — |
| Mandatory update (2.10) | PAGE-MST-028-E | API-ROLLOUT-CREATE | PERM-ROLLOUT-MANDATORY (two approvers) | `rollouts`, `rollout_targets` | `rollout.started` |
| Create, configure, flow, preview (workflow 1–4) | PAGE-MST-028-F with PAGE-MST-022/023 | API-CLIENTAPP-CREATE, API-CONFIG-* | PERM-CONFIG-EDIT, PERM-CONFIG-PUBLISH | `client_apps`, `config_versions`, `config_item_sources` | `config.published` |
| Devices and updates (merchant) | PAGE-ORG-008 | API-DEVICE-LIST, API-ENROLL-CODE | PERM-DEVICE-MANAGE | `devices`, `enrollment_codes` | `device.enrolled` |

## Appendix B — Sources and confidence
- **Read directly (high):** viyaa routes §§5, 27, 29–40; Product Architecture §§7–10, 56 (support pages), 70–71, 74–75, 79–82, 97, 103, 109, and the platform capability list (approval engine, configuration versioning); Product Flow §§6–7; POS PRD §§7, 8, 10, 11; decision record D01–D10 and Q04; POS `build.yml`, `run_local.sh`, `pubspec.yaml`; POS journal (15 and 16 Sep); Figma context for node `275:304`; your three screen sets.
- **Founder notebook (medium — AI summaries of documents not stored locally, two questions on 2026-09-21):** requirement dispositions, the "Create organization" automation, the seven readiness checks, the stack (Turborepo/Melos, NestJS, Vercel, Railway/Fly, Fastlane), PAGE-MST-028, and the remark that `deal_events` and `readiness_checks` are not named in the documents.
- **Table names only (live database):** `modules`, `roles`, `org_users`, `customers`, `deal_events`, `readiness_checks`, `menu_categories`, `orders`, seen through publishable-key error hints on 2026-09-21; columns not inspected (Q04).
- **Not read:** the OS repository `Repo-1-` — the most important input for Phase 0.
- **Platform facts from general knowledge, to re-check in Phase 0:** Apple distribution routes (unlisted apps, Custom Apps through Apple Business Manager, TestFlight builds expiring after 90 days, the Enterprise programme being for employees only); the CA/Browser Forum hardware-key rule for code signing; managed Google Play private apps; GitHub's default artifact retention.

## Appendix C — Glossary
| Term | Meaning here |
|---|---|
| Client | an organization that bought Proviyaa; its branches are locations |
| Module | a Feature Store capability (POS, Billing, KOT, Inventory, CRM, Loyalty…) |
| Template | the preset for a business type (Restaurant, Store, Service) |
| Configuration snapshot | an immutable, signed, versioned set of a client's settings |
| Release | a numbered build of one app for all clients |
| Client package | a release paired with one client's configuration and licence |
| Rollout | the plan for delivering a release to clients, in rings, optionally with a deadline |
| Device | one installed app on one machine; reports itself by heartbeat |
| Licence | a signed, device-bound grant that lets the app run offline for a limited time |
| White-label | a client's own app name, icon and store listing around the shared code |
