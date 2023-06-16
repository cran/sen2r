## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)

## ---- eval = FALSE------------------------------------------------------------
#  list_indices("s2_formula", "^NDVI$")

## ---- eval=FALSE--------------------------------------------------------------
#  json_path <- build_example_param_file()
#  out_dir_1 <- tempfile(pattern = "sen2r_out_1_")
#  
#  library(sen2r)
#  sen2r(
#    json_path,
#    timewindow = c("2019-07-13","2019-07-23"),
#    path_out = out_dir_1
#  )

## ---- eval=FALSE--------------------------------------------------------------
#  system(paste("tree", out_dir_1)) # working on Linux with binary "tree" installed

## ---- eval=FALSE--------------------------------------------------------------
#  out_dir_2 <- tempfile(pattern = "sen2r_out_2_")
#  
#  sen2r(
#    json_path,
#    timewindow = c("2019-07-13","2019-07-23"),
#    path_out = out_dir_2,
#    path_subdirs = FALSE,
#    thumbnails = FALSE
#  )

## ---- eval=FALSE--------------------------------------------------------------
#  system(paste("tree", out_dir_2))

