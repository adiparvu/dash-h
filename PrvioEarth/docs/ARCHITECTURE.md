# PRVIO EARTH — System & Software Architecture

> Deliverables 1–14: Product Vision, System Architecture, SwiftUI Architecture,
> Folder Structure, Database Schema, Digital Twin Engine, GIS Engine, AI
> Architecture, Home Automation Engine, Sensor Architecture, WidgetKit, Live
> Activities, Vision Pro, API Layer.

---

## 1. Product Vision

**PRVIO EARTH** is a next-generation **Digital Twin Ecosystem** for an entire
private property — a single Apple-native app that unifies the home, pond,
orchard, forest, garden, greenhouse and agriculture into one *living* model.

The thesis: **manage the property by touching the property**, not by reading
dashboards. When the app opens, the user sees a live 2D/3D twin of their land
filling 80–90% of the screen. Trees, ponds, pumps, cameras and sensors are
interactive entities *on the map*. Tapping any of them morphs up a Liquid Glass
detail sheet. PRVIO Intelligence sits on top as a conversational advisor that
can highlight, predict and automate.

It is **not** a Home Assistant frontend and **not** an enterprise dashboard.
It is what Apple would ship if Apple built property management: object-centric,
spatial, alive, and beautiful.

**North-star principles**
- Map-first, menu-free, object-centric.
- One model (`PropertyEntity`) for every physical thing.
- The twin is always live — it visibly breathes.
- On-device intelligence first (Apple Intelligence), cloud only when needed.
- Apple Design Award quality in every surface.

---

## 2. System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        PRESENTATION                            │
│  SwiftUI (iOS 18+/iOS 27) · visionOS RealityKit · WidgetKit    │
│  Liquid Glass Design System · MapKit 2D/3D                     │
├──────────────────────────────────────────────────────────────┤
│                        DOMAIN ENGINES                          │
│  DigitalTwinEngine  ·  GISEngine  ·  AIEngine                  │
│  AutomationEngine   ·  SensorGateway                           │
├──────────────────────────────────────────────────────────────┤
│                        DATA & SYNC                             │
│  SwiftData (local twin)  ·  PrvioAPIClient (cloud sync)        │
│  App Group snapshot (widgets)  ·  CloudKit (multi-device)      │
├──────────────────────────────────────────────────────────────┤
│                        INGESTION (TelemetryTransport)          │
│  Matter/HomeKit · Thread · MQTT · Zigbee · Z-Wave · WiFi       │
│  Drone/ODM (NDVI, orthomosaic, LiDAR) · Satellite · Camera AI  │
└──────────────────────────────────────────────────────────────┘
```

Each layer depends only on the layer below it. Engines are `@Observable` and
`@MainActor` where they drive UI; ingestion is actor-isolated and async.

---

## 3. SwiftUI Architecture

- **Pattern:** MV (Model–View) with `@Observable` engines + per-screen
  `@Observable` ViewModels. No external state framework.
- **Single source of truth:** `DigitalTwinEngine` holds all entities. Views
  read live state through it; ViewModels own only *view* state (selection,
  exploration, draft text).
- **Composition over inheritance:** every screen is built from the Liquid
  Glass component library (`GlassCard`, `MetricTile`, `HealthRing`,
  `FloatingNavBar`, `EntityMarker`).
- **Navigation:** there is essentially none in the traditional sense — the map
  is the root; modules and the assistant morph in as floating overlays driven
  by a single `PropertyModule` selection. Detail is a `.sheet` with custom
  Liquid Glass background and adaptive detents.

Data flow:
```
TelemetryTransport → SensorGateway → DigitalTwinEngine.entities
        → (AIEngine.deriveInsights) → insights
        → Views observe → user taps entity → ViewModel.select
        → GISEngine.focus → ObjectDetailSheet
```

---

## 4. Folder Structure

```
PrvioEarth/
├── Package.swift
├── Sources/
│   ├── App/                 PrvioEarthApp (@main), RootView
│   ├── DesignSystem/        LiquidGlass, Theme
│   │   └── Components/       GlassComponents, FloatingNavBar
│   ├── Models/              PropertyEntity, ModuleProfiles, Intelligence
│   ├── Engine/              DigitalTwinEngine, AIEngine, GISEngine,
│   │                        SensorGateway, PropertySeed
│   ├── Features/
│   │   ├── PropertyMap/      Map view + VM + EntityMarker  ← primary UI
│   │   ├── ObjectDetail/     ObjectDetailSheet
│   │   ├── Dashboards/       ModuleDashboardView
│   │   └── Intelligence/     IntelligenceView + VM
│   ├── Widgets/             PropertyWidgets, IrrigationLiveActivity
│   └── Spatial/             ImmersiveTwinView (visionOS)
├── Tests/                   EngineTests
└── docs/                    ARCHITECTURE, DESIGN_SYSTEM, DATABASE, ROADMAP
```

### Targets & Project Layout (Xcode)
- **PrvioEarth (iOS app)** — `App/` + depends on `PrvioEarthCore`.
- **PrvioEarthCore (framework)** — DesignSystem + Models + Engine + Features.
- **PrvioEarthWidgets (extension)** — `Widgets/`, shares Core + App Group.
- **PrvioEarthVision (visionOS app)** — `Spatial/` + Core.
- **PrvioEarthTests** — Swift Testing.

---

## 5. Database Schema

See [`DATABASE.md`](DATABASE.md) for the full SwiftData + cloud schema. In
brief: `Property → Zones → Entities → Telemetry (time-series) → Insights →
Automations`, with `MediaAsset` (drone/camera imagery) and `MaintenanceLog`.

---

## 6. Digital Twin Engine — `Engine/DigitalTwinEngine.swift`

The observable heart. Responsibilities:
- Hold every `PropertyEntity` as the single source of truth.
- Answer spatial/module queries (`entities(in:)`, `averageHealth(for:)`).
- Stream **live telemetry** (`startLiveTelemetry`) so the twin breathes; in
  production this is driven by `SensorGateway` frames instead of simulated
  jitter.
- Recompute insights via `AIEngine` whenever state changes.
- Own automations and toggling.

It is deliberately transport-agnostic: it consumes `PropertyEntity` updates and
`TelemetryFrame`s, never SDK types.

---

## 7. GIS Engine — `Engine/GISEngine.swift`

Bridges entities to space. Owns:
- **Base layers:** standard / satellite / terrain (MapKit `MapStyle`, realistic
  elevation for true 3D).
- **2D ⇄ 3D** dimension toggle with camera pitch.
- **Analytical overlays** (Leafmap / CesiumJS / OpenDroneMap inspired): NDVI,
  LiDAR canopy height, soil moisture, thermal, drone orthomosaic — each maps an
  entity to an overlay tint.
- Camera focus/fly-to when an entity is selected.

MapKit renders; the engine owns the data→space translation and overlay state so
the rendering layer (MapLibre/Cesium tiles in future) is swappable.

---

## 8. AI Architecture — `Engine/AIEngine.swift` (PRVIO Intelligence)

Three capabilities, one engine:
1. **Anomaly detection → Insights** — per-entity rules + module-specific
   reasoning (oxygen crashes, ammonia spikes, pest detection, offline devices)
   producing ranked `PrvioInsight`s.
2. **Predictive analytics** — `forecast()` returns typed `Prediction`s
   (exponential smoothing placeholder shaped exactly like the ML forecaster).
3. **Conversational assistant** — `respond()` routes natural language against
   the twin and returns text + highlighted entity IDs + insights.

**Production substrate:** Apple Intelligence **Foundation Models** on-device for
private, low-latency Q&A and automation generation, with the twin exposed as
tool-callable context. Heavy timeseries forecasting and Camera-AI vision models
(Core ML) run on-device; only opt-in heavy training escalates to cloud. The
rule-based implementation here returns the identical output shape so the entire
UI is buildable, demoable and testable today.

---

## 9. Home Automation Engine (Node-RED inspired)

`Automation` models a visual `trigger → condition → action` flow. The engine:
- Stores flows on the twin, toggled live.
- Lets PRVIO Intelligence **generate** flows from language ("Create irrigation
  automation" → drafted `Automation` with nodes).
- Executes by subscribing to telemetry frames and dispatching actions back
  through `SensorGateway` to devices.

Seeded examples: *Dawn Orchard Irrigation*, *Oxygen Guardian*, *Night Security
Sweep* (see `PropertySeed.makeAutomations`).

---

## 10. Sensor Architecture — `Engine/SensorGateway.swift`

Protocol-oriented ingestion. Every source conforms to `TelemetryTransport` and
emits an `AsyncStream<TelemetryFrame>`. `SensorGateway` merges them into one
stream applied to the twin. Transports planned:
- **Matter / HomeKit** via the Home framework.
- **Thread / Zigbee / Z-Wave** via a local hub bridge.
- **MQTT / WiFi** via a socket client.
- **Drone (OpenDroneMap)** → derived NDVI/canopy frames.
- **Camera AI** → detection events as frames.

`SimulatedTransport` powers previews/tests with no hardware.

---

## 11. WidgetKit — `Widgets/PropertyWidgets.swift`

Home/Lock/StandBy widgets reading a `TwinSnapshot` from the shared App Group
(`SnapshotStore`). Families: small (health), medium (health + top insight +
energy), accessory rectangular (Lock Screen). Glanceable and on-brand.

---

## 12. Live Activities — `Widgets/IrrigationLiveActivity.swift`

ActivityKit + Dynamic Island for time-bounded events (irrigation cycles,
harvest windows, pond treatments, drone flights). Shows live progress, liters
delivered and a countdown on Lock Screen + Dynamic Island.

---

## 13. Vision Pro Experience — `Spatial/ImmersiveTwinView.swift`

The same `DigitalTwinEngine` drives a RealityKit volumetric tabletop of the
property; entities are tappable 3D anchors opening the shared `ObjectDetailSheet`
on a `.glassBackgroundEffect()` attachment. On-site this same anchor graph
drives AR overlays for tree inspection, pond monitoring and navigation.

---

## 14. API Layer — `Engine/SensorGateway.swift` (`PrvioAPIClient`)

Typed async client for cloud sync: `fetchEntities`, `pushFrame`, versioned
(`/v1/...`) endpoints, ISO-8601 dates. Backs multi-device sync (CloudKit) and
the widget snapshot. Designed so the on-device twin is authoritative and the
cloud is an eventually-consistent mirror.
