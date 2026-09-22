#' Download four-node ERA5 wind support and interpolate it to target sites
#'
#' `taruwind_download_era5()` reads native hourly 10 m or 100 m wind components
#' from the official geo-chunked CDS ARCO store. For every target it retrieves
#' the four surrounding 0.25-degree nodes, performs bilinear interpolation on
#' the selected `u` and `v` components separately, and returns a tidy hourly
#' table. Downloaded Zarr metadata and chunks are cached and reused.
#'
#' The Climate Data Store is free to use, but its ARCO endpoint requires a CDS
#' API key. The function checks `api_key`, then `CDSAPIKEY` and `CDS_API_KEY`,
#' and finally the `key:` entry in `~/.cdsapirc`. The key is sent only in the
#' HTTPS authorization header and is never written to the cache or result.
#'
#' @param sites Optional data frame or matrix containing `lon` and `lat`
#'   columns. `longitude` and `latitude` are accepted aliases. An optional
#'   `site_id` column is retained.
#' @param lon,lat Numeric longitude and latitude vectors. Use these instead of
#'   `sites`; scalar values are allowed.
#' @param start,end Start and end of the requested period. Date-only values
#'   include the complete UTC day; date-times select exact inclusive hours.
#' @param period Optional two-element start/end vector. Supply this instead of
#'   separate `start` and `end` values.
#' @param wind_height ERA5 diagnostic wind height in metres. Supported values
#'   are `10` (default) and `100`. The function retrieves the native ERA5
#'   `u10`/`v10` or `u100`/`v100` fields; it never vertically extrapolates one
#'   height from the other.
#' @param api_key Optional CDS API key. Prefer `CDSAPIKEY` or `~/.cdsapirc` for
#'   interactive use so the secret does not appear in scripts.
#' @param cache_dir Directory used for the sparse local Zarr cache.
#' @param local_tz If `FALSE` (default), timestamps remain in UTC. If `TRUE`,
#'   the time zone is inferred independently for each coordinate with `lutz`
#'   and local ISO timestamps are added. A single Olson/IANA time-zone string
#'   can also be supplied explicitly.
#' @param include_nodes Include the four raw ERA5 node series in a `nodes`
#'   attribute on the returned tibble.
#' @param refresh Refresh mutable ARCO metadata and recent ERA5T chunks
#'   automatically once per day (`"auto"`), on every call (`"always"`), or
#'   never (`"never"`). Historical cached chunks are immutable and reused.
#' @param quiet Suppress download progress messages.
#' @param allow_large Bypass the safeguards reported by [taruwind_limits()].
#'   Use this deliberately and split large jobs into recoverable batches.
#' @return A `taruwind_era5` tibble with hourly vector-bilinear wind at every
#'   site. Provenance, interpolation nodes and cache files are stored as
#'   attributes.
#' @export
taruwind_download_era5 <- function(
    sites = NULL, lon = NULL, lat = NULL, start = NULL, end = NULL,
    period = NULL,
    api_key = NULL,
    cache_dir = file.path(file.path(tempdir(), "taruwind-cache"), "era5"),
    local_tz = FALSE, include_nodes = FALSE,
    refresh = c("auto", "always", "never"), quiet = FALSE,
    allow_large = FALSE, wind_height = 10L) {
  .taruwind_require("Rarr", "reading the CDS ARCO Zarr store")
  refresh <- match.arg(refresh)
  wind_height <- .taruwind_wind_height(wind_height)
  u_name <- paste0("u", wind_height)
  v_name <- paste0("v", wind_height)
  target <- .taruwind_sites(sites, lon, lat)
  period <- .taruwind_resolve_period(start, end, period)
  .taruwind_guard_request(target, period, allow_large = allow_large)
  key <- .taruwind_cds_key(api_key)
  store <- paste0(
    "https://arco.datastores.ecmwf.int/cadl-arco-geo-002/arco/",
    "reanalysis_era5_single_levels/sfc/geoChunked.zarr"
  )
  cache <- file.path(cache_dir, "cds_arco_sfc_geo")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)

  metadata_file <- file.path(cache, ".zmetadata")
  metadata_age <- if (file.exists(metadata_file)) {
    as.numeric(difftime(Sys.time(), file.info(metadata_file)$mtime, units = "hours"))
  } else Inf
  metadata_refresh <- refresh == "always" ||
    (refresh == "auto" && metadata_age >= 24)
  if (!file.exists(metadata_file) || metadata_refresh) {
    .taruwind_fetch(
      paste0(store, "/.zmetadata"), metadata_file, key, quiet,
      overwrite = file.exists(metadata_file)
    )
    # The last time-coordinate chunk grows as ERA5/ERA5T is extended.
    if (dir.exists(file.path(cache, "time"))) {
      unlink(list.files(file.path(cache, "time"), pattern = "^[0-9]+$", full.names = TRUE))
    }
  }
  metadata <- jsonlite::fromJSON(metadata_file, simplifyVector = FALSE)$metadata
  for (variable in c("time", "latitude", "longitude", u_name, v_name)) {
    .taruwind_materialize_zarr_metadata(cache, variable, metadata)
  }

  coordinates <- lapply(c("time", "latitude", "longitude"), function(variable) {
    info <- metadata[[paste0(variable, "/.zarray")]]
    chunk_count <- ceiling(unlist(info$shape) / unlist(info$chunks))
    for (chunk in seq_len(chunk_count[1]) - 1L) {
      .taruwind_fetch_chunk(store, cache, variable, as.character(chunk), key, quiet)
    }
    as.vector(Rarr::read_zarr_array(file.path(cache, variable)))
  })
  names(coordinates) <- c("time", "latitude", "longitude")
  timestamp <- as.POSIXct(as.numeric(coordinates$time), origin = "1970-01-01", tz = "UTC")
  time_index <- which(timestamp >= period$start & timestamp <= period$end)
  if (!length(time_index)) {
    stop("the requested period is outside the available CDS ARCO ERA5 record")
  }
  if (timestamp[time_index[1]] != period$start ||
      timestamp[time_index[length(time_index)]] != period$end) {
    stop("the requested start/end must coincide with available hourly ERA5 timestamps")
  }

  brackets <- lapply(seq_len(nrow(target)), function(index) {
    .taruwind_era5_bracket(
      target$lon[index], target$lat[index],
      coordinates$longitude, coordinates$latitude
    )
  })
  variable_arrays <- list()
  recent_request <- period$end >= max(timestamp) - 100 * 86400
  for (variable in c(u_name, v_name)) {
    info <- metadata[[paste0(variable, "/.zarray")]]
    chunks <- unlist(info$chunks)
    required <- unique(do.call(rbind, lapply(brackets, function(bracket) {
      expand.grid(
        floor((time_index - 1L) / chunks[1]),
        floor((bracket$lat_index - 1L) / chunks[2]),
        floor((bracket$lon_index - 1L) / chunks[3])
      )
    })))
    for (row in seq_len(nrow(required))) {
      chunk <- paste(required[row, ], collapse = ".")
      .taruwind_fetch_chunk(
        store, cache, variable, chunk, key, quiet,
        overwrite = metadata_refresh && recent_request
      )
    }
    variable_arrays[[variable]] <- lapply(brackets, function(bracket) {
      Rarr::read_zarr_array(
        file.path(cache, variable),
        index = list(time_index, bracket$lat_index, bracket$lon_index)
      )
    })
  }

  node_tables <- vector("list", nrow(target))
  site_tables <- vector("list", nrow(target))
  for (index in seq_len(nrow(target))) {
    bracket <- brackets[[index]]
    u <- variable_arrays[[u_name]][[index]]
    v <- variable_arrays[[v_name]][[index]]
    dim(u) <- c(length(time_index), 2L, 2L)
    dim(v) <- c(length(time_index), 2L, 2L)
    weights <- bracket$weights
    interpolated_u <- rowSums(matrix(u, nrow = length(time_index)) *
                                matrix(weights, nrow = length(time_index), ncol = 4L,
                                       byrow = TRUE))
    interpolated_v <- rowSums(matrix(v, nrow = length(time_index)) *
                                matrix(weights, nrow = length(time_index), ncol = 4L,
                                       byrow = TRUE))
    site_table <- data.frame(
      site_id = target$site_id[index], lon = target$lon[index], lat = target$lat[index],
      timestamp_utc = timestamp[time_index],
      wind_height_m = wind_height,
      u = interpolated_u, v = interpolated_v,
      wind_speed = sqrt(interpolated_u^2 + interpolated_v^2),
      stringsAsFactors = FALSE
    )
    site_table[[u_name]] <- interpolated_u
    site_table[[v_name]] <- interpolated_v
    site_tables[[index]] <- site_table
    if (include_nodes) {
      node_labels <- c("north_west", "south_west", "north_east", "south_east")
      node_grid <- expand.grid(
        timestamp_position = seq_along(time_index), node_position = seq_len(4L)
      )
      node_table <- data.frame(
        site_id = target$site_id[index],
        timestamp_utc = timestamp[time_index][node_grid$timestamp_position],
        wind_height_m = wind_height,
        node = node_labels[node_grid$node_position],
        node_lon = bracket$node_lon[node_grid$node_position],
        node_lat = bracket$node_lat[node_grid$node_position],
        weight = weights[node_grid$node_position],
        u = as.vector(matrix(u, nrow = length(time_index)))[
          node_grid$timestamp_position + (node_grid$node_position - 1L) * length(time_index)
        ],
        v = as.vector(matrix(v, nrow = length(time_index)))[
          node_grid$timestamp_position + (node_grid$node_position - 1L) * length(time_index)
        ], stringsAsFactors = FALSE
      )
      node_table[[u_name]] <- node_table$u
      node_table[[v_name]] <- node_table$v
      node_table$wind_speed <- with(node_table, sqrt(u^2 + v^2))
      node_tables[[index]] <- node_table
    }
  }
  result <- tibble::as_tibble(do.call(rbind, site_tables))
  result <- .taruwind_add_local_time(result, target, local_tz)
  class(result) <- c("taruwind_era5", class(result))
  attr(result, "sites") <- tibble::as_tibble(target)
  attr(result, "source") <- store
  attr(result, "license") <- "Copernicus C3S/CAMS License"
  attr(result, "citation") <- paste(
    "Hersbach et al. (2020), The ERA5 global reanalysis,",
    "Q.J.R. Meteorol. Soc., https://doi.org/10.1002/qj.3803"
  )
  attr(result, "retrieved_utc") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  attr(result, "wind_height_m") <- wind_height
  attr(result, "component_variables") <- c(u = u_name, v = v_name)
  attr(result, "interpolation") <- paste0(
    "bilinear on ", u_name, " and ", v_name,
    " over four surrounding ERA5 nodes"
  )
  attr(result, "cache_dir") <- normalizePath(cache, mustWork = TRUE)
  if (include_nodes) attr(result, "nodes") <- tibble::as_tibble(do.call(rbind, node_tables))
  result
}

.taruwind_resolve_period <- function(start = NULL, end = NULL, period = NULL) {
  if (!is.null(period)) {
    if (!is.null(start) || !is.null(end) || length(period) != 2L) {
      stop("period must contain exactly two values and cannot be combined with start/end")
    }
    start <- period[[1L]]
    end <- period[[2L]]
  }
  if (is.null(start) || is.null(end)) {
    stop("supply start/end or a two-element period")
  }
  .taruwind_period(start, end)
}

#' @export
print.taruwind_era5 <- function(x, ...) {
  sites <- if ("site_id" %in% names(x)) unique(x$site_id) else attr(x, "sites")$site_id
  cat("<taruwind_era5>", length(unique(sites)), "site(s),", nrow(x), "hourly rows\n")
  cat("  period:", format(min(x$timestamp_utc), tz = "UTC"), "to",
      format(max(x$timestamp_utc), tz = "UTC"), "UTC\n")
  height <- attr(x, "wind_height_m")
  if (is.null(height) && "wind_height_m" %in% names(x)) height <- unique(x$wind_height_m)[1]
  cat("  wind height:", height, "m\n")
  cat("  interpolation: vector bilinear from four ERA5 nodes\n")
  NextMethod("print")
}

.taruwind_wind_height <- function(wind_height) {
  if (!is.numeric(wind_height) || length(wind_height) != 1L ||
      is.na(wind_height) || !is.finite(wind_height) ||
      !wind_height %in% c(10, 100)) {
    stop("wind_height must be exactly 10 or 100 metres", call. = FALSE)
  }
  as.integer(wind_height)
}

.taruwind_sites <- function(sites = NULL, lon = NULL, lat = NULL) {
  if (!is.null(sites)) {
    if (!is.null(lon) || !is.null(lat)) stop("supply either sites or lon/lat, not both")
    sites <- as.data.frame(sites, stringsAsFactors = FALSE)
    lower <- tolower(names(sites))
    lon_name <- names(sites)[match(TRUE, lower %in% c("lon", "longitude"))]
    lat_name <- names(sites)[match(TRUE, lower %in% c("lat", "latitude"))]
    if (is.na(lon_name) || is.na(lat_name)) {
      stop("sites must contain lon/lat or longitude/latitude columns")
    }
    lon <- sites[[lon_name]]
    lat <- sites[[lat_name]]
    id_name <- names(sites)[match(TRUE, lower %in% c("site_id", "id", "name"))]
    site_id <- if (is.na(id_name)) NULL else as.character(sites[[id_name]])
  } else {
    if (is.null(lon) || is.null(lat)) stop("lon and lat must be supplied")
    site_id <- names(lon)
  }
  lon <- as.numeric(lon); lat <- as.numeric(lat)
  if (!length(lon) || length(lon) != length(lat) ||
      any(!is.finite(lon)) || any(!is.finite(lat)) ||
      any(lon < -180 | lon > 180) || any(lat < -90 | lat > 90)) {
    stop("lon and lat must be equal-length finite coordinates in valid ranges")
  }
  if (is.null(site_id) || length(site_id) != length(lon) || any(!nzchar(site_id))) {
    site_id <- paste0("site_", seq_along(lon))
  }
  if (anyDuplicated(site_id)) stop("site identifiers must be unique")
  data.frame(site_id = site_id, lon = lon, lat = lat, stringsAsFactors = FALSE)
}

.taruwind_period <- function(start, end) {
  date_only <- function(value) inherits(value, "Date") ||
    (is.character(value) && length(value) == 1L && grepl("^\\d{4}-\\d{2}-\\d{2}$", value))
  start_time <- as.POSIXct(start, tz = "UTC")
  end_time <- as.POSIXct(end, tz = "UTC")
  if (date_only(end)) end_time <- end_time + 23 * 3600
  if (length(start_time) != 1L || length(end_time) != 1L ||
      is.na(start_time) || is.na(end_time) || start_time > end_time) {
    stop("start and end must define a valid inclusive UTC period")
  }
  if (as.numeric(start_time) %% 3600 != 0 || as.numeric(end_time) %% 3600 != 0) {
    stop("start and end must be aligned to whole hours")
  }
  list(start = start_time, end = end_time)
}

.taruwind_cds_key <- function(api_key = NULL) {
  candidates <- c(api_key, Sys.getenv("CDSAPIKEY"), Sys.getenv("CDS_API_KEY"))
  candidates <- candidates[nzchar(candidates)]
  if (length(candidates)) return(candidates[1])
  config <- path.expand("~/.cdsapirc")
  if (file.exists(config)) {
    lines <- readLines(config, warn = FALSE)
    key <- sub("^key:[[:space:]]*", "", lines[grepl("^key:", lines)])
    if (length(key) && nzchar(key[1])) return(key[1])
  }
  stop(
    "a free CDS API key is required; set CDSAPIKEY or add key: to ~/.cdsapirc",
    call. = FALSE
  )
}

.taruwind_fetch <- function(url, destination, key, quiet, overwrite = FALSE) {
  if (file.exists(destination) && !overwrite) return(invisible(destination))
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(destination, ".part")
  handle <- curl::new_handle(failonerror = TRUE, connecttimeout = 30L)
  curl::handle_setheaders(handle, Authorization = paste("Bearer", key))
  tryCatch(
    curl::curl_download(url, temporary, quiet = quiet, handle = handle),
    error = function(error) {
      if (file.exists(temporary)) unlink(temporary)
      stop("CDS ARCO download failed: ", conditionMessage(error), call. = FALSE)
    }
  )
  if (file.exists(destination) && unlink(destination) != 0L) {
    unlink(temporary)
    stop("could not replace cached ERA5 file: ", destination)
  }
  if (!file.rename(temporary, destination)) {
    unlink(temporary)
    stop("could not finalize cached ERA5 file: ", destination)
  }
  invisible(destination)
}

.taruwind_materialize_zarr_metadata <- function(cache, variable, metadata) {
  directory <- file.path(cache, variable)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  for (suffix in c(".zarray", ".zattrs")) {
    key <- paste0(variable, "/", suffix)
    jsonlite::write_json(
      metadata[[key]], file.path(directory, suffix), auto_unbox = TRUE,
      pretty = TRUE, null = "null", digits = NA
    )
  }
}

.taruwind_fetch_chunk <- function(
    store, cache, variable, chunk, key, quiet, overwrite = FALSE) {
  destination <- file.path(cache, variable, chunk)
  if (!file.exists(destination) || overwrite) {
    .taruwind_fetch(
      paste(store, variable, chunk, sep = "/"), destination, key, quiet,
      overwrite = overwrite
    )
  }
  destination
}

.taruwind_era5_bracket <- function(lon, lat, longitude, latitude) {
  lon360 <- lon %% 360
  west <- floor(lon360 * 4 + 1e-10) / 4
  east <- (west + 0.25) %% 360
  south <- floor(lat * 4 + 1e-10) / 4
  north <- min(90, south + 0.25)
  if (south < -90 || north == south) stop("coordinates at a pole are not supported")
  lon_index <- match(c(west, east), round(longitude, 8))
  lat_index <- match(c(north, south), round(latitude, 8))
  if (anyNA(c(lon_index, lat_index))) stop("could not identify four ERA5 support nodes")
  east_delta <- (east - west) %% 360
  x_weight <- ((lon360 - west) %% 360) / east_delta
  y_weight <- (lat - south) / (north - south)
  list(
    lon_index = lon_index, lat_index = lat_index,
    node_lon = c(west, west, east, east),
    node_lat = c(north, south, north, south),
    weights = c(
      (1 - x_weight) * y_weight,
      (1 - x_weight) * (1 - y_weight),
      x_weight * y_weight,
      x_weight * (1 - y_weight)
    )
  )
}

.taruwind_add_local_time <- function(data, sites, local_tz) {
  if (identical(local_tz, FALSE)) return(data)
  if (identical(local_tz, TRUE)) {
    .taruwind_require("lutz", "coordinate-based local time-zone lookup")
    zones <- lutz::tz_lookup_coords(sites$lat, sites$lon, method = "fast", warn = FALSE)
  } else if (is.character(local_tz) && length(local_tz) == 1L && nzchar(local_tz)) {
    zones <- rep(local_tz, nrow(sites))
  } else {
    stop("local_tz must be FALSE, TRUE, or one Olson/IANA time-zone string")
  }
  zone_map <- stats::setNames(zones, sites$site_id)
  data$time_zone <- unname(zone_map[data$site_id])
  data$timestamp_local <- mapply(
    function(time, zone) format(time, tz = zone, format = "%Y-%m-%dT%H:%M:%S%z"),
    data$timestamp_utc, data$time_zone, USE.NAMES = FALSE
  )
  data
}

.taruwind_require <- function(package, purpose) {
  if (!requireNamespace(package, quietly = TRUE)) {
    installation <- if (identical(package, "Rarr")) {
      " Install it with BiocManager::install('Rarr')."
    } else {
      paste0(" Install it with install.packages('", package, "').")
    }
    stop("this operation requires the optional package '", package,
         "' for ", purpose, ".", installation, call. = FALSE)
  }
}
