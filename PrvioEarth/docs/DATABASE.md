# PRVIO EARTH — Database Schema

> Deliverable 5. Local-first **SwiftData** model (authoritative on-device) with
> **CloudKit** sync and a typed REST mirror via `PrvioAPIClient`.

## Design

The on-device twin is authoritative; cloud is an eventually-consistent mirror
for multi-device + widgets. Telemetry is high-volume and time-series, so it is
stored separately from entity state and down-sampled on write.

## Entities (SwiftData)

```
Property
  id: UUID (PK)
  name, anchorLat, anchorLon, anchorAlt
  createdAt, updatedAt
  zones: [Zone]            (1—N)

Zone                        // Forest, Orchard, Pond, Garden, Home…
  id: UUID (PK)
  module: String            // PropertyModule
  name, boundaryGeoJSON
  property: Property         (N—1)
  entities: [Entity]         (1—N)

Entity                       // mirrors PropertyEntity
  id: UUID (PK)
  name, kind: String         // EntityKind
  lat, lon, alt
  healthScore, diseaseRisk, healthNote, lastAssessed
  detailJSON: Data           // encoded EntityDetail (tree/orchard/pond/device)
  zone: Zone                 (N—1)
  telemetry: [TelemetrySample]   (1—N, cascade delete)
  maintenance: [MaintenanceLog]  (1—N)
  media: [MediaAsset]            (1—N)

TelemetrySample              // time-series, indexed on (entityId, metric, ts)
  id: UUID (PK)
  entityId: UUID (FK, indexed)
  metric: String             // "pH", "oxygen", "height_m"…
  value: Double
  unit: String
  timestamp: Date (indexed)
  source: String             // matter|thread|mqtt|drone|camera|sim

Insight
  id: UUID (PK)
  title, detail, recommendation
  severity: Int              // PrvioInsight.Severity
  module: String
  relatedEntityIds: [UUID]
  createdAt, acknowledgedAt?

Automation                   // Node-RED inspired
  id: UUID (PK)
  name, module: String, isEnabled: Bool
  nodesJSON: Data            // [Automation.Node]

MaintenanceLog
  id: UUID (PK)
  entityId: UUID (FK)
  kind: String               // inspection|treatment|pruning|repair
  note, performedAt, performedBy

MediaAsset                   // drone orthomosaic, camera frames, LiDAR
  id: UUID (PK)
  entityId: UUID? (FK)
  type: String               // ndvi|orthomosaic|lidar|photo|thermal
  url, capturedAt, metadataJSON
```

## Relationships

```
Property 1─N Zone 1─N Entity 1─N TelemetrySample
                         Entity 1─N MaintenanceLog
                         Entity 1─N MediaAsset
Insight  N─N Entity (via relatedEntityIds)
Automation N─N Entity (via node config)
```

## Indexing & retention
- Composite index `(entityId, metric, timestamp)` on `TelemetrySample`.
- Raw telemetry retained 30 days at full resolution, then down-sampled to
  hourly/daily aggregates (`TelemetryRollup`) for long-horizon charts/forecasts.
- `Insight.acknowledgedAt` drives the alert badge counts in widgets.

## Sync
- **CloudKit** private database mirrors `Property/Zone/Entity/Insight/Automation`.
- **Telemetry** streams to the cloud via `PrvioAPIClient.pushFrame` and is *not*
  fully mirrored to CloudKit (volume) — the cloud time-series store serves
  cross-device history.
- **App Group** holds the lightweight `TwinSnapshot` for WidgetKit.
