% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getkey.R
\name{getkey}
\alias{getkey}
\alias{taxize-authentication}
\title{Function to get API key.}
\usage{
getkey(x = NULL, service)
}
\arguments{
\item{x}{(character) An API key, defaults to \code{NULL}}

\item{service}{(character) The API data provider, used to match to
default guest key (for Tropicos and EOL; there's no guest
key for NCBI or IUCN, for which you have to get your own)}
}
\description{
Checks first to get key from your .Rprofile or .Renviron (or similar) file.
See Details.
}
\details{
Get help for getting and saving your keys via \code{\link{key_helpers}}.
Save your API keys with the following names:
\itemize{
 \item Tropicos: R option or env var as 'TROPICOS_KEY'
 \item EOL: R option or env var as 'EOL_KEY'
 \item IUCN: R option or env var as 'IUCN_REDLIST_KEY'
 \item ENTREZ: R option or env var as 'ENTREZ_KEY'
}
 as R options in your \code{.Rprofile} file, or
as environment variables in either your \code{.Renviron} file or
\code{.bash_profile} file, or \code{.zshrc} file (if you use oh-my-zsh) or
similar. See \code{\link{Startup}} for help on R options and environment
variables.

Remember to restart your R session (and to start a new shell window/tab
if you're using the shell) to take advantage of the new R options
or environment variables.

We strongly recommend using environment variables over R options.

Note that NCBI Entrez doesn't require that you use an API key,
but you should get higher rate limit with a key,
from 3 to 10 requests per second, so do get one.
}
\examples{
\dontrun{
getkey(service="tropicos")
getkey(service="eol")
getkey(service="iucn")
getkey(service="entrez")
}
}
