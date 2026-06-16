# PRVIO EARTH — Roadmap, Monetization & Apple Design Award Plan

> Deliverables 18–20.

---

## 18. Roadmap — MVP → Enterprise

### Phase 0 — Foundation (this repo)
Liquid Glass design system, unified `PropertyEntity` model, Digital Twin / GIS /
AI engines, map-first root, object detail sheet, module surfaces, PRVIO
Intelligence, WidgetKit + Live Activity + visionOS scaffolds, simulated
telemetry. **Buildable, demoable, testable end-to-end.**

### Phase 1 — MVP (public beta)
- Real MapKit satellite/3D twin with onboarding property setup (drop pins,
  draw zones).
- SwiftData persistence + CloudKit sync.
- HomeKit/Matter ingestion for real devices (lights, cameras, energy).
- Manual entity creation (plant a tree, add a pond) with the detail sheet.
- On-device Apple Intelligence wired into PRVIO Intelligence (Q&A + highlight).

### Phase 2 — Smart Modules
- Pond chemistry sensors (MQTT/Thread) + Oxygen Guardian automations.
- Orchard yield tracking + harvest forecasting (Core ML timeseries).
- Forest inventory import (TreeScope-style) + carbon/biomass analytics.
- Node-RED-style visual automation editor.

### Phase 3 — Aerial & Vision
- Drone mapping pipeline (OpenDroneMap) → NDVI / orthomosaic / LiDAR overlays.
- Camera AI (Core ML): pest/disease, fish/animal/bird ID, intrusion.
- visionOS app: volumetric twin + on-site AR overlays.

### Phase 4 — Enterprise
- Multi-property + roles/teams (estates, farms, conservancies).
- Predictive maintenance SLAs, asset/inventory ledgers, audit logs.
- Open API + webhooks; third-party sensor marketplace.
- Carbon/biodiversity reporting exports for certification.

---

## 19. Monetization Strategy

| Tier | Price | For | Includes |
|------|-------|-----|----------|
| **PRVIO Free** | $0 | curious owners | 1 property, ≤50 entities, core twin, manual data, basic insights |
| **PRVIO Plus** | ~$12/mo | serious homeowners | unlimited entities, CloudKit sync, full Apple Intelligence, automations, widgets/Live Activities |
| **PRVIO Pro** | ~$39/mo | smallholdings/orchards | drone/NDVI pipeline, Camera AI, forecasting, visionOS, export |
| **PRVIO Enterprise** | custom | estates/farms/agencies | multi-property, teams, API/webhooks, SLAs, on-prem ingestion |

Additional: hardware **sensor kits** (pond probe, soil/canopy nodes) as a
first-party accessory line; **drone-mapping** as a metered add-on. All billing
via StoreKit 2 subscriptions; no ads, privacy-first (on-device AI is a selling
point, not a cost center).

---

## 20. Apple Design Award Implementation Plan

Target categories: **Innovation**, **Visuals & Graphics**, **Interaction**,
**Spatial Computing**.

**Innovation** — a genuinely new category: a consumer Digital Twin you manage
by touching a living map. On-device Apple Intelligence reasoning over a personal
spatial model.

**Visuals & Graphics** — the Liquid Glass system: dynamic specular reflections,
adaptive depth, contextual morphing, health-driven living markers, realistic 3D
terrain. Cohesive, restrained, unmistakably Apple.

**Interaction** — object-centric, menu-free. Spatial gestures, physics-based
morphing between map ↔ sheet ↔ module, chrome that gets out of the way while
exploring, a conversational layer that acts *on the map*.

**Inclusion** — full Dynamic Type (rounded SF scales), VoiceOver labels on every
marker/metric, Reduce Motion paths for all springs, high-contrast health colors
with non-color status (icons + text), localized number/units.

**Performance** — 120fps ProMotion target, on-device inference (no network
stalls), down-sampled telemetry, lazy map annotation rendering.

**Checklist to ship-quality**
- [ ] Reduce Motion + Reduce Transparency fallbacks for Liquid Glass.
- [ ] Full VoiceOver pass + rotor for map entities.
- [ ] Localized into 8+ languages.
- [ ] Haptics on selection / threshold crossings.
- [ ] StandBy, Lock Screen, Watch complications.
- [ ] visionOS shared-engine parity.
- [ ] 60→120fps profiling on device with 1,000+ entities.
