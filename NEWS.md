# taruwind 0.1.1

First CRAN release, published on 21 October 2026.

- Install the released package with `install.packages("taruwind")`.
- CRAN package DOI: <https://doi.org/10.32614/CRAN.package.taruwind>.
- Post-publication documentation refresh: update CRAN installation instructions,
  publication status, citation metadata and links in the GitHub README and
  getting-started guide. This documentation update does not change the
  numerical code or the already published CRAN archive.

- Declare all bundled PocketFFT contributors and copyright holders in
  Authors@R, with comments restricting their roles to that third-party code.
  Cem Özen remains the sole package author and maintainer.
- Update version metadata and the response provenance version string.
  No solver, surface-memory formula or numerical setting changed.

# taruwind 0.1.0

Earlier development and submission candidate; not a separate CRAN release.

- Review candidate fixes: factor-coordinate labels are parsed as coordinates;
  missing/blank site identifiers and unknown local time zones are rejected.
  No physical solver or numeric prediction formula changed.

- Six-mode neutral terrain response and exact-fetch surface memory.
- Explicit metric-grid preparation and reusable time-series prediction.
- Input validation and numerical regression tests.
- Current-core build/predict APIs, four-node prediction and portable batch work.
- Separate ERA5 and Copernicus DEM acquisition utilities; GLO-90 is default.
- Geographic preparation and ERA5-to-current-solver convenience workflow.
- Optional explicit WorldCover acquisition with documented roughness lookup.
- Reusable geographic responses, UTC/local timestamps and consistent site IDs.
- Bounded local-area wind rasters, aligned elevation and roughness layers, and
  a base-R map plotting helper.
- Fail-fast ERA5 time-axis checks before terrain work, request-size reporting,
  and enforced reflected-grid limits for multi-site workflows.
- Ten-calendar-year point-request and seven-day local-map limits, with reusable
  area responses for consecutive batches.
- Historical candidate checks: the base source snapshot passed Linux, Windows
  and macOS checks, followed by a local Linux check of the input-validation
  correction. Subsequent cross-platform checks and the first CRAN publication
  are recorded under version 0.1.1 above.
- Automatic latitude-based neutral depth and resumable CDS FSR reference
  acquisition, with an explicit diagnostic convention and provenance.

Earlier version numbers belonged to unreleased research prototypes. Their
source and experiment history remain in the research archive. This version
does not silently expose the older spectral/shallow-layer algorithm.
