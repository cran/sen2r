#' @title Create the indices database
#' @description The internal function checks if indices.json (the
#'  database of spectral indices) already exists; if not, it
#'  downloads source files and creates it.
#'  Since this function depends on `xsltproc` executable (available
#'  only for Linux), this function can be used only from from
#'  Linux. It is not necessary, since a indices.json file is
#'  present in the package.
#' @param xslt_path (optional) The path where to install `xsltml`,
#'  an external `xsltproc` script used to convert MathML index formulas
#'  to LaTeX (default: a subdirectory of the package).
#' @param json_path (optional) The path of the output JSON file.
#'  *Warning*: to create a file which will be usable by the package,
#'  this option must be left to NA (default location is within the
#'  package installation). Edit this only to create the file in another
#'  place for external use.
#' @param force (optional) Logical: if FALSE (default), the db is created only
#'  if missing or not updated; if TRUE, it is created in any case.
#' @return NULL (the function is called for its side effects)
#' @author Luigi Ranghetti, phD (2019)
#' @references L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
#'  "sen2r": An R toolbox for automatically downloading and preprocessing 
#'  Sentinel-2 satellite data. _Computers & Geosciences_, 139, 104473. 
#'  \doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
#' @note License: GPL 3.0
#' @import data.table
#' @importFrom XML htmlTreeParse xmlRoot readHTMLTable xmlAttrs saveXML
#' @importFrom jsonlite toJSON fromJSON
#' @importFrom stats runif
#' @importFrom utils capture.output download.file unzip packageVersion
#' @keywords internal


create_indices_db <- function(xslt_path = NA,
                              json_path = NA,
                              force = FALSE) {
  
  # to avoid NOTE on check
  . <- n_index <- name <- longname <- s2_formula <- type <- checked <- link <- a <- NULL
  
  # check if indices.json already exists, and if the version is updated
  # we assume that a new version of indices.json is created at every new ackage update
  if (is.na(json_path)) {
    json_path <- file.path(system.file("extdata/settings",package="sen2r"),"indices.json")
  }
  if (system.file("extdata/settings/indices.json", package="sen2r") == json_path) {
    if (force == FALSE) {
      return(invisible(NULL))
    }
  }
  
  # check the presence of xsltproc
  if (Sys.which("xsltproc")=="") {
    print_message(
      type="error",
      "\"xsltproc\" was not found in your system; ",
      "please install it or update your system PATH.")
  }
  
  # set XSLT path
  if (is.na(xslt_path)) {
    xslt_path <- file.path(dirname(attr(load_binpaths(), "path")),"xslt")
  }
  
  # if missing, download xsltml to convert from MathML to LaTeX: http://fhoerni.free.fr/comp/xslt.html
  if (any(!file.exists(file.path(xslt_path,c("cmarkup.xsl","entities.xsl","glayout.xsl","mmltex.xsl","scripts.xsl","tables.xsl","tokens.xsl"))))) {
    dir.create(xslt_path, recursive=FALSE, showWarnings=FALSE)
    download.file("https://netix.dl.sourceforge.net/project/xsltml/xsltml/v.2.1.2/xsltml_2.1.2.zip",
                  file.path(xslt_path,"xsltml_2.1.2.zip"),
                  quiet = TRUE)
    unzip(file.path(xslt_path,"xsltml_2.1.2.zip"), exdir=xslt_path)
    unlink(file.path(xslt_path,"xsltml_2.1.2.zip"))
  }
  
  # Read HTML indices database from indexdatabase.de
  idb_url <- "http://www.indexdatabase.de"
  idb_s2indices_url <- file.path(idb_url,"db/is.php?sensor_id=96")
  download.file(idb_s2indices_url, s2_path <- tempfile(), quiet = TRUE)
  s2_html <- xmlRoot(htmlTreeParse(s2_path, useInternalNodes = FALSE))
  s2_htmlinternal <- xmlRoot(htmlTreeParse(s2_path, useInternalNodes = TRUE))
  s2_html_table <- s2_html[["body"]][["div"]][["table"]]
  s2_htmlinternal_table <- s2_htmlinternal[["body"]][["div"]][["table"]]
  unlink(s2_path)
  
  s2_table <- data.table(readHTMLTable(s2_htmlinternal_table, header=TRUE, stringsAsFactors=FALSE)[,1:3])
  setnames(s2_table, c( "Nr.\r\n      ", "Name\r\n      ","Abbrev.\r\n      "),
           c("n_index","longname","name"))
  
  s2_table$link <- paste0(idb_url, sapply(seq_along(s2_html_table)[-1], function(x) {
    xmlAttrs(s2_html_table[[x]][[2]][[1]])["href"]
  }))
  s2_formula_mathml <- lapply(seq_along(s2_html_table)[-1], function(x) {
    s2_html_table[[x]][[5]][[1]]
  })
  s2_formula_mathml_general <- lapply(seq_along(s2_html_table)[-1], function(x) {
    s2_html_table[[x]][[4]][[1]]
  }) # this is used for automatic band substitution
  
  # Build table
  s2_table$s2_formula <- as.character(NA)
  s2_table[,n_index:=as.integer(n_index)]
  if (any(s2_table$n_index != seq_len(nrow(s2_table)))) {
    print_message(
      type="error",
      "The index numbering in Index DataBase is altered; ",
      "please report this to a maintainer.")
  }
  
  # clean database
  n_index_toremove <- c()
  # change name to some indices
  s2_table[grep("MIR/NIR Normalized Difference",s2_table$longname),name:="NDVI2"]
  s2_table[longname=="Transformed Soil Adjusted Vegetation Index 2",name:="TSAVI2"]
  s2_table[longname=="Modified Soil Adjusted Vegetation Index",name:="MSAVI2"]
  
  # Change names containing "/"
  s2_table[,name:=gsub("/","-",name)]
  
  # remove indices without name
  n_index_toremove <- c(n_index_toremove, s2_table[name=="",n_index])
  # replacing duplicated indices
  n_index_toremove <- c(
    n_index_toremove,
    s2_table[longname %in% c(
      "RDVI",
      "RDVI2",
      "Normalized Difference NIR/Green Green NDVI",
      "Enhanced Vegetation Index 2"
    ),n_index])
  # (duplicated_indices <- unique(s2_table$name[duplicated(s2_table$name)]))
  # removing indices with incorrect formulas
  n_index_toremove <- c(
    n_index_toremove,
    s2_table[name %in% c(
      "CRI550","CRI700","GEMI","IR550","IR700","LWCI","mCRIG","mCRIRE","CCCI","Ctr6",
      "ND800:680","NLI","RARSa1","RARSa2","RARSa3","RARSa4","RARSc3","RARSc4",
      "mARI","NDVIc","RSR","SRSWIRI:NIR","SARVI","SQRT(IR:R)","TNDVI"
    ),n_index]) # TODO some indices can be reintegrated
  # clean
  n_index_toremove <- sort(as.integer(n_index_toremove))
  s2_formula_mathml <- s2_formula_mathml[!s2_table$n_index %in% n_index_toremove]
  s2_formula_mathml_general <- s2_formula_mathml_general[!s2_table$n_index %in% n_index_toremove]
  s2_table <- s2_table[!n_index %in% n_index_toremove,]
  
  
  ## Convert MathML to LaTeX on each row, using external tool
  parent_regex <- "\\{((?>[^{}]+)|(?R))*\\}"
  max_iter = 7 # maximum numbero of iterations for nested fractions
  
  for (sel_row in seq_len(nrow(s2_table))) {
    
    
    saveXML(s2_formula_mathml[[sel_row]],
            tmp_infile <- tempfile())
    
    system(
      paste0(
        Sys.which("xsltproc")," ",
        file.path(xslt_path,"mmltex.xsl")," ",
        "\"",tmp_infile,"\" > ",
        "\"",tmp_outfile <- tempfile(),"\""),
      intern = Sys.info()["sysname"] == "Windows"
    )
    
    # convert manually from latex to formula
    tmp_latex <- suppressWarnings(readLines(tmp_outfile))
    tmp_latex <- gsub("^\\$ *(.*) *\\$$","\\1",tmp_latex) # remove math symbols
    tmp_latex <- gsub("\\\\textcolor\\[rgb\\]\\{[0-9\\.\\,]+\\}", "\\\\var", tmp_latex) # RGB indications are variable names
    tmp_latex <- gsub(paste0("\\\\mathrm",parent_regex), "\\1", tmp_latex, perl=TRUE) # remove mathrm
    tmp_latex <- gsub("\\\\left\\|([^|]+)\\\\right\\|", "abs(\\1)", tmp_latex) # abs
    tmp_latex <- gsub("\u00B7", "*", tmp_latex) # replace muddle point
    tmp_latex <- gsub("\\\\times", "*", tmp_latex) # replace times
    tmp_latex <- gsub("\\\\&InvisibleTimes;", "*", tmp_latex) # remove invisibles multiplications
    tmp_latex <- gsub("\u0096", "-band_", tmp_latex) # unicode START OF GUARDED AREA as "-"
    tmp_latex <- gsub("\\\\var\\{([0-9][0-9a]?)\\}", "band\\_\\1", tmp_latex) # recognise band names
    tmp_latex <- gsub("\\\\var\\{([^}]+)\\}", "par\\_\\1", tmp_latex) # recognise other elements as parameters
    tmp_latex <- gsub("par\\_([^0-9A-Za-z])", "\\1", tmp_latex) # error in two indices
    tmp_latex <- gsub("\\\\left\\(", "(", tmp_latex) # parenthesis
    tmp_latex <- gsub("\\\\right\\)", ")", tmp_latex) # parenthesis
    
    # remove temporary files
    unlink(tmp_infile)
    unlink(tmp_outfile)
    
    n_iter <- 1
    while (length(grep("[{}]", tmp_latex))>0 & n_iter<=max_iter) {
      tmp_latex <- gsub(paste0("\\\\frac",parent_regex,parent_regex), "(\\1)/(\\2)", tmp_latex, perl=TRUE) # convert fractions
      tmp_latex <- gsub(paste0("\\\\sqrt",parent_regex), "sqrt(\\1)", tmp_latex, perl=TRUE) # convert sqrt
      tmp_latex <- gsub(paste0(parent_regex,"\\^",parent_regex),"power\\(\\1,\\2\\)", tmp_latex, perl=TRUE) # square
      n_iter <- n_iter+1
    }
    
    s2_table[sel_row,"s2_formula"] <- tmp_latex
    # print(sel_row)
    
  }
  
  # last manual corrections on names
  s2_table[,s2_formula:=gsub("par\\_([0-9])", "band_\\1", s2_table$s2_formula)] # some bands were wrongly classified as parameters
  s2_table$name[s2_table$name=="TCI"] <- "TCIdx" # in order not to mess with TCI True Color Image product
  s2_table$name[s2_table$name=="NDSI"] <- "NDSaI" # in order not to mess with Normalized Difference Snow Index
  
  # last manual corrections on formulas
  s2_table[name=="ARVI", s2_formula := gsub("band_8a", "band_8", s2_formula)] # revert manual change on IDB
  s2_table[name=="WDRVI", s2_formula := gsub("0.1", "par_a", s2_formula)] # set 0.1 as parameter
  
  # rename parameters (A, B, ...)
  s2_table[,s2_formula:=gsub("par\\_([aALyY]r?)", "par_a", s2_table$s2_formula)] # first parameters (a, A, ar, y, Y, L) -> "a"
  s2_table[,s2_formula:=gsub("par\\_([bB])", "par_b", s2_table$s2_formula)] # second parameters (b, B) -> "b"
  s2_table[,s2_formula:=gsub("par\\_([X])", "par_c", s2_table$s2_formula)] # third parameters ("X") -> "c"
  
  ## Test expressions
  # build a data.frame with random values
  test_df <- runif(17,0,1)
  names(test_df) <- c(paste0("band_",c(1:12,"8a")),"par_a","par_b","par_c","par_d")
  test_df <- as.data.frame(t(test_df))
  # define power() as in numpy
  power <- function(x,y){x^y}
  
  test_results <-with(test_df,
                      sapply(s2_table$s2_formula,
                             function(x) {
                               tryCatch(eval(parse(text=x)),
                                        error = function(y){return(y)},
                                        warning = function(y){return(y)})
                             }
                      ))
  test_type <-with(test_df,
                   sapply(s2_table$s2_formula,
                          function(x) {
                            tryCatch(ifelse(is.numeric(eval(parse(text=x))),return("ok")),
                                     error = function(y){return("error")},
                                     warning = function(y){return("warning")})
                          }
                   ))
  test_out <- data.table("formula"=s2_table$s2_formula,
                         "n_index"=s2_table$n_index,
                         "index"=s2_table$name,
                         "output"=ifelse(test_type=="ok",test_results,NA),
                         "type"=test_type)
  
  # # These indices contain errors:
  # test_out[type=="error",]
  # # for now, remove them.
  # # TODO check them and correct manually
  # # TODO2 check all the aoutmatic parsings (maybe expression do not provide errors but they are different from originals)
  n_index_toremove <- test_out[type%in%c("error","warning"),n_index]
  s2_formula_mathml <- s2_formula_mathml[!s2_table$n_index %in% n_index_toremove]
  s2_formula_mathml_general <- s2_formula_mathml_general[!s2_table$n_index %in% n_index_toremove]
  s2_table <- s2_table[!n_index %in% n_index_toremove,]
  
  
  ## Check indices manually
  # (this is necessary because most of the indices is associated to wrong
  # Sentinel-2 bands, and because parameter values are missing)
  # logical: FALSE for not checked, TRUE for checked
  s2_table$checked <- FALSE
  # numerics: values for index parameters
  s2_table$d <- s2_table$c <- s2_table$b <- s2_table$a <- as.numeric(NA)
  
  # by default, make all these changes
  # (only bands named as "RED", "BLUE" and "NIR" are changed, because
  # these are the wrong ones, while normally bands named in other ways
  # - like "700nm" - are correctly associated)
  s2_table[grepl("RED",s2_formula_mathml_general),
           s2_formula := gsub("band_5","band_4",s2_formula)] # B5 to B4 (Red)
  s2_table[grepl("NIR",s2_formula_mathml_general),
           s2_formula := gsub("band_9","band_8",s2_formula)] # B9 to B8 (NIR)
  s2_table[grepl("BLUE",s2_formula_mathml_general),
           s2_formula := gsub("band_1","band_2",s2_formula)] # B2 to B1 (Blue)
  
  # set as checked for indices ok after previous changes
  s2_table[name %in% c(
    "NDVI","SAVI","MCARI","MCARI2","TCARI","ARVI","NDRE",
    "BNDVI","GNDVI","NDII","TCIdx","MSAVI2","OSAVI",
    "NBR","NDMI","WDRVI",#"EVI2",
    "SIPI1", "PSSRb1", "NDII", "MSI", "EVI", "Chlred-edge", "ARI", # sentinel-hub
    "MTVI2","MCARI-MTVI2","TCARI-OSAVI"
  ),checked:=TRUE]
  
  # set default parameter values
  s2_table[name=="SAVI", a:=0.5] # default value for L (here "a") parameter
  s2_table[name=="ARVI", a:=1] # default value for gamma (here "a") parameter
  s2_table[name=="WDRVI", a:=0.1] # default value for weighting coefficient "a" (0.1-0.2)
  
  # add missing indices
  s2_table_new <- rbindlist(list(
    "NDFI" = data.frame(
      n_index = 301,
      longname = "Normalized Difference Flood Index B1B7",
      name = "NDFI",
      link = "https://doi.org/10.1371/journal.pone.0088741",
      s2_formula = "(band_4-band_12)/(band_4+band_12)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">RED</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">SWIR2</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">RED</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">SWIR2</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NDFI2" = data.frame(
      n_index = 302,
      longname = "Normalized Difference Flood Index B1B6",
      name = "NDFI2",
      link = "https://doi.org/10.1371/journal.pone.0088741",
      s2_formula = "(band_4-band_11)/(band_4+band_11)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">RED</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">RED</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NDSI" = data.frame(
      n_index = 303,
      longname = "Normalize Difference Snow Index",
      name = "NDSI",
      link = "https://doi.org/10.1007/978-90-481-2642-2_376",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">GREEN</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">GREEN</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      s2_formula = "(band_3-band_11)/(band_3+band_11)",
      checked = TRUE
    ),
    "NBR2" = data.frame(
      n_index = 304,
      longname = "Normalized Burn Ratio 2",
      name = "NBR2",
      link = "https://landsat.usgs.gov/sites/default/files/documents/si_product_guide.pdf",
      s2_formula = "(band_11-band_12)/(band_11+band_12)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">SWIR2</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">SWIR2</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "MIRBI" = data.frame(
      n_index = 305,
      longname = "Mid-Infrared Burn Index",
      name = "MIRBI",
      link = "https://doi.org/10.1080/01431160110053185",
      s2_formula = "(1E-3*band_12)-(9.8E-4*band_11)+2E-4",
      checked = TRUE
    ),
    "CSI" = data.frame(
      n_index = 306,
      longname = "Char Soil Index",
      name = "CSI",
      link = "https://doi.org/10.1016/j.rse.2005.04.014",
      s2_formula = "(band_8)/(band_12)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">NIR</mi>\n      </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">SWIR</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "CRred" = data.frame(
      n_index = 307,
      longname = "Continuum Removal in the red",
      name = "CRred",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip((band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = TRUE
    ),
    "CRred-2A" = data.frame(
      n_index = 308,
      longname = "Continuum Removal in the red (Sentinel-2A reflectances)",
      name = "CRred-2A",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip((band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((664.6-559.8)/(740.5-559.8)) # reflectances for S2A
    ),
    "CRred-2B" = data.frame(
      n_index = 309,
      longname = "Continuum Removal in the red (Sentinel-2B reflectances)",
      name = "CRred-2B",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip((band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((664.9-559.0)/(739.1-559.0)) # reflectances for S2B
    ),
    "CRred-0" = data.frame(
      n_index = 310,
      longname = "Continuum Removal in the red (standard reflectances)",
      name = "CRred-0",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip((band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((665-560)/(740-560)) # standard reflectances
    ),
    "BDred" = data.frame(
      n_index = 311,
      longname = "Band Depth in the red",
      name = "BDred",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip(1-(band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = TRUE
    ),
    "BDred-2A" = data.frame(
      n_index = 312,
      longname = "Band Depth in the red (Sentinel-2A reflectances)",
      name = "BDred-2A",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip(1-(band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((664.6-559.8)/(740.5-559.8)) # reflectances for S2A
    ),
    "BDred-2B" = data.frame(
      n_index = 313,
      longname = "Band Depth in the red (Sentinel-2B reflectances)",
      name = "BDred-2B",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip(1-(band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((664.9-559.0)/(739.1-559.0)) # reflectances for S2B
    ),
    "BDred-0" = data.frame(
      n_index = 314,
      longname = "Band Depth in the red (standard reflectances)",
      name = "BDred-0",
      link = "Panigada et al. 2019 (in press)",
      s2_formula = "clip(1-(band_4)/(band_3+par_a*(band_6-band_3)),0,1)",
      checked = FALSE,
      a = ((665-560)/(740-560)) # standard reflectances
    ),
    "CRred2" = data.frame(
      n_index = 315,
      longname = "Continuum Removal in the red 2",
      name = "CRred2",
      link = "",
      s2_formula = "clip((((par_b-par_a)*(band_4+band_3)+(par_c-par_b)*(band_5+band_4)+(par_d-par_c)*(band_6+band_5))/((par_d-par_a)*(band_6+band_3))),0,1)",
      checked = FALSE
    ),
    "CRred2-2A" = data.frame(
      n_index = 316,
      longname = "Continuum Removal in the red 2 (Sentinel-2A reflectances)",
      name = "CRred2-2A",
      link = "",
      s2_formula = "clip((((par_b-par_a)*(band_4+band_3)+(par_c-par_b)*(band_5+band_4)+(par_d-par_c)*(band_6+band_5))/((par_d-par_a)*(band_6+band_3))),0,1)",
      checked = FALSE,
      a = 559.8, b = 664.6, c = 704.1, d = 740.5 # reflectances for S2A
    ),
    "CRred2-2B" = data.frame(
      n_index = 317,
      longname = "Continuum Removal in the red 2 (Sentinel-2B reflectances)",
      name = "CRred2-2B",
      link = "",
      s2_formula = "clip((((par_b-par_a)*(band_4+band_3)+(par_c-par_b)*(band_5+band_4)+(par_d-par_c)*(band_6+band_5))/((par_d-par_a)*(band_6+band_3))),0,1)",
      checked = FALSE,
      a = 559.0, b = 664.9, c = 703.8, d = 739.1 # reflectances for S2B
    ),
    "CRred2-0" = data.frame(
      n_index = 318,
      longname = "Continuum Removal in the red 2 (standard reflectances)",
      name = "CRred2-0",
      link = "",
      s2_formula = "clip((((par_b-par_a)*(band_4+band_3)+(par_c-par_b)*(band_5+band_4)+(par_d-par_c)*(band_6+band_5))/((par_d-par_a)*(band_6+band_3))),0,1)",
      checked = FALSE,
      a = 560, b = 665, c = 704, d = 740 # standard reflectances
    ),
    "NDWI" = data.frame(
      n_index = 319,
      longname = "Normalized Difference Water Index",
      name = "NDWI",
      link = "https://www.sentinel-hub.com/eoproducts/ndwi-normalized-difference-water-index",
      s2_formula = "(band_8-band_11)/(band_8+band_11)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">NIR</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">NIR</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NDWI2" = data.frame(
      n_index = 320,
      longname = "Normalized Difference Water Index 2",
      name = "NDWI2",
      link = "https://www.tandfonline.com/doi/abs/10.1080/01431169608948714",
      s2_formula = "(band_3-band_8)/(band_3+band_8)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">GREEN</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">NIR</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">GREEN</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">NIR</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NDVIre" = data.frame(
      n_index = 321,
      longname = "Red-edge-based Normalized Difference Vegetation Index",
      name = "NDVIre",
      link = "https://doi.org/10.1016/S0034-4257(03)00131-7",
      s2_formula = "(band_5-band_4)/(band_5+band_4)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">Rededge1</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">RED</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">Rededge1</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">RED</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NDBI" = data.frame(
      n_index = 322,
      longname = "Normalized Difference Built-up Index",
      name = "NDBI",
      link = "https://doi.org/10.1080/01431160304987",
      s2_formula = "(band_11-band_8)/(band_11+band_8)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n      <mo>-</mo>\n      <mi mathcolor=\"#443399\">NIR</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">SWIR1</mi>\n      <mo>+</mo>\n      <mi mathcolor=\"#443399\">NIR</mi>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "Rcc" = data.frame(
      n_index = 323,
      longname = "Red Chromatic Coordinate",
      name = "Rcc",
      link = "https://doi.org/10.1016/j.agrformet.2011.09.009",
      s2_formula = "band_4 / (band_2 + band_3 + band_4)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mi mathcolor=\"#443399\">RED</mi>\n   </mrow>\n   <mrow>\n    <mi mathcolor=\"#443399\">RED</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">GREEN</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">BLUE</mi>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "Gcc" = data.frame(
      n_index = 324,
      longname = "Green Chromatic Coordinate",
      name = "Gcc",
      link = "https://doi.org/10.1016/j.agrformet.2011.09.009",
      s2_formula = "band_3 / (band_2 + band_3 + band_4)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mi mathcolor=\"#443399\">GREEN</mi>\n   </mrow>\n   <mrow>\n    <mi mathcolor=\"#443399\">RED</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">GREEN</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">BLUE</mi>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "Bcc" = data.frame(
      n_index = 325,
      longname = "Blue Chromatic Coordinate",
      name = "Bcc",
      link = "https://doi.org/10.1016/j.agrformet.2011.09.009",
      s2_formula = "band_2 / (band_2 + band_3 + band_4)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mi mathcolor=\"#443399\">BLUE</mi>\n   </mrow>\n   <mrow>\n    <mi mathcolor=\"#443399\">RED</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">GREEN</mi>\n    <mo>+</mo>\n    <mi mathcolor=\"#443399\">BLUE</mi>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "ExG" = data.frame(
      n_index = 326,
      longname = "Excess Green",
      name = "ExG",
      link = "https://doi.org/10.1016/j.agrformet.2011.09.009",
      s2_formula = "2 * band_3 - (band_2 + band_4)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mn>2</mn>\n  <mo>&amp;InvisibleTimes;</mo>\n  <mi mathcolor=\"#443399\">GREEN</mi>\n  <mo>-</mo>\n  <mo>(</mo>\n  <mi mathcolor=\"#443399\">RED</mi>\n  <mo>+</mo>\n  <mi mathcolor=\"#443399\">BLUE</mi>\n  <mo>)</mo>\n </mrow>\n</math>",
      checked = TRUE,
      a = NA, b = NA, x = NA
    ),
    "NMDI" = data.frame(
      n_index = 327,
      longname = "Normalized Multi-band Drought Index",
      name = "NMDI",
      link = "https://doi.org/10.1029/2007GL031021",
      s2_formula = "(band_8 - band_11 + band_12) / (band_8 + band_11 - band_12)",
      s2_formula_mathml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\n <mrow>\n  <mfrac>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">NIR</mi>\n      <mo>-</mo>\n      <mrow>\n       <mo>(</mo>\n       <mrow>\n        <mrow>\n         <mi mathcolor=\"#443399\">SWIR1</mi>\n         <mo>-</mo>\n         <mi mathcolor=\"#443399\">SWIR2</mi>\n        </mrow>\n       </mrow>\n       <mo>)</mo>\n      </mrow>\n     </mrow>\n    </mrow>\n   </mrow>\n   <mrow>\n    <mrow>\n     <mrow>\n      <mi mathcolor=\"#443399\">NIR</mi>\n      <mo>+</mo>\n      <mrow>\n       <mo>(</mo>\n       <mrow>\n        <mrow>\n         <mi mathcolor=\"#443399\">SWIR1</mi>\n         <mo>-</mo>\n         <mi mathcolor=\"#443399\">SWIR2</mi>\n        </mrow>\n       </mrow>\n       <mo>)</mo>\n      </mrow>\n     </mrow>\n    </mrow>\n   </mrow>\n  </mfrac>\n </mrow>\n</math>\n",
      checked = TRUE,
      a = NA, b = NA, x = NA
    )
  ), fill=TRUE)
  
  s2_table_new[,n_index:=as.integer(n_index)]
  s2_table_new[,longname:=as.character(longname)]
  s2_table_new[,name:=as.character(name)]
  s2_table_new[,link:=as.character(link)]
  s2_table_new[,s2_formula:=as.character(s2_formula)]
  s2_table_new[,s2_formula_mathml:=as.character(s2_formula_mathml)]
  s2_table <- rbind(s2_table, s2_table_new, fill=TRUE)
  
  # add empty elements in MathML formulas
  for (i in length(s2_formula_mathml) + seq_len(nrow(s2_table) - length(s2_formula_mathml))) {
    s2_formula_mathml[[i]] <- if (!is.na(s2_table$s2_formula_mathml[i])) {
      xmlRoot(
        htmlTreeParse(s2_table$s2_formula_mathml[i], useInternalNodes = FALSE)
      )[["body"]][["math"]]
    } else {
      NA
    }
    s2_formula_mathml_general[[i]] <- s2_formula_mathml[[i]]
  }
  
  
  ## Convert in JSON
  # convert MathML to character
  s2_table$s2_formula_mathml <- sapply(
    s2_formula_mathml_general, # replaced from s2_formula_mathml in order not to show uncorrect band numbers
    function(x) {
      if (is(x, "XMLNode")) {
        paste(capture.output(print(x)), collapse="\n")
      } else {
        ""
      }
    }
  )
  
  json_table <- list(
    "indices" = s2_table,
    "pkg_version" = as.character(packageVersion("sen2r")),
    "creation_date" = as.character(Sys.time())
  )
  writeLines(jsonlite::toJSON(json_table, digits=NA, pretty=TRUE), json_path)
  return(invisible(NULL))
}
