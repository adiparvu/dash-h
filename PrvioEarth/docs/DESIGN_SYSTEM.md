# PRVIO EARTH — Liquid Glass Design System

> Deliverables 15–17: Apple Liquid Glass Design System, Screen-by-Screen UI
> Specification, Component Library.

---

## 15. Liquid Glass Design System

PRVIO EARTH uses a single material language — **iOS 27 Liquid Glass** — so the
entire app reads as one continuous Apple surface floating above the Digital
Twin. No Material Design. No flat cards. Everything is glass, depth and motion.

### Material tiers — `GlassDepth`
| Tier | Use | Blur | Highlight |
|------|-----|------|-----------|
| `.ambient` | background chrome, scrims | 12 | subtle |
| `.raised` | floating cards, pills | 24 | medium |
| `.floating` | nav bar, search, dock | 36 | strong |
| `.modal` | detail sheets, assistant | 50 | strongest |

Each tier scales corner radius, shadow depth and a moving **specular
highlight** that sweeps across the surface (`LiquidGlassBackground`).

### Signature traits (all implemented)
- **Dynamic reflections** — animated diagonal specular sweep, `.plusLighter`.
- **Adaptive blur** — `.ultraThinMaterial` + per-tier radius.
- **Dynamic depth** — tier-driven shadow + scale.
- **Frosted translucency** — domain-tinted wash over material.
- **Luminous adaptive border** — top-bright → bottom-faint stroke.
- **Contextual morphing** — `matchedGeometryEffect` nav pill, sheet morph.
- **Physics-based animation** — `prvioMorph`, `prvioFluid`, `prvioSnappy`
  springs used everywhere.

### Color — `Theme.swift`
- **Brand:** Mist, Deep, Horizon.
- **Domain accents:** each Smart module owns a hue (Forest green, Orchard
  amber, Pond teal, Water blue, Energy gold, Home violet, Security red…).
- **Health spectrum:** thriving → stable → stressed → critical, mapped from a
  0…1 score via `Double.healthColor`.

### Typography & spacing
Rounded SF throughout (`prvioTitle/headline/metric/label/caption`); a 4→36pt
spacing scale (`Spacing`).

---

## 16. Screen-by-Screen UI Specification

### A. Digital Twin (root) — `PropertyMapView`
- **80–90% map.** Live 2D/3D MapKit twin, satellite default, realistic
  elevation. The first and primary surface.
- **Floating top bar** (`.floating` glass): brand + current context; a "Clear"
  button appears when Intelligence has highlighted entities.
- **Entity markers** (`EntityMarker`): glass discs with live health halos that
  pulse; selected markers enlarge; non-focused markers dim when Intelligence
  highlights a subset.
- **Layer dock** (bottom, auto-hides while exploring): 2D/3D toggle + horizontal
  analytical-overlay picker (NDVI, Canopy, Soil, Thermal, Drone).
- **Interaction:** tap a marker → camera flies in → Liquid Glass detail sheet
  morphs up. Pan/zoom collapses all chrome out of the way (`isExploring`).

### B. Object Detail Sheet — `ObjectDetailSheet`
Custom-background `.sheet`, detents `.fraction(0.45)` & `.large`. Sections:
- **Header:** icon disc, name, status, `HealthRing`.
- **Live metrics:** kind-adaptive `MetricTile` grid (pond chemistry, tree
  biometrics, orchard yield, device status…).
- **PRVIO Insights:** related insights with severity icon + recommendation.
- **History:** Swift Charts area+line of health over 14 days.
- **Actions:** Inspect (Camera AI), Automate, Log.

### C. Module surfaces — `ModuleDashboardView` (Forest/Orchard/Pond/Home)
Floats over a *filtered* twin. Leads with an aggregate `HealthRing` summary
card, a horizontal insight strip, then an adaptive grid of entity chips. Tapping
a chip returns to the map and selects the entity — the dashboard always points
back to the spatial truth. No tables.

### D. PRVIO Intelligence — `IntelligenceView`
Conversational panel over the twin: message bubbles on glass, a horizontal
suggestion row (the canonical example prompts), and a glass composer. Replies
can highlight entities on the underlying map and propose automations.

### E. Floating Navigation — `FloatingNavBar`
The only persistent chrome. Six contexts (Twin, Forest, Orchard, Pond, Home,
PRVIO). Selected item expands into a tinted capsule with a `matchedGeometryEffect`
pill; collapses to icons while exploring the map.

---

## 17. Component Library — `DesignSystem/Components/`

| Component | Purpose |
|-----------|---------|
| `liquidGlass(_:tint:interactive:)` | the material modifier — base of everything |
| `GlassCard` | floating glass container |
| `GlassButton` | capsule glass button with press physics |
| `MetricTile` | live metric readout with trend arrow |
| `HealthRing` | Activity-style 0…1 health ring with numeric transition |
| `FloatingNavBar` | morphing module switcher |
| `EntityMarker` | tappable, pulsing, health-aware map annotation |
| `MessageBubble` | assistant conversation bubble |

All components consume only design tokens (`Theme`) and the `GlassDepth`
material, guaranteeing visual consistency across every screen and target.
