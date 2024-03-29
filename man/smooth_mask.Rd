% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/smooth_mask.R
\name{smooth_mask}
\alias{smooth_mask}
\title{Buffer cloud masks}
\usage{
smooth_mask(
  inmask,
  tmpdir = tempdir(),
  radius = 250,
  buffer = 250,
  namask = NULL,
  bigtiff = FALSE
)
}
\arguments{
\item{inmask}{The path of the input 0-1 mask (where 0 represents the area
to be masked, 1 the clean surface).}

\item{tmpdir}{(optional) Path where intermediate files (VRT) will be created.
Default is a temporary directory.}

\item{radius}{(optional) Numerical (positive): the size (in the unit of
\code{inmask}, typically metres) to be used as radius for the smoothing
(the higher it is, the more smooth the output mask will result).}

\item{buffer}{(optional) Numerical (positive or negative): the size of the
buffer (in the unit of \code{inmask}, typically metres) to be applied to the
masked area after smoothing it (positive to enlarge, negative to reduce).}

\item{namask}{(optional) The path of an input 0-1 mask where 0 represents
the area of the original file with NA values (which should not be
smoothed / buffered).
Default (NULL) means that no NA values are present.}

\item{bigtiff}{(optional) Logical: if TRUE, the creation of a BigTIFF is
forced (default is FALSE).}
}
\value{
The path of the smoothed mask.
}
\description{
Internal function (used by \link{s2_mask}) which smooths
and buffers a 0-1 mask image in order to reduce the roughness of the mask
obtained from SCL classification (which is done pixel by pixel).
See details.
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
Luigi Ranghetti, phD (2019)
}
\keyword{internal}
