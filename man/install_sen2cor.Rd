% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/install_sen2cor.R
\name{install_sen2cor}
\alias{install_sen2cor}
\alias{link_sen2cor}
\title{Download and install (or link) Sen2Cor}
\usage{
install_sen2cor(sen2cor_dir = NA, version = "2.5.5", force = FALSE)

link_sen2cor(sen2cor_dir)
}
\arguments{
\item{sen2cor_dir}{Path where sen2cor will be installed or searched
(by default it is a subdirectory \code{"sen2cor"} of the default sen2r directory).}

\item{version}{(optional) Character: Sen2Cor version (one among
'2.5.5' - default - and '2.8.0').}

\item{force}{(optional) Logical: if TRUE, installs sen2cor even if it is already
found in sen2cor_dir (default is FALSE).}
}
\value{
NULL (the function is called for its side effects)
}
\description{
\code{\link[=install_sen2cor]{install_sen2cor()}} downloads and installs a standalone version of
\href{https://step.esa.int/main/snap-supported-plugins/sen2cor/}{Sen2Cor}.

\code{link_sen2cor()} links an existing standalone version of
\href{https://step.esa.int/main/snap-supported-plugins/sen2cor/}{Sen2Cor} to sen2r.
}
\note{
License: GPL 3.0
}
\examples{
\dontrun{
install_sen2cor(sen2cor_dir = tempdir())
# ( use a non-temporary folder path instead of tempdir() )
}
}
\references{
L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
"sen2r": An R toolbox for automatically downloading and preprocessing
Sentinel-2 satellite data. \emph{Computers & Geosciences}, 139, 104473.
\doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
}
\author{
Luigi Ranghetti, phD (2019)
}
