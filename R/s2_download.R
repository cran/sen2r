#' @title Download S2 products.
#' @description The function downloads a single S2 product.
#'  Input filename must be an element obtained with
#'  [s2_list] function
#'  (the content must be a URL, and the name the product name).
#' @param s2_prodlist List of the products to be downloaded
#'  (this must be the output of [s2_list] function).
#' @param downloader Executable to use to download products
#'  (default: "builtin"). Alternatives are "builtin" or "aria2"
#'  (this requires aria2c to be installed).
#' @param apihub Path of the "apihub.txt" file containing credentials
#'  of SciHub account.
#'  If NA (default), the default location inside the package will be used.
#' @param tile Single Sentinel-2 Tile string (5-length character)
#' @param outdir (optional) Full name of the existing output directory
#'  where the files should be created (default: current directory).
#' @param overwrite Logical value: should existing output archives be
#'  overwritten? (default: FALSE)
#' @return NULL (the function is called for its side effects)
#'
#' @author Luigi Ranghetti, phD (2019) \email{luigi@@ranghetti.info}
#' @author Lorenzo Busetto, phD (2019) \email{lbusett@@gmail.com}
#' @note License: GPL 3.0
#' @importFrom httr GET RETRY authenticate progress write_disk
#' @export
#'
#' @examples
#' \dontrun{
#' single_s2 <- paste0("https://scihub.copernicus.eu/apihub/odata/v1/",
#'   "Products(\'c7142722-42bf-4f93-b8c5-59fd1792c430\')/$value")
#' names(single_s2) <- "S2A_MSIL1C_20170613T101031_N0205_R022_T32TQQ_20170613T101608.SAFE"
#' # (this is equivalent to:
#' # single_s2 <- example_s2_list[1]
#' # where example_s2_list is the output of the example of the
#' # s2_list() function)
#'
#' # Download the whole product
#' s2_download(single_s2, outdir=tempdir())
#'
#' #' # Download the whole product - using aria2
#' s2_download(single_s2, outdir=tempdir(), downloader = "aria2")
#'
#' # Download a specific tile
#' s2_download(single_s2, tile="32TQQ", outdir=tempdir())
#' # (for products with compact names, the two above commands produce equivalent
#' # results: the first one downloads a SAFE archive, while the second one
#' # downloads single product files)
#'
#' # Download a serie of products
#' pos <- st_sfc(st_point(c(12.0, 44.8)), crs=st_crs(4326))
#' time_window <- as.Date(c("2017-05-01","2017-07-30"))
#' example_s2_list <- s2_list(spatial_extent=pos, tile="32TQQ", time_interval=time_window)
#' s2_download(example_s2_list, outdir=tempdir())
#' }

s2_download <- function(s2_prodlist = NULL,
                        downloader = "builtin",
                        apihub = NA,
                        tile = NULL,
                        outdir = ".",
                        overwrite = FALSE) {
  
  # convert input NA arguments in NULL
  for (a in c("s2_prodlist","tile","apihub")) {
    if (suppressWarnings(all(is.na(get(a))))) {
      assign(a,NULL)
    }
  }
  
  # read credentials
  creds <- read_scihub_login(apihub)
  
  # check downloader
  if (!downloader %in% c("builtin", "aria2", "aria2c")) {
    print_message(
      type = "warning",
      "Downloader \"",downloader,"\" not recognised ",
      "(builtin will be used)."
    )
    downloader <- "builtin"
  }
  
  for (i in seq_len(length(s2_prodlist))) {
    
    link <- s2_prodlist[i]
    zip_path <- file.path(outdir, paste0(names(s2_prodlist[i]),".zip"))
    safe_path <- gsub("\\.zip$", "", zip_path)
    
    if (any(overwrite == TRUE, !file.exists(safe_path))) {
      
      print_message(
        type = "message",
        date = TRUE,
        "Downloading Sentinel-2 image ", i," of ",length(s2_prodlist),
        " (",basename(safe_path),")..."
      )
      
      if (downloader %in% c("builtin", "wget")) { # wget left for compatibility
        
        download <- httr::RETRY(
          verb = "GET",
          url = as.character(link),
          config = httr::authenticate(creds[1], creds[2]),
          times = 10,
          httr::progress(),
          httr::write_disk(zip_path, overwrite = TRUE)
        )
        
      } else if (grepl("^aria2c?$", downloader)) {
        
        binpaths <- load_binpaths("aria2")
        if (Sys.info()["sysname"] != "Windows") {
          link <- gsub("/\\$value", "/\\\\$value", link)
        }
        aria_string <- paste0(
          binpaths$aria2c, " -x 2 --check-certificate=false -d ",
          dirname(zip_path),
          " -o ", basename(zip_path),
          " ", "\"", as.character(link), "\"",
          " --allow-overwrite --file-allocation=none --retry-wait=2",
          " --http-user=", "\"", creds[1], "\"",
          " --http-passwd=", "\"", creds[2], "\"",
          " --max-tries=10"
        )
        download <- try({
          system(aria_string, intern = Sys.info()["sysname"] == "Windows")
        })
        
      }
      
      if (inherits(download, "try-error")) {
        suppressWarnings(file.remove(zip_path))
        suppressWarnings(file.remove(paste0(zip_path,".aria2")))
        print_message(
          type = "error",
          "Download of file", link, "failed more than 10 times. ",
          "Internet connection or SciHub may be down."
        )
      } else {
        # check md5
        check_md5 <- tryCatch({
          sel_md5 <- httr::GET(
            url = gsub("\\$value$", "Checksum/Value/$value", as.character(link)),
            config = httr::authenticate(creds[1], creds[2]),
            httr::write_disk(md5file <- tempfile(), overwrite = TRUE),
            times = 10
          )
          md5 <- toupper(readLines(md5file, warn = FALSE)) == toupper(tools::md5sum(zip_path))
          file.remove(md5file)
          md5
        }, error = function(e) {logical(0)})
        if (length(check_md5) == 0) {
          print_message(
            type = "warning",
            "File ", names(link), " cannot be checked. ",
            "Please verify if the download was successful."
          )
        } else if (!check_md5) {
          file.remove(zip_path)
          print_message(
            type = "error",
            "Download of file ", names(link), " was incomplete (Md5sum check failed). ",
            "Please retry to launch the download."
          )
        }
        # remove existing SAFE
        if (dir.exists(safe_path)) {
          unlink(safe_path, recursive = TRUE)
        }
        # unzip
        unzip(zip_path, exdir = dirname(zip_path))
        file.remove(zip_path)
      }
      
    } else {
      
      print_message(
        type = "message",
        date = TRUE,
        "Skipping Sentinel-2 image ", i," of ",length(s2_prodlist),
        " (",basename(safe_path),") ",
        "since the corresponding folder already exists."
      )
      
    }
    
  }
  
  return(invisible(NULL))
  
}