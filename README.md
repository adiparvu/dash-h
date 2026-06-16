# 🌍 PRVIO EARTH

**A next-generation Digital Twin Ecosystem for a complete private property — an
Apple-native iOS 27 application.**

PRVIO EARTH unifies **Smart Home · Pond · Orchard · Forest · Garden · Greenhouse
· Agriculture** into a single *living* map. When the app opens you see a 2D/3D
Digital Twin of your land filling the screen. Every tree, pond, pump, camera and
sensor is an interactive entity you tap to inspect, predict and automate.
**PRVIO Intelligence** sits on top as a conversational property advisor.

> Not a Home Assistant frontend. Not an enterprise dashboard. This is what Apple
> would ship if Apple built property management: **map-first, object-centric,
> spatial, alive — Liquid Glass throughout.**

---

## Why it's different
- **80–90% map.** You manage the property by touching the property.
- **One model, every module.** `PropertyEntity` powers trees, fish, pumps,
  solar — the whole twin.
- **Live.** The twin breathes via streaming telemetry; markers pulse with health.
- **On-device intelligence.** PRVIO Intelligence reasons over your twin
  privately (Apple Intelligence), cloud only when needed.
- **Liquid Glass.** Dynamic reflections, adaptive blur, depth, contextual
  morphing, physics-based motion — Apple Design Award quality.

---

## Code map (`PrvioEarth/Sources/`)

| Area | Files | What |
|------|-------|------|
| **Design System** | `DesignSystem/LiquidGlass.swift`, `Theme.swift`, `Components/*` | The Liquid Glass material + component library |
| **Models** | `Models/PropertyEntity.swift`, `ModuleProfiles.swift`, `Intelligence.swift` | Unified twin model + module profiles + AI types |
| **Engines** | `Engine/DigitalTwinEngine.swift`, `AIEngine.swift`, `GISEngine.swift`, `SensorGateway.swift`, `PropertySeed.swift` | Twin, AI, GIS, ingestion/API, demo data |
| **Primary UI** | `Features/PropertyMap/*` | The live map, markers, view model |
| **Detail** | `Features/ObjectDetail/ObjectDetailSheet.swift` | Liquid Glass entity inspector |
| **Modules** | `Features/Dashboards/ModuleDashboardView.swift` | Spatial Forest/Orchard/Pond/Home surfaces |
| **Analytics** | `Features/Analytics/ModuleAnalyticsView.swift` + `Engine/ModuleAnalytics.swift` | Forest carbon/biomass/species + Orchard yield forecasting (Swift Charts) |
| **Onboarding** | `Features/Onboarding/OnboardingView.swift` | First-run twin-materializing flow |
| **Editor** | `Features/Editor/PropertyEditorView.swift` | Tap-the-map to place/remove entities and build your twin |
| **Systems** | `Features/Systems/SystemsHubView.swift` + `Engine/PropertyAnalytics.swift` | Energy/Weather/Water/Security computed over the twin |
| **Automation** | `Features/Automation/AutomationStudioView.swift` | Node-RED-style visual flow studio + AI flow generation |
| **Camera AI** | `Features/CameraAI/CameraAIView.swift` + `Engine/VisionEngine.swift` | Live detection feed (pest/disease/intrusion/wildlife) with bounding boxes |
| **Drone** | `Features/Drone/DroneModeView.swift` | OpenDroneMap pipeline → orthomosaic/NDVI/LiDAR overlays on the twin |
| **AI** | `Features/Intelligence/IntelligenceView.swift` | PRVIO Intelligence assistant |
| **App** | `App/PrvioEarthApp.swift`, `RootView.swift` | Entry point + orchestration |
| **Widgets** | `Widgets/PropertyWidgets.swift`, `IrrigationLiveActivity.swift` | WidgetKit + Live Activity |
| **Spatial** | `Spatial/ImmersiveTwinView.swift` | visionOS RealityKit twin |
| **Tests** | `Tests/EngineTests.swift` | Swift Testing for the engines |

---

## Documentation (all 20 deliverables)

| Doc | Deliverables |
|-----|--------------|
| [`docs/ARCHITECTURE.md`](PrvioEarth/docs/ARCHITECTURE.md) | 1–14: vision, system & SwiftUI architecture, folder structure, engines (Twin/GIS/AI/Automation/Sensor), WidgetKit, Live Activities, Vision Pro, API |
| [`docs/DESIGN_SYSTEM.md`](PrvioEarth/docs/DESIGN_SYSTEM.md) | 15–17: Liquid Glass design system, screen-by-screen UI spec, component library |
| [`docs/DATABASE.md`](PrvioEarth/docs/DATABASE.md) | 5: SwiftData + CloudKit schema |
| [`docs/ROADMAP.md`](PrvioEarth/docs/ROADMAP.md) | 18–20: roadmap, monetization, Apple Design Award plan |

---

## Build
The reusable core is a Swift package (`PrvioEarth/Package.swift`, iOS 18+ /
visionOS 2). The `@main` app, Widget Extension and visionOS app are Xcode
targets that depend on `PrvioEarthCore` — see *Targets & Project Layout* in
`docs/ARCHITECTURE.md`. The app runs on simulated telemetry out of the box (no
backend or hardware required).

---

## Design inspiration
Architecture & workflows drawn from Awesome Home Assistant, OpenFarm, FarmBot,
Awesome Agriculture, Leafmap, TreeScope, SeeTree, CesiumJS, MapLibre,
OpenDroneMap and Node-RED — reimagined as one Apple-native ecosystem.
