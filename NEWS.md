# taruwind 0.1.0

First public-version candidate, not yet published.

- Six-mode neutral terrain response and exact-fetch surface memory.
- Explicit metric-grid preparation and reusable time-series prediction.
- Input validation and numerical regression tests.
- Current-core build/predict APIs, four-node prediction and portable batch work.
- Separate ERA5 and Copernicus DEM acquisition utilities; GLO-90 is default.
- Geographic preparation and ERA5-to-current-solver convenience workflow.
- Optional explicit WorldCover acquisition with documented roughness lookup.
- Reusable geographic responses, UTC/local timestamps and consistent site IDs.
- Linux/Windows/macOS CI template (remote execution pending publication).
- Automatic latitude-based neutral depth and resumable CDS FSR reference
  acquisition, with an explicit diagnostic convention and provenance.

Earlier version numbers belonged to unreleased research prototypes. Their
source and experiment history remain in the research archive. This version
does not silently expose the older spectral/shallow-layer algorithm.
