# TaruWind 0.1.0

## Start here

**[Step-by-step getting-started guide](inst/doc/getting-started.md)** —
installation check, first coordinate, downloads, interpreting results,
saving/reusing responses and troubleshooting.

The formatted guide is also installed locally:

```r
library(taruwind)
browseURL(system.file("doc", "getting-started.html", package = "taruwind"))
```

Start with **`taruwind_downscale()`** when you have coordinates and a period.
You do not need to call all exported functions in sequence.

| Task | Entry point |
|---|---|
| Coordinates + period, automatic data preparation | `taruwind_downscale()` |
| Previously prepared response + new period | `taruwind_downscale(responses = ...)` |
| Prepared response + your own wind components | `taruwind_predict()` |
| Georeferenced DEM and roughness rasters | `taruwind_prepare_site()` |
| Explicit metric-grid matrices | `taruwind_build()` |
| Independent metric-grid batches | `taruwind_build_many()` |
| Inputs only, without solving | `taruwind_download_era5()`, `taruwind_download_copernicus_dem()`, `taruwind_download_worldcover()` |
| Profile assumptions / resource policy | `taruwind_source_profile()`, `taruwind_neutral_depth()`, `taruwind_limits()`, `taruwind_workers()` |

`wind_speed` in the geographic output is **vector-bilinear ERA5**;
`taruwind_speed` is the final downscaled speed, both in m/s. The `u`/`v`
columns remain ERA5 input components, not downscaled output components.

**Recommended order:** offline flat-terrain check below → one-coordinate
integration example in the guide → inspect output → save responses → expand
to normal domain size, longer periods and multiple sites. An initial terrain
solve is distinct from the much cheaper application of a prepared response.

## Technical overview and examples

Local first-release candidate by Cem Özen (ozenc@itu.edu.tr).
Prepared in the private GitHub repository `cemoze/taruwind` for cross-platform
release checks. Not yet published on CRAN or as a public release.

The current neutral reduced-mode terrain solver and finite-fetch surface
memory are exposed through an explicit metric-grid interface. Older research
algorithms are not silently substituted by geographic convenience functions.

```r
library(taruwind)
dem <- matrix(0, 9, 11)
roughness <- matrix(0.03, 9, 11)
response <- taruwind_modal_prepare(
  dem, roughness, dx = 90, x0 = 0, y0 = 0, x = 450, y = 360,
  depth = 900, source_z0 = 0.03
)
taruwind_modal_predict(response, u = c(3, 0), v = c(4, 0))
# Speeds: 5 and 0 m/s on flat, homogeneous, matched-reference terrain.
```

Rows run south to north. Coordinates are projected metres; roughness values
are aerodynamic lengths in metres, not land-cover class codes. `source_z0`
is an explicit effective input, never inferred from target roughness. Wind
components must already be interpolated to the target in the grid frame.
Preparation uses one native thread. Observations are not used to fit responses.

`taruwind_build()` and `taruwind_predict()` use this same current core.
Prediction also accepts four-column source-node component matrices and four
interpolation weights. `taruwind_build_many()` supports portable PSOCK workers:
auto is half the logical cores, capped at 16 and the site count, with a padded-
cell memory guard. Each native solve remains single-threaded.

Separate ERA5 (10/100 m) and Copernicus DEM download utilities are included;
GLO-90 is the default. Network services and credentials remain provider-owned.
No download occurs when the package is loaded or during ordinary package tests.
`taruwind_prepare_site()` projects rasters to a target-centred metric grid;
`taruwind_downscale()` connects this current solver to ERA5 retrieval. DEM
acquisition is automatic unless a raster is supplied. Roughness may be a
georeferenced aerodynamic-length raster or explicitly `"worldcover"` to fetch
ESA WorldCover 2021 and apply the documented WindKit lookup. WorldCover is
not presented as a replacement for the study's CORINE-based inputs.

```r
# Internet/CDS credentials and monthly-means dataset terms acceptance required.
# The documented study reference profile is prepared automatically.
wind <- taruwind_downscale(
  lon = 29.02, lat = 41.02,
  period = c("2020-01-01", "2020-01-02"),
  roughness = "worldcover"
)
# Reuse response construction for another period:
later <- taruwind_downscale(
  lon = 29.02, lat = 41.02,
  period = c("2020-02-01", "2020-02-02"),
  responses = attr(wind, "responses")
)
```

`sites` also accepts a data frame or matrix with `lon`/`lat` columns and an
optional `site_id`. Output is a tibble; UTC is default, `local_tz = TRUE` adds
coordinate-specific local timestamps with `lutz`. Geographic downloads and
raster preparation are serial to avoid cache races; response construction
uses automatic portable workers with a memory guard. No national-map convenience API is
claimed. Missing raster coverage is an error, never silently filled.

Source roughness is never guessed from target land cover. If omitted, it is
obtained from the ERA5 FSR reference climatology (default 2021, all months/hours)
through the documented diagnostic adapter. At 10 m this adapter bounds FSR to
0.0002–0.03 m; it does not assert that actual ERA5 roughness is globally 0.03 m.
The neutral depth follows the study's latitude-dependent formula. Both can
still be explicitly overridden with `source_z0` and `depth`.
Near the equator, automatic depth is rejected; this convention is restricted
to absolute latitudes 5–85 degrees. Source-profile downloads can enter a CDS
queue: repeat the same call after timeout to resume the cached job, without
submitting it again. Install optional `ncdf4` for this operation.
Automatic CORINE acquisition is not included in this release. The
geographic workflow is a new input-grid convenience layer, not a byte-for-byte
reproduction of the archived study grids. The current solver itself is unchanged.

The `.github/workflows/R-CMD-check.yaml` workflow checks Linux, Windows and
macOS. All three completed with `Status: OK` in GitHub Actions run
35756209012 (22 September 2026). These checks cover package installation,
offline examples and tests, not live downloading on every platform.

The model is neutral and diagnostic; separation, thermal circulations and
canopy displacement are not explicitly resolved. The mapped source/target
profile convention must be chosen explicitly. Evaluation above 10 m is not
claimed by this interface; supported numeric heights extend up to 100 m.
