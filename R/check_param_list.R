#' @title Check a parameter list
#' @description Check that the parameter list (or JSON parameter file)
#'  is in the correct format, and then specified values are coherent with
#'  parameters.
#' @param pm List of parameters or path of a JSON parameter file.
#' @param type Type of the output (see [print_message] for details).
#' @param check_paths Logical: if TRUE, the function checks required output
#'  paths to be provided; if FALSE (default) these checks are skipped.
#' @param correct Logical: if TRUE (default), the function corrects
#'  some incoherences (e.g. timewindow of length 1 is transformed in length 2)
#'  and returns the corrected list as output; if false, only checking is
#'  performed, and the output is NULL if no errors occur.
#' @return In case of errors, depending on `type` argument, output can be
#'  a vector of errors (if `type = "string"`),
#'  the first error occurred (if `type = "error"`)
#'  or a set of warnings (if `type = "warning"`).
#'  If no errors occur, output is the corrected parameter list if
#'  `correct = TRUE` or NULL otherwise.
#'  
#' @importFrom jsonlite fromJSON
#' @importFrom methods is
#' @importFrom sf st_is_valid st_make_valid
#' @author Luigi Ranghetti, phD (2019)
#' @references L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
#'  "sen2r": An R toolbox for automatically downloading and preprocessing 
#'  Sentinel-2 satellite data. _Computers & Geosciences_, 139, 104473. 
#'  \doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
#' @note License: GPL 3.0
#' @keywords internal


check_param_list <- function(pm, type = "string", check_paths = FALSE, correct = TRUE) {
  
  # to avoid NOTE on check
  . <- valid_s2tiles <- reference_path <- NULL
  
  # check the output type
  
  # check the format of pm object
  if (is(pm, "character")) {
    if (file.exists(pm)) {
      # load json parameter file
      pm <- jsonlite::fromJSON(pm)
    } else {
      print_message(
        type = "error",
        "The file ",pm," does not exist."
      )
    }
  } else if (!is(pm, "list")) {
    print_message(
      type = "error",
      "\"",deparse(substitute(pm)),"\"",
      "must be a list or a path of a JSON parameter file."
    )
  }
  
  
  ## == Checks to be run first ==
  
  # -- Add NA on empty product lists --
  if (length(nn(pm$list_prods)) == 0) {pm$list_prods <- NA}
  if (length(nn(pm$list_rgb)) == 0) {pm$list_rgb <- NA}
  if (length(nn(pm$list_indices)) == 0) {pm$list_indices <- NA}
  
  
  ## == Recurrent check ==
  
  # -- Missing parameters: if a parameter is missing, set it to the default --
  pm_def <- formals(sen2r::sen2r) # default parameter values
  pm_def <- sapply(pm_def[!names(pm_def) %in% c("param_list","gui","use_python","tmpdir","rmtmp")], eval)
  for (sel_par in names(pm_def)) {
    if (length(nn(pm[[sel_par]])) == 0) {
      print_message(
        type = if (type == "error") {"warning"} else {type},
        paste0("Parameter \"",sel_par,"\" was not specified; ",
               "setting it to the default ('",pm_def[[sel_par]],"').")
      )
      pm[[sel_par]] <- pm_def[[sel_par]]
    }
  }
  
  # -- Preprocessing-specific parameters: set to defaults if preprocess == FALSE
  pm_forpreproc <- c(
    "list_prods", "list_rgb", "lsit_indices", "index_source", "rgb_ranges",
    "mask_type", "max_mask", "mask_smooth", "mask_buffer", "clip_on_extent", 
    "extent_as_mask", "reference_path", "res", "res_s2", "unit", "proj",
    "resampling", "resampling_scl", "outformat", "rgb_outformat", "index_datatype",
    "compression", "rgb_compression", "overwrite", "path_tiles", "path_merged",
    "path_out", "path_rgb", "path_indices", "path_subdirs", "thumbnails"
  )
  if (is(pm$preprocess, "logical") && pm$preprocess[1] == FALSE) {
    pm[pm_forpreproc] <- pm_def[pm_forpreproc]
  }
  
  
  # -- Parameters of length 1: check length
  pm_length1 <- c(
    "preprocess", "online", "order_lta", "downloader", 
    "overwrite_safe", "rm_safe", "step_atmcorr", "sen2cor_use_dem", 
    "max_cloud_safe", "timeperiod", "extent_name", "index_source",
    "mask_type", "max_mask", "mask_smooth", "mask_buffer", "clip_on_extent",
    "extent_as_mask", "reference_path", "res_s2", "unit", "proj", "resampling",
    "resampling_scl", "outformat", "rgb_outformat", "index_datatype",
    "compression", "rgb_compression", "overwrite", "path_l1c", "path_l2a",
    "path_tiles", "path_merged", "path_out", "path_rgb", "path_indices",
    "path_subdirs", "thumbnails", "parallel", "processing_order"
  )
  for (sel_par in pm_length1) {
    if (length(nn(pm[[sel_par]])) > 1) {
      print_message(
        type = type,
        paste0("Parameter \"",sel_par,"\" must be of length 1; ",
               "only the first element ('",pm[[sel_par]][1],"') is used.")
      )
      pm[[sel_par]] <- pm[[sel_par]][1]
    }
  }
  
  # -- Logical parameters: check them to be TRUE or FALSE
  pm_logical <- c(
    "preprocess", "online", "overwrite_safe", "clip_on_extent",
    "extent_as_mask", "path_subdirs", "thumbnails", "overwrite"
  )
  for (sel_par in pm_logical) {
    if (any(!is(pm[[sel_par]], "logical"), !pm[[sel_par]] %in% c(TRUE,FALSE))) {
      print_message(
        type = type,
        paste0("Parameter \"",sel_par,"\" must be TRUE or FALSE; ",
               "setting it to the default (",pm_def[[sel_par]],").")
      )
      pm[[sel_par]] <- pm_def[[sel_par]]
    }
  }
  
  
  ## == Specific checks on parameters ==
  
  
  # -- preprocess --
  
  
  # -- sel_sensor --
  if (all(!pm$sel_sensor %in% c("s2a", "s2b"))) {
    print_message(
      type = type,
      "Parameter \"sel_sensor\" must be 's2a', 's2b' or both (setting to the default)."
    )
    pm$sel_sensor <- pm_def$sel_sensor
  }
  
  
  # -- online --
  
  
  # -- server --
  if ("scihub" %in% pm$server) {
    print_message(
      type = type,
      "Parameter \"server\" = 'scihub' is deprecated; currently, only 'gcloud' ",
      "can be used (setting to the default)."
    )
    pm$server <- pm_def$server
  }
  if (all(!pm$server %in% c("scihub", "gcloud"))) {
    print_message(
      type = type,
      "Parameter \"server\" must be 'scihub', 'gcloud' or both (setting to the default)."
    )
    pm$server <- pm_def$server
  }
  
  
  # -- order_lta --
  
  
  # -- downloader --
  if (!pm$downloader %in% c("builtin", "aria2")) {
    print_message(
      type = type,
      "Parameter \"downloader\" must be 'builtin' or 'aria2' (setting to the default)."
    )
    pm$downloader <- pm_def$downloader
  }
  
  
  # -- overwrite_safe --
  
  
  # -- rm_safe --
  if (pm$rm_safe == TRUE) {
    pm$rm_safe <- "yes"
  } else if (pm$rm_safe == FALSE) {
    pm$rm_safe <- "no"
  } else if (!pm$rm_safe %in% c("yes", "all", "no", "l1c")) {
    print_message(
      type = type,
      "Parameter \"rm_safe\" must be one among 'yes' (or 'all'), ",
      "'no' and 'l1c' (setting to the default)."
    )
    pm$rm_safe <- pm_def$rm_safe
  }
  
  
  # -- max_cloud_safe --
  if (!is(pm$max_cloud_safe, "numeric")) {
    if (is.na(suppressWarnings(as.numeric(as.character(pm$max_cloud_safe))))) {
      print_message(
        type = type,
        "Parameter \"max_cloud_safe\" must be numeric (setting it to the default)."
      )
      pm$max_cloud_safe <- pm_def$max_cloud_safe
    } else {
      pm$max_cloud_safe <- as.numeric(as.character(pm$max_cloud_safe))
    }
  }
  if (pm$max_cloud_safe < 0) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Minimum allowed cloud cover value is 0; ",
      "setting parameter \"max_cloud_safe\" to 0."
    )
    pm$max_cloud_safe <- 0
  } else if (pm$max_cloud_safe > 100) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Maximum allowed cloud cover value is 100; ",
      "setting parameter \"max_cloud_safe\" to 100."
    )
    pm$max_cloud_safe <- 0
  }
  
  
  # -- timewindow --
  if (!anyNA(pm$timewindow)) {
    if (length(pm$timewindow)==1) {
      if (is(pm$timewindow, "numeric") | is(pm$timewindow, "difftime")) {
        pm$timewindow <- c(Sys.Date() - pm$timewindow, Sys.Date())
      } else {
        pm$timewindow <- rep(pm$timewindow, 2)
      }
    } else if (length(pm$timewindow)>2) {
      print_message(
        type = type,
        "Parameter 'timewindow' must be of length 1 or 2."
      )
    }
    if (is(pm$timewindow, "character")) {
      tryCatch(pm$timewindow <- as.Date(pm$timewindow), error = print)
    } else if (is(pm$timewindow, "POSIXt")) {
      pm$timewindow <- as.Date(pm$timewindow)
    }
    if (!is(pm$timewindow, "Date")) {
      print_message(
        type = type,
        "Parameter 'timewindow' must be a Date object."
      )
    }
  } else if (pm$online == TRUE) {
    # in online mode, NA value is converted to last 90 days
    pm$timewindow <- c(Sys.Date() - 90, Sys.Date())
  }
  
  
  # -- timeperiod --
  if (!pm$timeperiod %in% c("full", "seasonal")) {
    print_message(
      type = type,
      "Parameter \"timeperiod\" must be one among 'full' and 'seasonal' (setting to the default)."
    )
    pm$timeperiod <- pm_def$timeperiod
  }
  
  
  # -- extent --
  # convert to sf
  if (inherits(pm$extent, "character") | inherits(pm$extent, "geojson")) {
    tryCatch(
      pm$extent <- st_read(pm$extent, quiet=TRUE),
      error = function(e) {
        print_message(
          type = type,
          "Extent can not be read from the specified file or string."
        )
      }
    )
  } else if (inherits(pm$extent, "Spatial")) {
    pm$extent <- st_as_sf(pm$extent)
  }
  # check validity
  if (inherits(pm$extent, c("sfc", "sf"))) {
    if (any(!st_is_valid(pm$extent))) {
      pm$extent <- st_make_valid(pm$extent)
    }
  }
  
  
  # -- s2tiles_selected --
  pm$s2tiles_selected <- toupper(pm$s2tiles_selected)
  invalid_s2tiles <- pm$s2tiles_selected[
    !is.na(pm$s2tiles_selected) &
      !grepl("^[0-9]{2}[A-Z]{3}$", pm$s2tiles_selected)
    ]
  if (length(nn(invalid_s2tiles)) > 0) {
    print_message(
      type = type,
      "Values '",
      paste(invalid_s2tiles, collapse = "', '"),
      "' are not valid tiles ID and will be removed."
    )
    valid_s2orbits <- pm$s2tiles_selected[!pm$s2tiles_selected %in% invalid_s2orbits]
    pm$s2tiles_selected <- if (length(nn(valid_s2tiles)) == 0) {NA} else {valid_s2tiles}
  }
  if (all(
    pm$online,
    all(is.na(pm$extent)) || length(nn(pm$extent))==0,
    all(is.na(pm$s2tiles_selected)) || length(nn(pm$s2tiles_selected))==0
  )) {
    print_message(
      type = type,
      "In online mode, at least one parameter among 'extent' and ",
      "'s2tiles_selected' must be provided."
    )
  }
  
  
  # -- s2orbits_selected --
  if (is(pm$s2orbits_selected, "numeric")) {
    pm$s2orbits_selected <- str_pad2(pm$s2orbits_selected, 3, "left", "0")
  }
  invalid_s2orbits <- pm$s2orbits_selected[
    !is.na(pm$s2orbits_selected) &
      (is.na(suppressWarnings(as.numeric(pm$s2orbits_selected))) |
         as.numeric(pm$s2orbits_selected) < 0 |
         as.numeric(pm$s2orbits_selected) > 143)
    ]
  if (length(nn(invalid_s2orbits)) > 0) {
    print_message(
      type = type,
      "Values '",
      paste(invalid_s2orbits, collapse = "', '"),
      "' are not valid orbit ID and will be removed."
    )
    valid_s2orbits <- pm$s2orbits_selected[!pm$s2orbits_selected %in% invalid_s2orbits]
    pm$s2orbits_selected <- if (length(nn(valid_s2orbits)) == 0) {NA} else {valid_s2orbits}
  }
  
  
  # -- list_prods --
  invalid_prods <- pm$list_prods[
    !is.na(pm$list_prods) &
      !pm$list_prods %in% c("BOA","TOA","SCL","TCI","WVP","AOT","CLD","SNW","SZA","OZA","SAA","OAA")
    ]
  if (length(nn(invalid_prods)) > 0) {
    print_message(
      type = type,
      "Values '",
      paste(invalid_prods, collapse = "', '"),
      "' are not valid products and will be removed."
    )
  }
  pm$list_prods <- pm$list_prods[!is.na(pm$list_prods) & !pm$list_prods %in% invalid_prods]
  if (length(nn(pm$list_prods)) == 0) {pm$list_prods <- NA}
  
  
  # -- list_indices --
  invalid_indices <- pm$list_indices[!is.na(pm$list_indices) & !pm$list_indices %in% list_indices(all=TRUE)$name]
  if (length(nn(invalid_indices)) > 0) {
    print_message(
      type = type,
      "Values '",
      paste(invalid_indices, collapse = "', '"),
      "' are not valid index names and will be removed."
    )
  }
  pm$list_indices <- pm$list_indices[!is.na(pm$list_indices) & !pm$list_indices %in% invalid_indices]
  if (length(nn(pm$list_indices)) == 0) {pm$list_indices <- NA}
  
  
  # -- list_rgb --
  # check bands numbers for required RGB
  # (TOA:1-12; BOA: 1-9,11-12)
  invalid_rgb <- pm$list_rgb[!is.na(pm$list_rgb) & !grepl("^RGB[0-9a-f]{3}[BT]$", pm$list_rgb)]
  if (length(nn(invalid_rgb)) > 0) {
    print_message(
      type = type,
      "Values '",
      paste(invalid_rgb, collapse = "', '"),
      "' are not valid RGB names and will be removed."
    )
  }
  pm$list_rgb <- pm$list_rgb[!is.na(pm$list_rgb) & !pm$list_rgb %in% invalid_rgb]
  if (length(nn(pm$list_rgb))>0) {
    rgb_bands <- lapply(
      strsplit(gsub("^RGB([0-9a-f]{3})([BT])$","\\1",pm$list_rgb),""),
      function(x) {strtoi(paste0("0x",x))}
    )
    rgb_sources <- gsub("^RGB([0-9a-f]{3})([BT])$","\\2OA",pm$list_rgb)
    rgb_list <- foreach(i = seq_along(pm$list_rgb), .combine=c) %do% {
      if (any(
        rgb_bands[[i]]<1 |
        rgb_bands[[i]]>12 |
        rgb_bands[[i]]==10 & rgb_sources[i]=="BOA"
      )) {
        print_message(
          type = type,
          "RGB ",pm$list_rgb[i]," can not be computed (bands out of range)."
        )
        character(0)
      } else {
        pm$list_rgb[i]
      }
    }
    pm$list_rgb <- rgb_list
  } else {pm$list_rgb <- NA}
  
  
  # -- rgb_ranges --
  if (all(is.array(pm$rgb_ranges), length(dim(pm$rgb_ranges)) > 2)) {
    pm$rgb_ranges <- split(pm$rgb_ranges, nrow(pm$rgb_ranges))
  }
  if (is.matrix(pm$rgb_ranges)) {
    pm$rgb_ranges <- list(pm$rgb_ranges)
  }
  if (all(is.na(pm$list_rgb), length(nn(pm$rgb_ranges))==0)) { # for compatibility
    pm$rgb_ranges <- NA
  }
  if (!all(is.na(pm$rgb_ranges)) & length(pm$rgb_ranges) != length(pm$list_rgb)) {
    print_message(
      type = type,
      "\"rgb_ranges\" and \"list_rgb\" must be of the same length."
    )
    pm$rgb_ranges <- pm$list_rgb <- NA
  }
  
  
  # -- index_source --
  if (!pm$index_source %in% c("BOA", "TOA")) {
    print_message(
      type = type,
      "Parameter \"index_source\" must be one among 'BOA' and 'TOA' (setting to the default)."
    )
    pm$index_source <- pm_def$index_source
  }
  
  
  # -- mask_type --
  if (!pm$mask_type %in% c(NA, "nodata", "cloud_high_proba", "cloud_medium_proba",
                           "cloud_low_proba", "cloud_and_shadow", "clear_sky", "land") &
      !grepl("^scl_[\\_0-9]+$", pm$mask_type)
  ) {
    print_message(
      type = type,
      "Parameter \"mask_type\" is not accepted (setting to the default)."
    )
    pm$mask_type <- pm_def$mask_type
  }
  # check consistency among mask_type and selected products
  # (if masking is selected but no prods or indices are selected, set to NA)
  if (
    !is.na(pm$mask_type) &
    all(is.na(nn(pm$list_indices))) &
    all(is.na(nn(pm$list_prods[pm$list_prods!="SCL"])))
  ) {
    pm$mask_type <- NA
    pm$max_mask <- 100
  }
  
  
  # -- max_mask --
  if (!is(pm$max_mask, "numeric")) {
    if (is.na(suppressWarnings(as.numeric(as.character(pm$max_mask))))) {
      print_message(
        type = type,
        "Parameter \"max_mask\" must be numeric (setting it to the default)."
      )
      pm$max_mask <- pm_def$max_mask
    } else {
      pm$max_mask <- as.numeric(as.character(pm$max_mask))
    }
  }
  if (pm$max_mask < 0) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Minimum allowed cloud cover value is 0; ",
      "setting parameter \"max_mask\" to 0."
    )
    pm$max_mask <- 0
  } else if (pm$max_mask > 100) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Maximum allowed cloud cover value is 100; ",
      "setting parameter \"max_mask\" to 100."
    )
    pm$max_mask <- 0
  }
  if (all(pm$max_mask < 100, is.na(pm$mask_type))) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "\"max_mask\" was set to ",pm$max_mask,", but no masks were defined: ",
      "set argument \"mask_type\" properly in order to use a cloud mask."
    )
  }
  
  
  # -- mask_smooth --
  if (!is(pm$mask_smooth, "numeric")) {
    if (is.na(suppressWarnings(as.numeric(as.character(pm$mask_smooth))))) {
      print_message(
        type = type,
        "Parameter \"mask_smooth\" must be numeric (setting it to the default)."
      )
      pm$mask_smooth <- pm_def$mask_smooth
    } else {
      pm$mask_smooth <- as.numeric(as.character(pm$mask_smooth))
    }
  }
  if (pm$mask_smooth < 0) {
    print_message(
      type = type,
      "Parameter \"mask_smooth\" must be positive (setting it to the default)."
    )
    pm$mask_smooth <- pm_def$mask_smooth
  }
  
  
  # -- mask_buffer --
  if (!is(pm$mask_buffer, "numeric")) {
    if (is.na(suppressWarnings(as.numeric(as.character(pm$mask_buffer))))) {
      print_message(
        type = type,
        "Parameter \"mask_buffer\" must be numeric (setting it to the default)."
      )
      pm$mask_buffer <- pm_def$mask_buffer
    } else {
      pm$mask_buffer <- as.numeric(as.character(pm$mask_buffer))
    }
  }
  
  
  # -- clip_on_extent --
  
  
  # -- extent_as_mask --
  
  
  # -- extent_name --
  if (is.na(pm$extent_name) || length(nn(pm$extent_name))==0 || pm$extent_name=="") {
    print_message(
      type = type,
      "The extent name (parameter \"extent_name\" ) can not be empty."
    )
  }
  if (grepl("[ \\.\\_]", pm$extent_name)) {
    print_message(
      type = type,
      "The extent name (parameter \"extent_name\" ) can not contain ",
      "spaces, points nor underscores."
    )
  }
  if (grepl("^[0-9]{2}[A-Z]{3}$", pm$extent_name)) {
    print_message(
      type = type,
      "The extent name (parameter \"extent_name\" ) can not cannot be ",
      "a five-length string with the same structure of a tile ID",
      "(two numeric and three uppercase character values)."
    )
  }
  
  
  # -- reference_path --
  if (all(!is.na(pm$reference_path), pm$reference_path != "")) {
    if(!file.exists(pm$reference_path)) {
      print_message(
        type = type,
        "File \"",pm$reference_path,"\" does not exist ",
        "(replacing parameter \"",reference_path,"\" with default value)."
      )
      pm$reference_path <- pm_def$reference_path
    }
  }
  
  
  # -- res --
  if (all(!is.na(pm$res), !is(pm$res, "numeric"))) {
    if (anyNA(suppressWarnings(as.numeric(as.character(pm$res))))) {
      print_message(
        type = type,
        "Parameter \"res\" must be numeric (setting it to the default)."
      )
      pm$res <- pm_def$res
    } else {
      pm$res <- as.numeric(as.character(pm$res))
    }
  }
  if (!anyNA(pm$res) & any(pm$res <= 0)) {
    print_message(
      type = type,
      "Output custom resolution (parameter \"res\" ) must be positive."
    )
  }
  if (length(pm$res) == 1) {
    pm$res <- rep(pm$res, 2)
  }
  
  
  # -- res_s2 --
  if ((!anyNA(pm$res) & !is.null(pm$res)) & (!anyNA(pm$res_s2) & !is.null(pm$res_s2))) {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Both native and custom resolution were provided; ",
      "only custom one (\"res\") will be used."
    )
    pm$res_s2 <- NA
  }
  if (!anyNA(pm$res_s2) & any(!pm$res_s2 %in% c("10m", "20m", "60m"))) {
    print_message(
      type = type,
      "Output native resolution (parameter \"res_s2\" ) is invalid ",
      "(accepted values are '10m', '20m' and '60m'); setting it to default."
    )
    if (!any(!pm$res_s2 %in% c("10m","20m","60m"))) {
      pm$res_s2 <- pm_def$res_s2
    }
  }
  if (any(!pm$res_s2 %in% c("10m","20m","60m"))) {
    pm$res_s2 <- if (as.integer(mean(pm$res)) >= 60) {"60m"} else if (as.integer(mean(pm$res)) >= 20) {"20m"} else {"10m"}
  }
  
  
  # -- unit --
  if (pm$unit != "Meter") {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Only \"unit\" == 'meter' is accepted."
    )
    pm$unit <- "Meter"
  }
  
  
  # -- proj --
  if (inherits(try(st_crs2(pm$proj), silent = TRUE), "try-error")) {
    print_message(
      type = type,
      "Output projection (parameter \"proj\" ) is not recognised; ",
      "setting it to default."
    )
    pm$proj <- pm_def$proj
  }
  
  
  # -- resampling --
  if (!pm$resampling %in% c("near", "mode", "bilinear", "cubic",
                            "cubicspline", "lanczos", "average", "mode")) {
    print_message(
      type = type,
      "Parameter \"resampling\" is not accepted (setting to the default)."
    )
    pm$resampling <- pm_def$resampling
  }
  
  
  # -- resampling_scl --
  if (!pm$resampling_scl %in% c("near", "mode")) {
    print_message(
      type = type,
      "Parameter \"resampling_scl\" is not accepted (setting to the default)."
    )
    pm$resampling_scl <- pm_def$resampling_scl
  }
  
  
  # -- outformat --
  gdal_formats <- fromJSON(
    system.file("extdata/settings/gdal_formats.json",package="sen2r")
  )$drivers
  if (!pm$outformat %in% c(gdal_formats$name, "BigTIFF")) {
    print_message(
      type = type,
      "Parameter \"outformat\" is not accepted (setting to the default)."
    )
    pm$outformat <- pm_def$outformat
  }
  
  
  # -- rgb_outformat --
  if (anyNA(pm$rgb_outformat)) {pm$rgb_outformat <- pm$outformat}
  if (!pm$rgb_outformat %in% gdal_formats$name) {
    print_message(
      type = type,
      "Parameter \"rgb_outformat\" is not accepted (setting to the default)."
    )
    pm$rgb_outformat <- pm_def$rgb_outformat
  }
  
  
  # -- index_datatype --
  if (!pm$index_datatype %in% c("Byte", "UInt16", "Int16", "UInt32", "Int32", "Float32", "Float64")) {
    print_message(
      type = type,
      "Parameter \"index_datatype\" is not accepted (setting to the default)."
    )
    pm$index_datatype <- pm_def$index_datatype
  }
  
  
  # -- compression --
  if (!as.character(pm$compression) %in% c(NA, "NONE", "LZW", "DEFLATE", "PACKBITS", "JPEG", 1:100)) {
    print_message(
      type = type,
      "Parameter \"compression\" is not accepted (setting to the default)."
    )
    pm$compression <- pm_def$compression
  }
  
  
  # -- rgb_compression --
  if (anyNA(pm$rgb_compression)) {pm$rgb_compression <- pm$compression}
  if (!as.character(pm$rgb_compression) %in% c(NA, "NONE", "LZW", "DEFLATE", "PACKBITS", "JPEG", 1:100)) {
    print_message(
      type = type,
      "Parameter \"rgb_compression\" is not accepted (setting to the default)."
    )
    pm$rgb_compression <- pm_def$rgb_compression
  }
  
  
  # -- overwrite --
  
  
  # -- s2_levels --
  # (moved here because it needs other checked parameters)
  l1c_prods <- c("TOA")
  l2a_prods <- c("BOA","SCL","TCI")
  # Automatically compute s2_levels if processing is TRUE (retrieve from products)
  if (pm$preprocess==TRUE) {
    # List required products (exmplicitly or implicitly)
    # 1. if masking is required, produce also SCL
    list_prods <- if (!is.na(pm$mask_type)) {
      unique(c(pm$list_prods, "SCL"))
    } else {
      pm$list_prods
    }
    # 2. if some RGB are required, compute also TOA or BOA
    if (any(!is.na(pm$list_rgb))) {
      list_prods <- unique(c(
        list_prods,
        paste0(unique(substr(pm$list_rgb,7,7)),"OA")
      ))
    }
    # 3. if some indices are required, compute also TOA or BOA
    if (any(!is.na(pm$list_indices))) {
      list_prods <- unique(c(list_prods, pm$index_source))
    }
    list_prods <- list_prods[!is.na(list_prods)]
    pm$s2_levels <- if (length(list_prods) > 0) {
      c(
        if (any(list_prods %in% l1c_prods)) {"l1c"},
        if (any(list_prods %in% l2a_prods)) {"l2a"}
      )
    } else {
      pm_def$s2_levels
    }
  }
  if (all(!pm$s2_levels %in% c("l1c", "l2a"))) {
    print_message(
      type = type,
      "Parameter \"s2_levels\" must be 'l1c', 'l2a' or both (setting to the default)."
    )
    pm$s2_levels <- pm_def$s2_levels
  }
  
  
  # -- step_atmcorr --
  if (pm$step_atmcorr == "no") {
    print_message(
      type = if (type == "error") {"warning"} else {type},
      "Value \"no\" for parameter \"step_atmcorr\" is deprecated ",
      "(\"l2a\" will be used)."
    )
    pm$step_atmcorr <- "l2a"
  } else if (!pm$step_atmcorr %in% c("auto", "scihub", "l2a")) {
    print_message(
      type = type,
      "Parameter \"step_atmcorr\" must be one among 'auto', 'scihub' and 'l2a' ",
      "(setting to the default)."
    )
    pm$step_atmcorr <- pm_def$step_atmcorr
  }
  
  
  # -- sen2cor_use_dem --
  if (!is(pm$sen2cor_use_dem, "logical")) {
    print_message(
      type = type,
      paste0("Parameter sen2cor_use_dem must be TRUE or FALSE; ",
             "setting it to the default (NA).")
    )
    pm$sen2cor_use_dem <- NA
  }
  
  
  # -- sen2cor_gipp
  
  
  # -- path_l1c --
  if (all(!is.na(pm$path_l1c), pm$path_l1c != "")) {
    if(!dir.exists(pm$path_l1c)) {
      if(!dir.exists(dirname(pm$path_l1c))) {
        print_message(
          type = type,
          "Directory \"",dirname(pm$path_l1c),"\" does not exist ",
          "(it must be created before continuing)."
        )
      }
    }
  } else if (all("l1c" %in% pm$s2_levels, check_paths)) {
    print_message(
      type = type,
      "Parameter \"path_l1c\" was not specified; ",
      "please provide the path of an existing directory."
    )
  }
  
  
  # -- path_l2a --
  if (all(!is.na(pm$path_l2a), pm$path_l2a != "")) {
    if(!dir.exists(pm$path_l2a)) {
      if(!dir.exists(dirname(pm$path_l2a))) {
        print_message(
          type = type,
          "Directory \"",dirname(pm$path_l2a),"\" does not exist ",
          "(it must be created before continuing)."
        )
      }
    }
  } else if (all("l2a" %in% pm$s2_levels, check_paths)) {
    print_message(
      type = type,
      "Parameter \"path_l2a\" was not specified; ",
      "please provide the path of an existing directory."
    )
  }
  
  
  # -- path_tiles --
  if (all(!is.na(pm$path_tiles), pm$path_tiles != "", pm$preprocess == TRUE)) {
    if(!dir.exists(pm$path_tiles)) {
      if(!dir.exists(dirname(pm$path_tiles))) {
        print_message(
          type = type,
          "Directory \"",dirname(pm$path_tiles),"\" does not exist ",
          "(it must be created before continuing)."
        )
      }
    }
  }
  
  
  # -- path_merged --
  if (all(!is.na(pm$path_merged), pm$path_merged != "", pm$preprocess == TRUE)) {
    if(!dir.exists(pm$path_merged)) {
      if(!dir.exists(dirname(pm$path_merged))) {
        print_message(
          type = type,
          "Directory \"",dirname(pm$path_merged),"\" does not exist ",
          "(it must be created before continuing)."
        )
      }
    }
  }
  
  # -- path_rgb --
  if (pm$preprocess == TRUE) {
    if (sum(!is.na(pm$list_rgb))==0) {
      pm$path_rgb <- NA
    } else if (is.na(pm$path_rgb) | pm$path_rgb=="") {
      pm$path_rgb <- pm$path_out
    }
    if (all(!is.na(pm$path_rgb), pm$path_rgb != "")) {
      if(!dir.exists(pm$path_rgb)) {
        if(!dir.exists(dirname(pm$path_rgb))) {
          print_message(
            type = type,
            "Directory \"",dirname(pm$path_rgb),"\" does not exist ",
            "(it must be created before continuing)."
          )
        }
      }
    } else if (all(length(nn(pm$list_rgb[!is.na(pm$list_rgb)])) > 0, check_paths)) {
      print_message(
        type = type,
        "Neither parameter \"path_rgb\" nor \"path_out\" were specified; ",
        "please provide the path of an existing directory for at least one of the two."
      )
    }
  }
  
  
  # -- path_indices --
  if (pm$preprocess == TRUE) {
    if (sum(!is.na(pm$list_indices))==0) {
      pm$path_indices <- NA
    } else if (is.na(pm$path_indices) | pm$path_indices=="") {
      pm$path_indices <- pm$path_out
    }
    if (all(!is.na(pm$path_indices), pm$path_indices != "")) {
      if(!dir.exists(pm$path_indices)) {
        if(!dir.exists(dirname(pm$path_indices))) {
          print_message(
            type = type,
            "Directory \"",dirname(pm$path_indices),"\" does not exist ",
            "(it must be created before continuing)."
          )
        }
      }
    } else if (all(length(nn(pm$list_indices[!is.na(pm$list_indices)])) > 0, check_paths)) {
      print_message(
        type = type,
        "Neither parameter \"path_indices\" nor \"path_out\" were specified; ",
        "please provide the path of an existing directory for at least one of the two."
      )
    }
  }
  
  # -- path_out --
  if (pm$preprocess == TRUE) {
    if (sum(!is.na(nn(pm$list_prods)))==0) {
      pm$path_out <- NA
    }
    if (all(!is.na(pm$path_out), pm$path_out != "")) {
      if(!dir.exists(pm$path_out)) {
        if(!dir.exists(dirname(pm$path_out))) {
          print_message(
            type = type,
            "Directory \"",dirname(pm$path_out),"\" does not exist ",
            "(it must be created before continuing)."
          )
        }
      }
    } else if (all(length(nn(pm$list_prods[!is.na(pm$list_prods)])) > 0, check_paths)) {
      print_message(
        type = type,
        "Parameter \"path_out\" was not specified; ",
        "please provide the path of an existing directory."
      )
    }
  }
  
  
  # -- path_subdirs --
  
  
  # -- thumbnails --
  
  
  # -- log --
  if (length(pm$log) > 2) {
    print_message(
      type = type,
      paste0("Parameter \"log\" must be of length 1 or 2; ",
             "only the first two elements are used.")
    )
    pm$log <- pm$log[1:2]
  }
  for (i in 1:2) {
    if (all(!is.na(pm$log[i]), pm$log[i] != "")) {
      if(!dir.exists(dirname(pm$log[i]))) {
        print_message(
          type = type,
          "Directory \"",dirname(pm$log[i]),"\" does not exist ",
          "(it must be created before continuing)."
        )
      }
    }
  }
  
  
  # -- parallel --
  if (all(
    !is(pm$parallel, "logical"), !pm$parallel %in% c(TRUE,FALSE),
    !is(pm$parallel, "numeric"), pm$parallel > 0
  )) {
    print_message(
      type = type,
      "Parameter \"",sel_par,"\" must be TRUE or FALSE, ",
      "or a positive integer value; ",
      "setting it to the default (",pm_def$parallel,")."
    )
    pm$parallel <- pm_def$parallel
  }
  if (all(
    is(pm$parallel, "numeric"),
    !is(pm$parallel, "integer")
  )) {
    pm$parallel <- floor(pm$parallel)
  }
  
  
  # -- processing_order --
  if (length(nn(pm$processing_order) > 0)) {
    if (pm$preprocess == FALSE) {
      pm$processing_order <- "by_step"
      # in case no preprocessing is required, "by_step" is the only accepted value
    }
  }
  if (!as.character(pm$processing_order) %in% c("by_step", "mixed", "by_date", "by_groups", 1:4)) {
    print_message(
      type = type,
      "Parameter \"processing_order\" must be one among 'by_step', 'mixed' and ",
      "'by_date', 'by_groups' (setting to the default)."
    )
    pm$processing_order <- pm_def$processing_order
  }
  
  
  # -- pkg_version --
  
  
  
  if (correct==TRUE) {
    return(pm)
  } else {
    return(invisible(NULL))
  }
  
  
}
