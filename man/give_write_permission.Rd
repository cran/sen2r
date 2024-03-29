% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/give_write_permission.R
\name{give_write_permission}
\alias{give_write_permission}
\title{Give permission to write settings on disk}
\usage{
give_write_permission(agree = NA)
}
\arguments{
\item{agree}{Logical: if TRUE, allow creating the hidden directory;
if FALSE, do not allow it; if NA (default), the permission is asked to
the user in interactive mode (in non-interactive mode, the permission is
denied).}
}
\value{
Logical: if TRUE, R was authorised saving in the directory;
if FALSE, it was not and a temporary directory is being used.
}
\description{
In interactive mode, ask users for permission to create a
.sen2r settings directory, in which to store files required by the packages.
The function can be used also in non-interactive mode by setting
\code{agree = TRUE}.
The function has no effect if the directory already exists.
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
Lorenzo Busetto, phD (2019)

Luigi Ranghetti, phD (2019)
}
\keyword{internal}
