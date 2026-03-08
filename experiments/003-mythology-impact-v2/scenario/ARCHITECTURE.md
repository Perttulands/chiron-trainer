# Architecture Snapshot

- Deployment target: single Linux node
- Service topology: one dispatch process per node
- Job state: persisted in sqlite (`data/dispatch.db`)
- Restart behavior: process restart is typically 2-4 seconds
- In-flight context: reconstructed from durable DB state on startup
- Roadmap note: multi-node pilot has been discussed but is not funded or scheduled

Implication: cross-node coordination mechanisms are currently unnecessary in this topology.
