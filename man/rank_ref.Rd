% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/taxize-package.R
\docType{data}
\name{rank_ref}
\alias{rank_ref}
\title{Lookup-table for IDs of taxonomic ranks}
\description{
data.frame of 42 rows, with 2 columns:
\itemize{
 \item rankid - a numeric rank id, consecutive
 \item ranks - a comma separated vector of names that are considered
 equal to one another within the row
}
}
\details{
We use this data.frame to do data sorting/filtering based on the ordering
of ranks.

Please let us know if there is a rank that occurs from one of the data
sources \pkg{taxize} that we don't have in \code{rank_ref} dataset.

Let us know if you disagree with the ordering of ranks.
}
\keyword{data}
