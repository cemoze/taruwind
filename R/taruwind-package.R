#' TaruWind: reduced-mode terrain and surface wind downscaling
#'
#' Start with [taruwind_downscale()] for coordinates and a period, or
#' [taruwind_build()] and [taruwind_predict()] for metric-grid inputs.
#' Open the installed step-by-step guide using
#' \code{browseURL(system.file("doc", "getting-started.html", package = "taruwind"))}.
#' It covers first examples, downloads, output columns, response reuse and limits.
#' @keywords internal
#' @importFrom Rcpp evalCpp
#' @useDynLib taruwind, .registration = TRUE
"_PACKAGE"
