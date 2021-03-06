#' Get the EOL ID from Encyclopedia of Life from taxonomic names.
#'
#' Note that EOL doesn't expose an API endpoint for directly querying for EOL
#' taxon ID's, so we first use the function \code{\link[taxize]{eol_search}}
#' to find pages that deal with the species of interest, then use
#' \code{\link[taxize]{eol_pages}} to find the actual taxon IDs.
#'
#' @export
#' @param sciname character; scientific name.
#' @param ask logical; should get_eolid be run in interactive mode?
#' If TRUE and more than one ID is found for the species, the user is asked for
#' input. If FALSE NA is returned for multiple matches.
#' @param key API key. passed on to \code{\link{eol_search}} and
#' \code{\link{eol_pages}} internally
#' @param ... Further args passed on to \code{\link{eol_search}}
#' @param messages logical; If \code{TRUE} the actual taxon queried is printed
#' on the console.
#' @param rows numeric; Any number from 1 to infinity. If the default NA, all
#' rows are considered. Note that this function still only gives back a eolid
#' class object with one to many identifiers. See
#' \code{\link[taxize]{get_eolid_}} to get back all, or a subset, of the raw
#' data that you are presented during the ask process.
#' @param x Input to \code{\link{as.eolid}}
#' @param check logical; Check if ID matches any existing on the DB, only
#' used in \code{\link{as.eolid}}
#' @template getreturn
#' 
#' @section Authentication:
#' See \code{\link{taxize-authentication}} for help on authentication
#'
#' @family taxonomic-ids
#' @seealso \code{\link[taxize]{classification}}
#'
#' @author Scott Chamberlain, \email{myrmecocystus@@gmail.com}
#'
#' @details EOL is a bit odd in that they have page IDs for each taxon, but
#' then within that, they have taxon ids for various taxa within that page
#' (e.g., GBIF and NCBI each have a taxon they refer to within the
#' page [i.e., taxon]). And we need the taxon ids from a particular data
#' provider (e.g, NCBI) to do other things, like get a higher classification
#' tree. However, humans want the page id, not the taxon id. So, the
#' id returned from this function is the taxon id, not the page id. You can
#' get the page id for a taxon by using \code{\link{eol_search}} and
#' \code{\link{eol_pages}}, and the URI returned in the attributes for a
#' taxon will lead you to the taxon page, and the ID in the URL is the
#' page id.
#'
#' @examples \dontrun{
#' get_eolid(sciname='Pinus contorta')
#' get_eolid(sciname='Puma concolor')
#'
#' get_eolid(c("Puma concolor", "Pinus contorta"))
#'
#' # specify rows to limit choices available
#' get_eolid('Poa annua')
#' get_eolid('Poa annua', rows=1)
#' get_eolid('Poa annua', rows=2)
#' get_eolid('Poa annua', rows=1:2)
#'
#' # When not found
#' get_eolid(sciname="uaudnadndj")
#' get_eolid(c("Chironomus riparius", "uaudnadndj"))
#'
#' # Convert a eolid without class information to a eolid class
#' # already a eolid, returns the same
#' as.eolid(get_eolid("Chironomus riparius"))
#' # same
#' as.eolid(get_eolid(c("Chironomus riparius","Pinus contorta")))
#' # numeric
#' as.eolid(10247706)
#' # numeric vector, length > 1
#' as.eolid(c(24954444,51389511,57266265))
#' # character
#' as.eolid("24954444")
#' # character vector, length > 1
#' as.eolid(c("24954444","51389511","57266265"))
#' # list, either numeric or character
#' as.eolid(list("24954444","51389511","57266265"))
#' ## dont check, much faster
#' as.eolid("24954444", check=FALSE)
#' as.eolid(24954444, check=FALSE)
#' as.eolid(c("24954444","51389511","57266265"), check=FALSE)
#' as.eolid(list("24954444","51389511","57266265"), check=FALSE)
#'
#' (out <- as.eolid(c(24954444,51389511,57266265)))
#' data.frame(out)
#' as.eolid( data.frame(out) )
#'
#' # Get all data back
#' get_eolid_("Poa annua")
#' get_eolid_("Poa annua", rows=2)
#' get_eolid_("Poa annua", rows=1:2)
#' get_eolid_(c("asdfadfasd", "Pinus contorta"))
#' }

get_eolid <- function(sciname, ask = TRUE, messages = TRUE, key = NULL,
                      rows = NA, ...){

  assert(ask, "logical")
  assert(messages, "logical")

  fun <- function(sciname, ask, messages, rows, ...) {
    direct <- FALSE
    mssg(messages, "\nRetrieving data for taxon '", sciname, "'\n")
    tmp <- eol_search(terms = sciname, key = key, ...)
    ms <- "Not found. Consider checking the spelling or alternate classification"
    datasource <- NA_character_
    if (all(is.na(tmp))) {
      mssg(messages, ms)
      id <- NA_character_
      page_id <- NA_character_
      att <- "not found"
      mm <- FALSE
    } else {
      pageids <- tmp[grep(tolower(sciname), tolower(tmp$name)), "pageid"]

      if (length(pageids) == 0) {
        if (nrow(tmp) > 0)
        mssg(messages, paste(ms, sprintf('\nDid find: %s',
                                        paste(tmp$name, collapse = "; "))))
        id <- NA_character_
      } else {
        dfs <- lapply(pageids, function(x) {
          y <- tryCatch(eol_pages(x, key = key), error = function(e) e)
          if (is(y, "error")) NULL else y$scinames
        })
        names(dfs) <- pageids
        dfs <- tc(dfs)
        if (length(dfs) > 1) dfs <- dfs[!sapply(dfs, nrow) == 0]
        df <- ldply(dfs)
        df <- rename(df, c('.id' = 'pageid', 'identifier' = 'eolid',
                     'scientificname' = 'name', 'nameaccordingto' = 'source',
                     'taxonrank' = 'rank'))
        df <- getsourceshortnames(df)
        df$source <- as.character(df$source)
        # drop columns
        df$canonicalform <- df$sourceidentifier <- NULL
        mm <- NROW(df) > 1
        df <- sub_rows(df, rows)

        if (nrow(df) == 0) {
          mssg(messages, ms)
          id <- NA_character_
          page_id <- NA_character_
        } else{
          id <- df$eolid
        }
        names(id) <- df$pageid
      }
    }

    # not found on eol
    if (length(id) == 0 || all(is.na(id))) {
      mssg(messages, ms)
      id <- NA_character_
      page_id <- NA_character_
			mm <- FALSE
      att <- 'not found'
    }
    # only one found on eol
    if (length(id) == 1 & !all(is.na(id))) {
      id <- df$eolid
      page_id <- df$pageid
      datasource <- df$source
      direct <- TRUE
      att <- 'found'
    }
    # more than one found on eol -> user input
    if (length(id) > 1) {
      if (ask) {
        rownames(df) <- 1:nrow(df)
        # prompt
        message("\n\n")
        message("\nMore than one eolid found for taxon '", sciname, "'!\n
            Enter rownumber of taxon (other inputs will return 'NA'):\n")
        print(df)
        take <- scan(n = 1, quiet = TRUE, what = 'raw')

        if (length(take) == 0) {
          take <- 'notake'
        }
        if (take %in% seq_len(nrow(df))) {
          take <- as.numeric(take)
          message("Input accepted, took eolid '",
                  as.character(df$eolid[take]), "'.\n")
          id <- as.character(df$eolid[take])
          names(id) <- as.character(df$pageid[take])
          page_id <- as.character(df$pageid[take])
          datasource <- as.character(df$source[take])
          att <- 'found'
        } else {
          id <- NA_character_
          page_id <- NA_character_
          att <- 'not found'
          mssg(messages, "\nReturned 'NA'!\n\n")
        }
      } else {
        if (length(id) != 1) {
          warning(
            sprintf("More than one eolid found for taxon '%s'; refine query or set ask=TRUE",
                    sciname),
            call. = FALSE
          )
          id <- NA_character_
          page_id <- NA_character_
          att <- 'NA due to ask=FALSE & > 1 result'
        }
      }
    }
    list(id = as.character(id), page_id = page_id, source = datasource,
         att = att, multiple = mm, direct = direct)
  }
  sciname <- as.character(sciname)
  out <- lapply(sciname, fun, ask = ask, messages = messages, rows = rows, ...)
  ids <- unname(sapply(out, "[[", "id"))
  sources <- pluck(out, "source", "")
  ids <- structure(ids, class = "eolid", provider = sources,
                   match = pluck(out, "att", ""),
                   multiple_matches = pluck(out, "multiple", logical(1)),
                   pattern_match = pluck(out, "direct", logical(1)))
  page_ids <- unlist(pluck(out, 'page_id'))
  add_uri(ids, 'http://eol.org/pages/%s/overview', page_ids)
}

getsourceshortnames <- function(input) {
  lookup <- data.frame(
    z = c('COL','ITIS','GBIF','NCBI','IUCN','EOL','INAT','UKSL',
      'USDA','NPSL','SPSL'),
    b = c(
      'Species 2000 & ITIS Catalogue of Life: April 2013',
      'Integrated Taxonomic Information System (ITIS)',
      'GBIF Nub Taxonomy',
      'NCBI Taxonomy',
      'IUCN Red List (Species Assessed for Global Conservation)',
      'EOL Dynamic Hierarchy',
      'iNaturalist',
      'United Kingdom Species List',
      'USDA Plants data',
      'North Pacific Species List',
      'South Pacific Species List'
    ),
  stringsAsFactors = FALSE)
  bb <- merge(input, lookup, by.x = "source", by.y = "b")[, -1]
  taxize_sort_df(rename(bb, c('z' = 'source')), "name")
}

taxize_sort_df <- function(data, vars = names(data)) {
  if (length(vars) == 0 || is.null(vars))
    return(data)
  data[do.call("order", data[, vars, drop = FALSE]), , drop = FALSE]
}

#' @export
#' @rdname get_eolid
as.eolid <- function(x, check=TRUE) {
  UseMethod("as.eolid")
}

#' @export
#' @rdname get_eolid
as.eolid.eolid <- function(x, check=TRUE) {
  x
}

#' @export
#' @rdname get_eolid
as.eolid.character <- function(x, check=TRUE) {
  if (length(x) == 1) {
    make_eolid(x, check)
  } else {
    collapse(x, fxn = make_eolid, class = "eolid", check = check)
  }
}

#' @export
#' @rdname get_eolid
as.eolid.list <- function(x, check=TRUE) {
  if (length(x) == 1) {
    make_eolid(x, check)
  } else {
    collapse(x, make_eolid, "eolid", check = check)
  }
}

#' @export
#' @rdname get_eolid
as.eolid.numeric <- function(x, check=TRUE) {
  as.eolid(as.character(x), check)
}

#' @export
#' @rdname get_eolid
as.eolid.data.frame <- function(x, check=TRUE) {
  structure(x$ids, class = "eolid", match = x$match,
            multiple_matches = x$multiple_matches,
            pattern_match = x$pattern_match, uri = x$uri)
}

#' @export
#' @rdname get_eolid
as.data.frame.eolid <- function(x, ...){
  data.frame(ids = as.character(unclass(x)),
             class = "eolid",
             match = attr(x, "match"),
             multiple_matches = attr(x, "multiple_matches"),
             pattern_match = attr(x, "pattern_match"),
             uri = attr(x, "uri"),
             stringsAsFactors = FALSE)
}

make_eolid <- function(x, check=TRUE) {
  tmp <- make_generic(x, 'http://eol.org/pages/%s/overview', "eolid", check)
  if (!check) {
    attr(tmp, "uri") <- NULL
  } else {
    z <- get_eol_pageid(x)
    if (!is.na(z)) {
      attr(tmp, "uri") <- sprintf('http://eol.org/pages/%s/overview', z)
    } else {
      attr(tmp, "uri") <- NULL
    }
  }
  tmp
}

check_eolid <- function(x){
  url <- sprintf("http://eol.org/api/hierarchy_entries/1.0/%s.json", x)
  tryid <- GET(url)
  if (tryid$status_code == 200) TRUE else FALSE
}

get_eol_pageid <- function(x){
  url <- sprintf("http://eol.org/api/hierarchy_entries/1.0/%s.json", x)
  tt <- GET(url)
  if (tt$status_code == 200) {
    jsonlite::fromJSON(con_utf8(tt), FALSE)$taxonConceptID
  } else {
    NA
  }
}

#' @export
#' @rdname get_eolid
get_eolid_ <- function(sciname, messages = TRUE, key = NULL, rows = NA, ...){
  stats::setNames(lapply(sciname, get_eolid_help, messages = messages,
                  key = key, rows = rows, ...), sciname)
}

get_eolid_help <- function(sciname, messages, key, rows, ...){
  mssg(messages, "\nRetrieving data for taxon '", sciname, "'\n")
  tmp <- eol_search(terms = sciname, key, ...)

  if (all(is.na(tmp))) {
    NULL
  } else {
    pageids <- tmp[grep(tolower(sciname), tolower(tmp$name)), "pageid"]
    if (length(pageids) == 0) {
      NULL
    } else {
      dfs <- lapply(pageids, function(x) {
        y <- tryCatch(eol_pages(x, key = key), error = function(e) e)
        if (inherits(y, "error")) NULL else y$scinames
      })
      names(dfs) <- pageids
      dfs <- tc(dfs)
      if (length(dfs) > 1) dfs <- dfs[!sapply(dfs, nrow) == 0]
      dfs <- ldply(dfs)
      df <- dfs[,c('.id','identifier','scientificname','nameaccordingto')]
      names(df) <- c('pageid','eolid','name','source')
      df <- getsourceshortnames(df)
      df$source <- as.character(df$source)
      if (NROW(df) == 0) NULL else sub_rows(df, rows)
    }
  }
}
