#' @title Return the mountpoint of the input directory (if it is mounted)
#' @description The function checks if the input directory is a subdirectory
#'  of a mountpoint of a certain protocol. At the moment, it works only on unix
#'  operating systems.
#' @param path The path to be checked
#' @param protocol (optional) Vector of protocol types. If NA (default),
#'  all the protocols are considered.
#' @return The path of the parent mountpoint for mounted directories; 
#'  if the input directory is not mounted, NULL is returned.
#'  NULL is returned also if the operating system is not unix
#'  (together with a warning message).
#'  An attribute "protocol" contains the protocol of the mountpoint.
#'
#' @author Luigi Ranghetti, phD (2019)
#' @references L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
#'  "sen2r": An R toolbox for automatically downloading and preprocessing 
#'  Sentinel-2 satellite data. _Computers & Geosciences_, 139, 104473. 
#'  \doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
#' @note License: GPL 3.0
#' @export

mountpoint <- function(path, protocol=NA) {
  
  # apply only in unix systems
  if (Sys.info()["sysname"] == "Windows") {
    print_message(
      type = "warning",
      "This function does not work on Windows systems."
    )
    return(invisible(NULL))
  }
  
  # retrieve mountpoints
  mountpoints <- system("mount", intern=TRUE)
  
  # extract paths
  mountpoints_paths <- gsub("^[^ ]+ on (.+) type ([^ ]+) .*$", "\\1", mountpoints)
  mountpoints_protocols <- gsub("^[^ ]+ on (.+) type ([^ ]+) .*$", "\\2", mountpoints)
  # mountpoints_protocols <- mountpoints_protocols[mountpoints_paths != "/"]
  # mountpoints_paths <- mountpoints_paths[mountpoints_paths != "/"]
  
  # limit to required protocols
  if (!is.na(protocol)) {
    mountpoints_paths <- mountpoints_paths[mountpoints_protocols %in% protocol]
    mountpoints_protocols <- mountpoints_protocols[mountpoints_protocols %in% protocol]
  }
  
  # scan the path
  path <- expand_path(path)
  parents <- sapply(
    sapply(mountpoints_paths, grep, path),
    length
  ) > 0
  
  parents <- names(parents)[parents]
  
  if (length(parents) == 0) {
    # if no parent directories, return NULL
    return(invisible(NULL))
  } else if (length(parents) > 1) {
    # if more than one parent directories, return the "nearer" to path
    parents <- names(sort(sapply(parents,nchar), decreasing=TRUE))[1]
  }
  
  attr(parents, "protocol") <- mountpoints_protocols[mountpoints_paths==parents]
  
  parents
  
}
