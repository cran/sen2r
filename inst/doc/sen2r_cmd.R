## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)

## ----eval=FALSE---------------------------------------------------------------
#  # Set paths
#  out_dir_1  <- tempfile(pattern = "sen2r_out_1_") # output folder
#  safe_dir <- tempfile(pattern = "sen2r_safe_")  # folder to store downloaded SAFE
#  
#  myextent_1 <- system.file("extdata/vector/barbellino.geojson", package = "sen2r")
#  
#  library(sen2r)
#  out_paths_1 <- sen2r(
#    gui = FALSE,
#    step_atmcorr = "l2a",
#    extent = myextent_1,
#    extent_name = "Barbellino",
#    timewindow = c(as.Date("2020-11-13"), as.Date("2020-11-25")),
#    list_prods = c("BOA","SCL"),
#    list_indices = c("NDVI","MSAVI2"),
#    list_rgb = c("RGB432B"),
#    mask_type = "cloud_and_shadow",
#    max_mask = 10,
#    path_l2a = safe_dir,
#    path_out = out_dir_1
#  )

## ----eval=FALSE---------------------------------------------------------------
#  list.files(safe_dir)

## ----eval=FALSE---------------------------------------------------------------
#  list.files(out_dir_1)

## ----eval=FALSE---------------------------------------------------------------
#  list.files(file.path(out_dir_1, "NDVI"))

## ----eval=FALSE---------------------------------------------------------------
#  # set the path to an existing JSON file
#  # (commented here, and substituted with an instruction that creates
#  # a test JSON file)
#  # json_path <- "/path/to/myparams.json"
#  json_path_2 <- build_example_param_file()
#  json_path_2

## ----eval=FALSE---------------------------------------------------------------
#  out_paths_2 <- sen2r(param_list = json_path_2)

## ----eval=FALSE---------------------------------------------------------------
#  # use the previously saved JSON path
#  json_path_2

## ----eval=FALSE---------------------------------------------------------------
#  out_dir_3 <- tempfile(pattern = "sen2r_out_3_")  # new output folder
#  
#  myextent_3 <- system.file("extdata/vector/scalve.kml", package = "sen2r")
#  
#  out_paths_3 <- sen2r(
#    param_list = json_path_2,
#    extent = myextent_3,
#    extent_name = "newxtent",
#    timewindow = c(as.Date("2020-10-01"), as.Date("2020-10-30")),
#    path_out = out_dir_3
#  )

