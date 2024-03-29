% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tile_utmzone.R
\name{tile_utmzone}
\alias{tile_utmzone}
\title{Obtain the UTM zone associated to Sentinel-2 tiles}
\usage{
tile_utmzone(tile_id)
}
\arguments{
\item{tile_id}{Character: tile ID (5 chars), e.g. \code{"32TNR"} (multiple values
can be provided).}
}
\value{
A vector of the same length of \code{tile_id} with UTM zones (e.g. \verb{"32N}").
}
\description{
Internal function: convenience function to obtain the UTM zone
from tile IDs.
}
\note{
License: GPL 3.0
}
\references{
L. Ranghetti, M. Boschetti, F. Nutini, L. Busetto (2020).
"sen2r": An R toolbox for automatically downloading and preprocessing
Sentinel-2 satellite data. \emph{Computers & Geosciences}, 139, 104473.
\doi{10.1016/j.cageo.2020.104473}, URL: \url{https://sen2r.ranghetti.info/}.
}
\author{
Luigi Ranghetti, phD (2020)
}
\keyword{internal}
