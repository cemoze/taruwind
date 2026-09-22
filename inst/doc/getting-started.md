---
title: "TaruWind 0.1.0 — Getting started"
lang: en
---

## Where should I start?

You do not need to learn every function. **Start with `taruwind_downscale()`
when you have coordinates and a period.** It combines data acquisition,
raster preparation and the current solver. No target observations are required.

Recommended order: **offline check → one coordinate → inspect results → save
the response → expand the domain, period and number of sites.**

## 1. Check your installation without downloading data

In RStudio, select **Session → Restart R** (`Ctrl+Shift+F10`), then run:

```r
library(taruwind)
packageVersion("taruwind")  # Expected: 0.1.0
find.package("taruwind")
?taruwind
```

Try a synthetic flat surface first:

```r
h = matrix(0, 5, 5)
op = taruwind_build(
  dem = h, roughness = h + 0.03, dx = 90,
  x0 = 0, y0 = 0, x = 180, y = 180,
  depth = 900, source_z0 = 0.03
)
taruwind_predict(op, u = c(3, 0), v = c(4, 0))
# Expected speed: approximately 5 and 0 m/s
```

This checks installation, not field accuracy. The values 900 and 0.03 are
synthetic inputs; do not copy them blindly into a real-site analysis.

## 2. Prepare for real data

| Input | What the package does | What you provide |
|---|---|---|
| Location and time | Selects the target and hours | Longitude/latitude in decimal degrees and a UTC period |
| ERA5 | Downloads wind from the four surrounding nodes | CDS account and API key |
| DEM | Downloads GLO-90 and projects it onto a metric grid | Optionally, your own DEM raster |
| Target roughness | Converts WorldCover classes to z₀ | `roughness = "worldcover"` or a prepared z₀ raster |
| Source profile | Retrieves reference FSR and applies the model convention | Optionally, explicit `source_z0` |
| Neutral depth | Calculates a latitude-dependent depth | Optionally, explicit `depth` |

DEM values represent **terrain elevation in metres**. Roughness values represent
**aerodynamic z₀ in metres**, not land-cover class identifiers.

### R dependencies

Check availability first; this command downloads nothing:

```r
needed = c("taruwind", "terra", "ncdf4", "Rarr", "lutz")
setNames(vapply(needed, requireNamespace, logical(1), quietly = TRUE), needed)
```

Install missing dependencies as needed:

```r
# Run only for packages that are missing:
install.packages(c("terra", "ncdf4", "lutz"))
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install("Rarr", ask = FALSE, update = FALSE)
```

`lutz` is needed only for automatic local time zones. TaruWind is not yet on
CRAN; use the locally installed package rather than `install.packages("taruwind")`.

### CDS access

Follow the [official CDS API setup instructions](https://cds.climate.copernicus.eu/how-to-api).
The package can read `~/.cdsapirc` or the `CDSAPIKEY` / `CDS_API_KEY` environment
variable. Accept the applicable terms for the ERA5 single-level and monthly-mean
datasets in your CDS account.

Existing credentials may already be sufficient. **Do not put your API key in
scripts, GitHub or chat messages.** DEM and WorldCover downloads do not require
a CDS key. The package does not require Python.

## 3. Your first coordinate: a three-hour smoke test

This example uses a terrain domain approximately 1 km wide. **The 990 m domain
is only an installation/integration check, not the normal study domain.**

By default, downloaded files are cached in the current R session's temporary
directory. The example below explicitly chooses a persistent user cache so
downloads and queued CDS requests can be reused after restarting R.

```r
cache = file.path(tools::R_user_dir("taruwind", "cache"), "first-example")
wind = taruwind_downscale(
  lon = 29.02, lat = 41.02,
  start = "2020-01-01 00:00:00",
  end   = "2020-01-01 02:00:00",
  roughness = "worldcover",
  domain_m = 990, resolution = 90, workers = 1,
  cache_dir = cache
)
wind[, c("timestamp_utc", "wind_speed", "taruwind_speed")]
```

The first call includes network access and potentially a CDS queue, so its
elapsed time is not just solver time. Requesting three hours does not necessarily
mean downloading a three-hour-sized file: provider chunks may be larger.

If you receive **“CDS source-profile job is still queued/running”**, repeat the
same call later with **the same cache directory**. The saved job identifier
allows the request to resume rather than submitting another job. Do not keep
clearing the cache and starting over.

For a normal site analysis, remove `domain_m = 990`: the default domain is
approximately **30 × 30 km**, with **90 m** metric cells. This requires more
computation; initial preparation at complex sites can take several minutes.
**Shortening the period does not shrink the terrain solve.** A 30 km domain
is not a universal guarantee of adequacy for every landscape.

## 4. Understand and plot the output

| Column | Meaning |
|---|---|
| `site_id`, `lon`, `lat` | Target identifier and coordinates |
| `timestamp_utc` | UTC timestamp |
| `wind_height_m` | Requested height: 10 or 100 m |
| `u`, `v` | ERA5 input components interpolated to the target using vector bilinear interpolation |
| `wind_speed` | ERA5 vector-bilinear speed, m/s |
| `taruwind_speed` | Final TaruWind speed estimate, m/s |

The `u10`/`v10` or `u100`/`v100` columns are also **input** components, not
downscaled output components. This version returns speed as its final product.

```r
wind$increment = wind$taruwind_speed - wind$wind_speed
plot(wind$timestamp_utc, wind$wind_speed, type = "l", col = "#0072B2",
     xlab = "UTC", ylab = "Wind speed (m/s)",
     ylim = range(c(wind$wind_speed, wind$taruwind_speed), finite = TRUE))
lines(wind$timestamp_utc, wind$taruwind_speed, col = "#D55E00")
legend("topright", c("ERA5 Bilinear", "TaruWind"),
       col = c("#0072B2", "#D55E00"), lty = 1, bty = "n")
```

A difference between models is not itself an accuracy gain. Independent
observations are needed to assess accuracy.

## 5. Save the response and reuse it

```r
responses = attr(wind, "responses")
saveRDS(responses, "taruwind-responses.rds")
saveRDS(wind, "taruwind-first-result.rds")
write.csv(as.data.frame(wind), "taruwind-first-result.csv", row.names = FALSE)

later = taruwind_downscale(
  lon = 29.02, lat = 41.02,
  period = c("2020-01-02", "2020-01-02"),
  responses = responses, cache_dir = cache
)
```

Identical start/end dates select all 24 hours of that UTC day; endpoints are
inclusive. This reused response still belongs to the **990 m test domain**.
Reusing it does not enlarge the domain. Build a new response for a normal 30 km
analysis.

In another session, use `responses = readRDS("taruwind-responses.rds")`.
CSV does not preserve model/provenance attributes; use RDS for that purpose.

Rebuild whenever you change the DEM, roughness, resolution, domain, coordinates,
height or source profile. Supplying new raster arguments alongside `responses`
does not update the saved response.

## 6. Multiple sites, local time and 100 m winds

After the single-site example works:

```r
sites = data.frame(site_id = c("site_a", "site_b"),
                    lon = c(29.02, 29.04), lat = c(41.02, 41.04))
network = taruwind_downscale(
  sites = sites, period = c("2020-01-01", "2020-01-01"),
  roughness = "worldcover", workers = "auto", local_tz = TRUE,
  cache_dir = cache
)
```

This example uses the default **30 km** domains. A matrix with named `lon` and
`lat` columns is also accepted. Keep `site_id` values unchanged when reusing
responses.

`local_tz = TRUE` adds `time_zone` and `timestamp_local` while retaining UTC.
**The requested period is still interpreted in UTC**, not local time.

For 100 m winds, make a new call with `wind_height = 100`. Native ERA5 u100/v100
are retrieved, rather than extrapolating from 10 m. Do not reuse a 10 m response
at 100 m. Numerical support does not imply observational validation at 100 m
in the accompanying study.

## 7. Use your own rasters or wind components

With georeferenced DEM and **aerodynamic z₀ in metres** rasters:

```r
# Replace these placeholder paths with actual files; this example is offline.
profile = taruwind_source_profile(
  lon = 29.02, lat = 41.02, fsr_file = "my-era5-fsr.nc"
)
op = taruwind_prepare_site(
  lon = 29.02, lat = 41.02,
  dem = "my-dem.tif", roughness = "my-aerodynamic-roughness.tif",
  depth = profile$depth, source_z0 = profile$source_z0
)
taruwind_predict(op, u = c(3, 4), v = c(1, 2))
```

These example u/v values represent components already interpolated to the
target. You can apply your own component series while retaining the same
geometric inputs. See `?taruwind_predict` for four-node matrices and weights.

Rasters must cover the complete local domain. Convert CORINE class codes using
an appropriate z₀ lookup before supplying them as roughness. Automatic CORINE
downloading is not provided. WorldCover inputs do not reproduce the study's
CORINE-based experiment exactly.

`taruwind_build()` is the advanced metric-matrix interface: x/y are in metres,
rows run south to north and columns west to east. Converting a terra raster
directly to a matrix may reverse the required row order. The geographic
interface handles this orientation.

## 8. Assumptions, runtime and limits

- The model is a neutral diagnostic approach. Turbulence, thermal circulations
  and canopy displacement are not explicitly resolved.
- GLO-90 is projected onto a metric 90 m grid. DEM resolution, 10/100 m wind
  height and 30 km domain width are separate quantities.
- WorldCover 2021 classes receive z₀ values from a documented lookup; these
  are not direct roughness measurements.
- The default source FSR reference year is 2021. It does not automatically
  follow the wind period; change it with `profile_year`. At 10 m, the effective
  source reference is bounded to 0.0002–0.03 m. This does not claim that actual
  ERA5 roughness is everywhere 0.03 m.
- Automatic neutral depth is not hourly boundary-layer height. The automatic
  profile path is restricted to absolute latitudes of 5–85 degrees.
- Auto workers use half the logical cores, with a minimum of 1 and maximum of
  16, further limited by the number of sites and memory guards. **Sixteen
  workers do not split one site's solve into sixteen parts.** Data preparation
  is sequential; independent numerical solves run in parallel.

```r
attr(wind, "responses")[[1]]$provenance
attr(wind, "forcing_provenance")
taruwind_limits()
taruwind_workers(n_sites = 10)
```

The automatic point workflow allows up to 100 sites and 10 million site-hours.
Reflected solves are limited to 2 million computational cells per site.
`allow_large` belongs to the separate ERA5 download helper, not the main
`taruwind_downscale()` function. Split larger requests into batches.

## 9. Troubleshooting

| Problem | First check |
|---|---|
| An older version loads | Restart R; inspect `find.package()` and `packageVersion()` |
| CDS key / 403 error | API configuration and acceptance of both datasets' terms |
| Queue timeout | Retry later with the same call and cache directory |
| Missing R package | Run the dependency check in Section 2 |
| Raster gaps / unknown class | Check complete domain coverage; missing ocean cells are not automatically set to zero |
| Response coordinate/height mismatch | Match the target, `site_id` and `wind_height` |
| Slow initial preparation | Check terrain complexity and domain size; separate download time |
| NA output | Check input u/v for missing values |

This version produces point wind-speed time series, not national atlases,
interactive maps, downscaled direction/u/v or CERRA downloads. Linux, Windows
and macOS package checks passed in GitHub Actions run 35756209012 on
22 September 2026. Live data integration was additionally checked on Linux;
the platform checks do not download environmental datasets.

```r
?taruwind_downscale
?taruwind_prepare_site
?taruwind_predict
help(package = "taruwind")
browseURL(system.file("doc", "getting-started.html", package = "taruwind"))
```

In short: **start with one site, understand the output, save the response,
then scale up.**
