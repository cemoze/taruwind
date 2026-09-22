#' Automatic-workflow safety limits
#'
#' TaruWind's automatic download workflow is intended for point networks and
#' local terrain domains, not accidental continental raster production. These
#' conservative limits are checked before network or DEM work starts. Advanced
#' users of [taruwind_download_era5()] can explicitly opt out with
#' `allow_large = TRUE`. The main [taruwind_downscale()] workflow does not expose
#' this override; split larger requests into recoverable batches.
#'
#' @return A named list containing the default limits.
#' @export
taruwind_limits <- function() {
  list(
    supported_era5_wind_heights_m = c(10L, 100L),
    max_sites = 100L,
    max_site_hours = 1e7,
    max_cells_per_site = 2e6,
    max_total_terrain_cells = 6e7
  )
}

.taruwind_guard_request <- function(
    sites, period, resolution = NULL, domain_km = NULL,
    allow_large = FALSE) {
  if (!is.logical(allow_large) || length(allow_large) != 1L || is.na(allow_large)) {
    stop("allow_large must be TRUE or FALSE")
  }
  limits <- taruwind_limits()
  hours <- as.numeric(difftime(period$end, period$start, units = "hours")) + 1
  site_hours <- nrow(sites) * hours
  issues <- character()
  if (nrow(sites) > limits$max_sites) {
    issues <- c(issues, paste0(nrow(sites), " sites > ", limits$max_sites))
  }
  if (site_hours > limits$max_site_hours) {
    issues <- c(
      issues,
      paste0(format(site_hours, scientific = FALSE, trim = TRUE),
             " site-hours > ",
             format(limits$max_site_hours, scientific = FALSE, trim = TRUE))
    )
  }
  if (!is.null(resolution) && !is.null(domain_km)) {
    cells_per_site <- (domain_km * 1000 / resolution)^2
    total_cells <- nrow(sites) * cells_per_site
    if (cells_per_site > limits$max_cells_per_site) {
      issues <- c(
        issues,
        paste0(format(round(cells_per_site), big.mark = ",", scientific = FALSE),
               " estimated terrain cells/site > ",
               format(limits$max_cells_per_site, big.mark = ",", scientific = FALSE))
      )
    }
    if (total_cells > limits$max_total_terrain_cells) {
      issues <- c(
        issues,
        paste0(format(round(total_cells), big.mark = ",", scientific = FALSE),
               " estimated total terrain cells > ",
               format(limits$max_total_terrain_cells, big.mark = ",", scientific = FALSE))
      )
    }
  }
  if (!length(issues)) return(invisible(TRUE))
  message <- paste0(
    "request exceeds TaruWind automatic-workflow safety limits: ",
    paste(issues, collapse = "; "),
    ". Reduce/split the request or set allow_large = TRUE deliberately."
  )
  if (!allow_large) stop(message, call. = FALSE)
  warning(message, call. = FALSE)
  invisible(TRUE)
}
