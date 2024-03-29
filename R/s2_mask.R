#' @title Apply cloud masks
#' @description [s2_mask] Applies a cloud mask to a Sentinel-2 product. Since
#'  [raster] functions are used to perform computations, output files
#'  are physical rasters (no output VRT is allowed).
#' @param infiles A vector of input filenames. Input files are paths
#'  of products already converted from SAFE format to a
#'  format managed by GDAL (use [s2_translate] to do it);
#'  their names must be in the sen2r naming convention
#'  ([safe_shortname]).
#' @param maskfiles A vector of filenames from which to take the
#'  information about cloud coverage (for now, only SCL products
#'  have been implemented). It is not necessary that `maskfiles`
#'  elements strictly match `infiles` ones. Input files are paths
#'  of products already converted from SAFE format to a
#'  format managed by GDAL (use [s2_translate] to do it);
#'  their names must be in the sen2r naming convention
#'  ([safe_shortname]).
#' @param mask_type Character vector which determines the type of
#'  mask to be applied. Accepted values are:
#'  - `"nomask"`: do not mask any pixel;
#'  - `"nodata"`: mask pixels checked as "No data" or "Saturated or defective"
#'      in the SCL product (all pixels with values are maintained);
#'  - `"cloud_high_proba"`: mask pixels checked as "No data", "Saturated or
#'      defective" or "Cloud (high probability)" in the SCL product;
#'  - `"cloud_medium_proba": mask pixels checked as "No data", "Saturated or
#'      defective" or "Cloud (high or medium probability)" in the SCL product;
#'  - `"cloud_and_shadow"`: mask pixels checked as "No data", "Saturated or
#'      defective", "Cloud (high or medium probability)" or "Cloud shadow"
#'      in the SCL product;
#'  - `"clear_sky"`: mask pixels checked as "No data", "Saturated or
#'      defective", "Cloud (high or medium probability)", "Cloud shadow",
#'      "Unclassified" or "Thin cirrus" in the SCL product
#'      (only pixels classified as clear-sky surface - so "Dark area",
#'      "Vegetation", "Bare soil", "Water" or "Snow" - are maintained);
#'  - `"land"`: mask pixels checked as "No data", "Saturated or
#'      defective", "Cloud (high or medium probability)", "Cloud shadow", "Dark area",
#'      "Unclassified", "Thin cirrus", "Water" or "Snow" in the SCL product
#'      (only pixels classified as land surface - so "Vegetation" or
#'      "Bare soil" - are maintained);
#'  - a string in the following form: `"scl_n_m_n"`, where `n`, `m` and `n` 
#'      are one or more SCL class numbers. E.g. string `"scl_0_8_9_11"` can
#'      be used to mask classes 0 ("No data"), 8-9 ("Cloud (high or medium
#'      probability)") and 11 ("Snow").
#' @param smooth (optional) Numerical (positive): the size (in the unit of
#'  `inmask`, typically metres) to be used as radius for the smoothing
#'  (the higher it is, the more smooth the output mask will result).
#'  Default is 0 (no smoothing is applied).
#' @param buffer (optional) Numerical (positive or negative): the size of the
#'  buffer (in the unit of `inmask`, typically metres) to be applied to the
#'  masked area after smoothing it (positive to enlarge, negative to reduce).
#'  Default is 0 (no buffer).
#' @param max_mask (optional) Numeric value (range 0 to 100), which represents
#'  the maximum percentage of allowed masked surface (by clouds or any other
#'  type of mask chosen with argument `mask_type`) for producing outputs.
#'  Images with a percentage of masked surface greater than `max_mask`%
#'  are not processed (the list of expected output files which have not been
#'  generated is returned as an attribute, named `skipped`).
#'  Default value is 100 (images are always produced).
#'  Notice that the percentage is computed on non-NA values (if input images
#'  had previously been clipped and masked using a polygon, the percentage is
#'  computed on the surface included in the masking polygons).
#' @param outdir (optional) Full name of the output directory where
#'  the files should be created (default: `"masked"`
#'  subdir of current directory).
#'  `outdir` can bot be an existing or non-existing directory (in the
#'  second case, its parent directory must exists).
#'  If it is a relative path, it is expanded from the common parent
#'  directory of `infiles`.
#' @param tmpdir (optional) Path where intermediate files (VRT) will be created.
#'  Default is a temporary directory.
#'  If `tmpdir` is a non-empty folder, a random subdirectory will be used.
#' @param rmtmp (optional) Logical: should temporary files be removed?
#'  (Default: TRUE).
#'  This parameter takes effect only if the output files are not VRT
#'  (in this case temporary files cannot be deleted, because rasters of source
#'  bands are included within them).
#' @param save_binary_mask (optional) Logical: should binary masks be exported?
#'  Binary mask are intermediate rasters used to apply the cloud mask:
#'  pixel values can be 1 (no cloud mask), 0 (cloud mask) or NA (original NA
#'  value, i.e. because input rasters had been clipped on the extent polygons).
#'  If FALSE (default) they are not exported; if TRUE, they are exported
#'  as `MSK` prod type (so saved within `outdir`, in a subdirectory called `"MSK"`
#'  if `subdirs = TRUE`).
#'  Notice that the presence of `"MSK"` products is not checked before running
#'  `sen2r()`, as done for the other products; this means that missing products
#'  which are not required to apply cloud masks will not be produced.
#' @param format (optional) Format of the output file (in a
#'  format recognised by GDAL). Default is the same format of input images
#'  (or `"GTiff"` in case of VRT input images).
#' @param subdirs (optional) Logical: if TRUE, different indices are
#'  placed in separated `outfile` subdirectories; if FALSE, they are placed in
#'  `outfile` directory; if NA (default), subdirectories are created only if
#'  more than a single product is required.
#' @param compress (optional) In the case a `GTiff` format is
#'  present, the compression indicated with this parameter is used.
#' @param bigtiff (optional) Logical: if TRUE, the creation of a BigTIFF is
#'  forced (default is FALSE).
#'  This option is used only in the case a GTiff format was chosen. 
#' @param parallel (optional) Logical: if TRUE, masking is conducted using parallel
#'  processing, to speed-up the computation for large rasters.
#'  The number of cores is automatically determined; specifying it is also
#'  possible (e.g. `parallel = 4`).
#'  If FALSE (default), single core processing is used.
#'  Multiprocess masking computation is always performed in singlecore mode
#'  if `format != "VRT"` (because in this case there is no gain in using
#'  multicore processing).
#' @param overwrite (optional) Logical value: should existing output files be
#'  overwritten? (default: FALSE)
#' @param .log_message (optional) Internal parameter
#'  (it is used when the function is called by `sen2r()`).
#' @param .log_output (optional) Internal parameter
#'  (it is used when the function is called by `sen2r()`).
#' @return [s2_mask] returns a vector with the names of the created products.
#'  An attribute `"toomasked"` contains the paths of the outputs which were not
#'  created cause to the high percentage of cloud coverage.
#' @export
#' @importFrom raster brick calc dataType mask overlay stack values
#' @importFrom jsonlite fromJSON
#' @importFrom utils txtProgressBar setTxtProgressBar
#' @importFrom sf gdal_utils
#' @import data.table
#' @author Luigi Ranghetti, phD (2019)
#' @references L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
#'  "sen2r": An R toolbox for automatically downloading and preprocessing 
#'  Sentinel-2 satellite data. _Computers & Geosciences_, 139, 104473. 
#'  \doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
#' @note License: GPL 3.0
#' @examples
#' \donttest{
#' # Define file names
#' ex_in <- system.file(
#'   "extdata/out/S2A2A_20190723_022_Barbellino_RGB432B_10.tif",
#'   package = "sen2r"
#' )
#' ex_mask <- system.file(
#'   "extdata/out/S2A2A_20190723_022_Barbellino_SCL_10.tif",
#'   package = "sen2r"
#' )
#'
#' # Run function
#' ex_out <- s2_mask(
#'   infiles = ex_in,
#'   maskfiles = ex_mask,
#'   mask_type = "land",
#'   outdir = tempdir()
#' )
#' ex_out
#'
#' # Show output
#' oldpar <- par(mfrow = c(1,3))
#' par(mar = rep(0,4))
#' image(stars::read_stars(ex_in), rgb = 1:3, useRaster = TRUE)
#' par(mar = rep(2/3,4))
#' image(stars::read_stars(ex_mask), useRaster = TRUE)
#' par(mar = rep(0,4))
#' image(stars::read_stars(ex_out), rgb = 1:3, useRaster = TRUE)
#' par(oldpar)
#' }

s2_mask <- function(infiles,
                    maskfiles,
                    mask_type,
                    smooth = 0,
                    buffer = 0,
                    max_mask = 100,
                    outdir = "./masked",
                    tmpdir = NA,
                    rmtmp = TRUE,
                    save_binary_mask = FALSE,
                    format = NA,
                    subdirs = NA,
                    compress = "DEFLATE",
                    bigtiff = FALSE,
                    parallel = FALSE,
                    overwrite = FALSE,
                    .log_message = NA,
                    .log_output = NA) {
  .s2_mask(infiles = infiles,
           maskfiles = maskfiles,
           mask_type = mask_type,
           smooth = smooth,
           buffer = buffer,
           max_mask = max_mask,
           outdir = outdir,
           tmpdir = tmpdir,
           rmtmp = rmtmp,
           save_binary_mask = save_binary_mask,
           format = format,
           subdirs = subdirs,
           compress = compress,
           bigtiff = bigtiff,
           parallel = parallel,
           overwrite = overwrite,
           output_type = "s2_mask",
           .log_message = .log_message,
           .log_output = .log_output)
}

.s2_mask <- function(infiles,
                     maskfiles,
                     mask_type = "cloud_medium_proba",
                     smooth = 250,
                     buffer = 250,
                     max_mask = 80,
                     outdir = "./masked",
                     tmpdir = NA,
                     rmtmp = TRUE,
                     save_binary_mask = FALSE,
                     format = NA,
                     subdirs = NA,
                     compress = "DEFLATE",
                     bigtiff = FALSE,
                     parallel = FALSE,
                     overwrite = FALSE,
                     output_type = "s2_mask", # determines if using s2_mask() or s2_perc_masked()
                     .log_message = NA,
                     .log_output = NA) {
  
  . <- NULL
  
  # Check that files exist
  if (!any(sapply(infiles, file.exists))) {
    print_message(
      type="error",
      if (!all(sapply(infiles, file.exists))) {"The "} else {"Some of the "},
      "input files (\"",
      paste(infiles[!sapply(infiles, file.exists)], collapse="\", \""),
      "\") do not exists locally; please check file names and paths.")
  }
  
  # check output format
  gdal_formats <- fromJSON(
    system.file("extdata/settings/gdal_formats.json",package="sen2r")
  )$drivers
  if (!is.na(format)) {
    sel_driver <- gdal_formats[gdal_formats$name==format,]
    if (nrow(sel_driver)==0) {
      print_message(
        type="error",
        "Format \"",format,"\" is not recognised; ",
        "please use one of the formats supported by your GDAL installation.\n\n",
        "To list them, use the following command:\n",
        "\u00A0\u00A0gdalUtils::gdalinfo(formats=TRUE)\n\n",
        "To search for a specific format, use:\n",
        "\u00A0\u00A0gdalinfo(formats=TRUE)[grep(\"yourformat\", gdalinfo(formats=TRUE))]")
    }
  }
  
  # Check tmpdir
  # define and create tmpdir
  if (is.na(tmpdir)) {
    tmpdir <- if (all(!is.na(format), format == "VRT")) {
      if (!missing(outdir)) {
        autotmpdir <- FALSE # logical: TRUE if tmpdir should be specified
        # for each out file (when tmpdir was not specified and output files are vrt),
        # FALSE if a single tmpdir should be used (otherwise)
        file.path(outdir, ".vrt")
      } else {
        autotmpdir <- TRUE
        tempfile(pattern="s2mask_")
      }
    } else {
      autotmpdir <- FALSE
      tempfile(pattern="s2mask_")
    }
  } else {
    if (dir.exists(tmpdir)) {
      tmpdir <- file.path(tmpdir, basename(tempfile(pattern="s2mask_")))
    }
    autotmpdir <- FALSE
  }
  if (all(!is.na(format), format == "VRT")) {
    rmtmp <- FALSE # force not to remove intermediate files
  }
  dir.create(tmpdir, recursive=FALSE, showWarnings=FALSE)
  
  # Get files metadata
  infiles_meta_sen2r <- sen2r_getElements(infiles, format="data.table")
  infiles_meta_raster <- raster_metadata(infiles, c("res", "outformat", "unit"), format="data.table")
  maskfiles_meta_sen2r <- sen2r_getElements(maskfiles, format="data.table")
  
  # create outdir if not existing (and dirname(outdir) exists)
  suppressWarnings(outdir <- expand_path(outdir, parent=comsub(infiles,"/"), silent=TRUE))
  if (!dir.exists(dirname(outdir))) {
    print_message(
      type = "error",
      "The parent folder of 'outdir' (",outdir,") does not exist; ",
      "please create it."
    )
  }
  dir.create(outdir, recursive=FALSE, showWarnings=FALSE)
  
  # create subdirs (if requested)
  prod_types <- unique(infiles_meta_sen2r$prod_type)
  if (is.na(subdirs)) {
    subdirs <- ifelse(length(prod_types)>1, TRUE, FALSE)
  }
  if (subdirs) {
    sapply(file.path(outdir,prod_types), dir.create, showWarnings=FALSE)
  }
  
  # check smooth and buffer
  if (anyNA(smooth)) {smooth <- 0}
  if (anyNA(buffer)) {buffer <- 0}
  
  # define required bands and formula to compute masks
  # accepted mask_type values: nodata, cloud_high_proba, cloud_medium_proba, cloud_low_proba, cloud_and_shadow, clear_sky, land
  # structure of req_masks: list, names are prod_types, content are values of the files to set as 0, otherwise 1
  if (mask_type == "nomask") {
    req_masks <- list()
  } else if (mask_type == "nodata") {
    req_masks <- list("SCL"=c(0:1))
  } else if (mask_type == "cloud_high_proba") {
    req_masks <- list("SCL"=c(0:1,9))
  } else if (mask_type == "cloud_medium_proba") {
    req_masks <- list("SCL"=c(0:1,8:9))
  } else if (mask_type == "cloud_low_proba") { # left for compatibility
    req_masks <- list("SCL"=c(0:1,7:9))
  } else if (mask_type == "cloud_and_shadow") { # changed! class 7 no more masked
    req_masks <- list("SCL"=c(0:1,3,8:9))
  } else if (mask_type == "clear_sky") {
    req_masks <- list("SCL"=c(0:1,3,7:10))
  } else if (mask_type == "land") {
    req_masks <- list("SCL"=c(0:3,6:11))
  } else if (grepl("^scl\\_", mask_type)) {
    req_masks <- list("SCL"=strsplit(mask_type,"_")[[1]][-1])
  }
  
  ## Cycle on each file
  if (output_type == "s2_mask") {
    outfiles <- character(0) # vector with paths of created files
    outfiles_toomasked <- character(0) # vector with the path of outputs which
    # were not created cause to the higher masked surface
  } else if (output_type == "perc") {
    outpercs <- numeric(0)
  }
  for (i in seq_along(infiles)) {try({
    sel_infile <- infiles[i]
    sel_infile_meta_sen2r <- c(infiles_meta_sen2r[i,])
    sel_infile_meta_raster <- c(infiles_meta_raster[i,])
    sel_format <- if (is.na(format)) {
      sel_infile_meta_raster$outformat
    } else {
      format
    }
    sel_rmtmp <- ifelse(sel_format == "VRT", FALSE, rmtmp)
    sel_out_ext <- gdal_formats[gdal_formats$name==sel_format,"ext"][1]
    sel_naflag <- s2_defNA(sel_infile_meta_sen2r$prod_type)
    
    # check that infile has the correct maskfile
    sel_maskfiles <- sapply(names(req_masks), function(m) {
      sel1 <- maskfiles_meta_sen2r$prod_type==m &
        maskfiles_meta_sen2r$type==sel_infile_meta_sen2r$type &
        maskfiles_meta_sen2r$mission==sel_infile_meta_sen2r$mission &
        maskfiles_meta_sen2r$sensing_date==sel_infile_meta_sen2r$sensing_date &
        maskfiles_meta_sen2r$id_orbit==sel_infile_meta_sen2r$id_orbit
      if (!is.null(maskfiles_meta_sen2r$res) & !is.null(sel_infile_meta_sen2r$res)) {
        sel1 <- sel1 &
          maskfiles_meta_sen2r$res==sel_infile_meta_sen2r$res
      }
      maskfiles[which(sel1)][1]
    })
    
    # define subdir
    out_subdir <- ifelse(subdirs, file.path(outdir,infiles_meta_sen2r[i,"prod_type"]), outdir)
    
    # define out name (a vrt for all except the last mask)
    sel_outfile <- file.path(
      out_subdir,
      gsub(paste0("\\.",infiles_meta_sen2r[i,"file_ext"],"$"),
           paste0(".",sel_out_ext),
           basename(sel_infile)))
    
    # if output already exists and overwrite==FALSE, do not proceed
    if (!file.exists(sel_outfile) | overwrite==TRUE) {
      
      print_message(
        type = "message",
        date = TRUE,
        paste0("Masking file ", basename(sel_outfile),"...")
      )
      
      # if no masking is required, "copy" input files
      if (length(sel_maskfiles)==0) {
        gdalUtil(
          "translate",
          source = sel_infile,
          destination = sel_outfile,
          options = c(
            "-of", sel_format,
            if (sel_format == "GTiff") {c(
              "-co", paste0("COMPRESS=",toupper(compress)),
              "-co", "TILED=YES"
            )},
            if (sel_format=="GTiff" & bigtiff==TRUE) {c("-co", "BIGTIFF=YES")}
          ),
          quiet = TRUE
        )
      } else {
        
        # load input rasters
        inmask <- raster::stack(sel_maskfiles)
        
        # path for bug #47
        if (Sys.info()["sysname"] == "Windows" & gsub(".*\\.([^\\.]+)$","\\1",sel_infile)=="vrt") {
          # on Windows, use input physical files
          gdalUtil(
            "translate",
            source = sel_infile,
            destination = gsub("\\.vrt$",".tif",sel_infile),
            options = c(
              "-of", "GTiff",
              "-co", paste0("COMPRESS=",toupper(compress)),
              "-co", "TILED=YES",
              if (bigtiff == TRUE) {c("-co", "BIGTIFF=YES")}
            ),
            quiet = TRUE
          )
          sel_infile <- gsub("\\.vrt$",".tif",sel_infile)
        }
        
        # if tmpdir should vary for each file, define it
        sel_tmpdir <- if (autotmpdir) {
          file.path(out_subdir, ".vrt")
        } else {
          tmpdir
        }
        dir.create(sel_tmpdir, showWarnings=FALSE)
        
        # create global mask
        mask_tmpfiles <- character(0) # files which compose the mask
        naval_tmpfiles <- character(0) # files which determine the amount of NA
        for (j in seq_along(inmask@layers)) {
          mask_tmpfiles <- c(
            mask_tmpfiles,
            file.path(sel_tmpdir, basename(tempfile(pattern = "mask_", fileext = ".tif")))
          )
          suppress_warnings(
            raster::calc(
              inmask[[j]],
              function(x){as.integer(!is.na(nn(x)) & !x %in% req_masks[[j]])},
              filename = mask_tmpfiles[j],
              options = c(
                "COMPRESS=LZW",
                if (bigtiff==TRUE) {"BIGTIFF=YES"}
              ),
              datatype = "INT1U",
              overwrite = TRUE
            ),
            "NOT UPDATED FOR PROJ >\\= 6"
          )
          naval_tmpfiles <- c(
            naval_tmpfiles,
            file.path(sel_tmpdir, basename(tempfile(pattern = "naval_", fileext = ".tif")))
          )
          suppress_warnings(
            raster::calc(
              inmask[[j]],
              function(x){as.integer(!is.na(nn(x)))},
              filename = naval_tmpfiles[j],
              options = "COMPRESS=LZW",
              datatype = "INT1U"
            ),
            "NOT UPDATED FOR PROJ >\\= 6"
          )
        }
        if(length(mask_tmpfiles)==1) {
          outmask <- mask_tmpfiles
          outnaval <- naval_tmpfiles
        } else {
          outmask <- file.path(sel_tmpdir, basename(tempfile(pattern = "mask_", fileext = ".tif")))
          outnaval <- file.path(sel_tmpdir, basename(tempfile(pattern = "naval_", fileext = ".tif")))
          raster::overlay(stack(mask_tmpfiles),
                          fun = sum,
                          filename = outmask,
                          options = "COMPRESS=LZW",
                          datatype = "INT1U")
          raster::overlay(stack(naval_tmpfiles),
                          fun = sum,
                          filename = outnaval,
                          options = "COMPRESS=LZW",
                          datatype = "INT1U")
        }
        
        # compute the percentage of masked surface
        
        # This is as fast as previous, but memory friendly on large raster
        mean_values_naval <- raster::cellStats(raster(outnaval), "mean", na.rm = TRUE)
        mean_values_mask <- raster::cellStats(raster(outmask), "mean", na.rm = TRUE)
        
        perc_mask <- 100 * (mean_values_naval - mean_values_mask) / mean_values_naval
        if (!is.finite(perc_mask)) {perc_mask <- 100}
        
        # if the requested output is this value, return it; else, continue masking
        if (output_type == "perc") {
          names(perc_mask) <- sel_infile
          outpercs <- c(outpercs, perc_mask)
        } else if (output_type == "s2_mask") {
          
          # evaluate if the output have to be produced
          # if the image is sufficiently clean, mask it
          if (is.na(max_mask) | perc_mask <= max_mask) {
            
            # if mask is at different resolution than inraster
            # (e.g. 20m instead of 10m),
            # resample it
            if (any(
              unlist(sel_infile_meta_raster[c("res.x","res.y")]) !=
              unlist(raster_metadata(outmask, "res", format = "list")[[1]]$res)
            )) {
              gdal_warp( # DO NOT use raster::disaggregate (1. not faster, 2. it does not always provide the right resolution)
                outmask,
                outmask_res <- file.path(sel_tmpdir, basename(tempfile(pattern = "mask_", fileext = ".tif"))),
                ref = sel_infile
              )
            } else {
              outmask_res <- outmask
            }
            
            # the same for outnaval
            if (any(
              unlist(sel_infile_meta_raster[c("res.x","res.y")]) !=
              unlist(raster_metadata(outnaval, "res", format = "list")[[1]]$res)
            )) {
              gdal_warp(
                outnaval,
                outnaval_res <- file.path(sel_tmpdir, basename(tempfile(pattern = "naval_", fileext = ".tif"))),
                ref = sel_infile
              )
            } else {
              outnaval_res <- outnaval
            }
            
            # apply the smoothing (if required)
            outmask_smooth <- if (smooth > 0 | buffer != 0) {
              # if the unit is not metres, approximate it
              if (sel_infile_meta_raster$unit == "degree") {
                buffer <- buffer * 8.15e-6
                smooth <- smooth * 8.15e-6
              }
              # apply the smooth to the mask
              min_values_naval <- raster::cellStats(raster(outnaval), "min", na.rm = TRUE)
              smooth_mask(
                outmask_res,
                radius = smooth, buffer = buffer,
                namask = if (min_values_naval==0) {outnaval_res} else {NULL}, # TODO NULL if no Nodata values are present
                tmpdir = sel_tmpdir,
                bigtiff = bigtiff
              )
            } else {
              outmask_res
            }
            
            # if the user required to save 0-1 masks, save them
            if (save_binary_mask == TRUE) {
              # define out MSK name
              binmask <- file.path(
                ifelse(subdirs, file.path(outdir,"MSK"), outdir),
                gsub(paste0("\\.",infiles_meta_sen2r[i,"file_ext"],"$"),
                     paste0(".",sel_out_ext),
                     gsub(paste0("\\_",infiles_meta_sen2r[i,"prod_type"],"\\_"),
                          "_MSK_",
                          basename(sel_infile)))
              )
              # create subdir if missing
              if (subdirs & !dir.exists(file.path(outdir,"MSK"))) {
                dir.create(file.path(outdir,"MSK"))
              }
              if (any(!file.exists(binmask), overwrite == TRUE)) {
                # mask NA values
                suppress_warnings(
                  raster::mask(
                    raster(outmask_smooth),
                    raster(outnaval_res),
                    filename = binmask,
                    maskvalue = 0,
                    updatevalue = sel_naflag,
                    updateNA = TRUE,
                    NAflag = 255,
                    datatype = "INT1U",
                    format = sel_format,
                    options = if(sel_format == "GTiff") {paste0("COMPRESS=",compress)},
                    overwrite = overwrite
                  ),
                  "NOT UPDATED FOR PROJ >\\= 6"
                )
              }
            }
            
            # load mask
            inraster <- raster::brick(sel_infile)
            
            # Maskapply
            maskapply_serial <- function(
              x, y, na, out_file = '', datatype, minrows = NULL,
              overwrite = overwrite
            ) {
              if (inherits(x, "RasterStackBrick")) {
                out <- brick(x, values = FALSE)
              }
              else {
                out <- raster(x)
                out@legend <- x@legend
              }
              
              if (grepl("\\.vrt$", out_file)) {
                out_file <- gsub("\\.vrt$", ".tif", out_file)
              }
              suppress_warnings(
                out <- writeStart(
                  out,
                  out_file,
                  NAflag=na,
                  datatype = datatype,
                  format = ifelse(sel_format=="VRT","GTiff",sel_format),
                  if (sel_format %in% c("GTiff","VRT")) {
                    options = c(
                      "COMPRESS=LZW",
                      if (bigtiff==TRUE) {"BIGTIFF=YES"}
                    )
                  },
                  overwrite = overwrite
                ),
                "NOT UPDATED FOR PROJ >\\= 6"
              )
              #4 bytes per cell, nb + 1 bands (brick + mask), * 2 to account for a copy
              bs <- blockSize(out, minblocks = 8)
              if (all(inherits(stdout(), "terminal"), interactive())) {
                pb <- txtProgressBar(0, bs$n, style = 3)
              }
              for (j in seq_len(bs$n)) {
                # message("Processing chunk ", j, " of ", bs$n)

                m <- raster::getValuesBlock(y, row = bs$row[j], nrows = bs$nrows[j])
                v <- raster::getValuesBlock(x, row = bs$row[j], nrows = bs$nrows[j])
                v[m == 0] <- NA
                
                out <- writeValues(out, v, bs$row[j])
                gc()
                if (all(inherits(stdout(), "terminal"), interactive())) {
                  setTxtProgressBar(pb, j)
                }
              }
              if (all(inherits(stdout(), "terminal"), interactive())) {
                message("")
              }
              out <- writeStop(out)
            }
            out <- maskapply_serial(
              x = inraster,
              y = raster(outmask_smooth),
              out_file = sel_outfile,
              na = sel_naflag,
              datatype = dataType(inraster),
              overwrite = TRUE
            )
            if (grepl("\\.vrt$", sel_outfile)) {
              file.rename(gsub("\\.vrt$", ".tif", sel_outfile), sel_outfile)
            }
            
            # fix for envi extension (writeRaster use .envi)
            if (sel_format=="ENVI") {fix_envi_format(sel_outfile)}
            
          } else { # end of max_mask IF cycle
            outfiles_toomasked <- c(outfiles_toomasked, sel_outfile)
          }
          
        } # end of output_type IF cycle
        
        if (sel_rmtmp == TRUE) {
          unlink(sel_tmpdir, recursive=TRUE) # FIXME check not to delete files created outside sel_ cycle!
        }
        
      } # end of length(sel_maskfiles)==0 IF cycle
      
    } # end of overwrite IF cycle
    
    if (output_type == "s2_mask" & file.exists(sel_outfile)) {
      outfiles <- c(outfiles, sel_outfile)
    }
    
  })} # end on infiles cycle
  
  # Remove temporary files
  if (rmtmp == TRUE) {
    unlink(tmpdir, recursive=TRUE)
  }
  
  if (output_type == "s2_mask") {
    attr(outfiles, "toomasked") <- outfiles_toomasked
    return(outfiles)
  } else if (output_type == "perc") {
    return(outpercs)
  }
  
}


#' @description [s2_perc_masked] computes the percentage of cloud-masked surface.
#'  The function is similar to [s2_mask], but it returns percentages instead
#'  of masked rasters.
#' @return [s2_perc_masked] returns a names vector with the percentages
#'  of masked surfaces.
#' @rdname s2_mask
#' @export

s2_perc_masked <- function(infiles,
                           maskfiles,
                           mask_type = "cloud_medium_proba",
                           tmpdir = NA,
                           rmtmp = TRUE,
                           parallel = FALSE) {
  .s2_mask(infiles = infiles,
           maskfiles = maskfiles,
           mask_type = mask_type,
           smooth = 0,
           buffer = 0,
           max_mask = 100,
           tmpdir = tmpdir,
           rmtmp = rmtmp,
           parallel = parallel,
           output_type = "perc")
}
