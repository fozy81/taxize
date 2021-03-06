#' Get the page name for a Wiki taxon
#'
#' @export
#' @param x (character) A vector of common or scientific names.
#' @param wiki_site (character) Wiki site. One of species (default), pedia,
#' commons
#' @param wiki (character) language. Default: en
#' @param ask logical; should get_wiki be run in interactive mode?
#' If \code{TRUE} and more than one wiki is found for the species, the user is
#' asked for input. If \code{FALSE} NA is returned for multiple matches.
#' @param verbose logical; should progress be printed?
#' @param rows numeric; Any number from 1 to infinity. If the default NA, all
#' rows are considered. Note that this function still only gives back a wiki
#' class object with one to many identifiers. See
#' \code{\link[taxize]{get_wiki_}} to get back all, or a subset, of the
#' raw data that you are presented during the ask process.
#' @param limit (integer) number of records to return
#' @param ... Ignored
#' @param check logical; Check if ID matches any existing on the DB, only
#' used in \code{\link{as.wiki}}
#' @template getreturn
#'
#' @details For \code{type = pedia}, we use the english language site by
#' default. Set the \code{language} parameter for a different language site.
#'
#' @family taxonomic-ids
#' @seealso \code{\link[taxize]{classification}}
#'
#' @examples \dontrun{
#' get_wiki(x = "Quercus douglasii")
#' get_wiki(x = "Quercu")
#' get_wiki(x = "Quercu", "pedia")
#' get_wiki(x = "Quercu", "commons")
#'
#' # diff. wikis with wikipedia
#' get_wiki("Malus domestica", "pedia")
#' get_wiki("Malus domestica", "pedia", "fr")
#'
#' # as coercion
#' as.wiki("Malus_domestica")
#' as.wiki("Malus_domestica", wiki_site = "commons")
#' as.wiki("Malus_domestica", wiki_site = "pedia")
#' as.wiki("Malus_domestica", wiki_site = "pedia", wiki = "fr")
#' as.wiki("Malus_domestica", wiki_site = "pedia", wiki = "da")
#' }

get_wiki <- function(x, wiki_site = "species", wiki = "en", ask = TRUE,
                     verbose = TRUE, limit = 100, rows = NA, ...) {

  assert(ask, "logical")
  assert(x, "character")
  assert(wiki_site, "character")
  assert(wiki, "character")
  assert(verbose, "logical")

  fun <- function(x, wiki_site, wiki, ask, verbose, limit, rows, ...) {
    direct <- FALSE
    mssg(verbose, "\nRetrieving data for taxon '", x, "'\n")
    df <- switch(
      wiki_site,
      species = wikitaxa::wt_wikispecies_search(query = x, limit = limit, ...),
      pedia = wikitaxa::wt_wikipedia_search(query = x, wiki = wiki,
                                            limit = limit, ...),
      commons = wikitaxa::wt_wikicommons_search(query = x, limit = limit, ...)
    )$query$search
    mm <- NROW(df) > 1

    if (!inherits(df, "tbl_df") || NROW(df) == 0) {
      id <- NA_character_
      att <- "not found"
    } else {
      df <- df[, c("title", "size", "wordcount")]
      df <- sub_rows(df, rows)

      # should return NA if spec not found
      if (NROW(df) == 0) {
        mssg(verbose, tx_msg_not_found)
        id <- NA_character_
        att <- 'not found'
      }

      df$title <- gsub("\\s", "_", df$title)

      # take the one wiki from data.frame
      if (NROW(df) == 1) {
        id <- df$title
        att <- 'found'
      }

      # check for direct match
      if (NROW(df) > 1) {
        df <- data.frame(df, stringsAsFactors = FALSE)

        direct <- match(tolower(df$title), gsub("\\s", "_", tolower(x)))

        if (length(direct) == 1) {
          if (!all(is.na(direct))) {
            id <- df$title[!is.na(direct)]
            direct <- TRUE
            att <- 'found'
          } else {
            direct <- FALSE
            id <- NA_character_
            att <- 'not found'
          }
        } else {
          direct <- FALSE
          id <- NA_character_
          att <- 'NA due to ask=FALSE & no direct match found'
          warning("> 1 result; no direct match found", call. = FALSE)
        }
      }

      # multiple matches
      if (any(
        NROW(df) > 1 && is.na(id) |
        NROW(df) > 1 && att == "found" && length(id) > 1
      )) {
        if (ask) {
          # user prompt
          df <- df[order(df$title), ]
          rownames(df) <- NULL

          # prompt
          message("\n\n")
          print(df)
          message("\nMore than one wiki ID found for taxon '", x, "'!\n
                  Enter rownumber of taxon (other inputs will return 'NA'):\n")
          take <- scan(n = 1, quiet = TRUE, what = 'raw')

          if (length(take) == 0) {
            take <- 'notake'
            att <- 'nothing chosen'
          }
          if (take %in% seq_len(nrow(df))) {
            take <- as.numeric(take)
            message("Input accepted, took taxon '",
                    as.character(df$title[take]), "'.\n")
            id <-  df$title[take]
            att <- 'found'
          } else {
            id <- NA_character_
            mssg(verbose, "\nReturned 'NA'!\n\n")
            att <- 'not found'
          }
        } else {
          if (length(id) != 1) {
            warning(
              sprintf("More than one wiki ID found for taxon '%s'; refine query or set ask=TRUE",
                      x),
              call. = FALSE
            )
            id <- NA_character_
            att <- 'NA due to ask=FALSE & > 1 result'
          }
        }
      }

    }

    data.frame(
      id = id,
      att = att,
      multiple = mm,
      direct = direct,
      stringsAsFactors = FALSE)
  }
  outd <- ldply(x, fun, wiki_site, wiki, ask, verbose, limit, rows, ...)
  out <- outd$id
  attr(out, 'match') <- outd$att
  attr(out, 'multiple_matches') <- outd$multiple
  attr(out, 'pattern_match') <- outd$direct
  attr(out, 'wiki_site') <- wiki_site
  attr(out, 'wiki_lang') <- wiki
  if ( !all(is.na(out)) ) {
    zz <- gsub("\\s", "_", na.omit(out))
    base_url <- switch(
      wiki_site,
      species = 'https://species.wikimedia.org/wiki/',
      pedia = sprintf('https://%s.wikipedia.org/wiki/', wiki),
      commons = 'https://commons.wikimedia.org/wiki/'
    )
    attr(out, 'uri') <- paste0(base_url, zz)
  }
  class(out) <- "wiki"
  return(out)
}

#' @export
#' @rdname get_wiki
as.wiki <- function(x, check=TRUE, wiki_site = "species", wiki = "en") {
  UseMethod("as.wiki")
}

#' @export
#' @rdname get_wiki
as.wiki.wiki <- function(x, check=TRUE, wiki_site = "species",
                         wiki = "en") x

#' @export
#' @rdname get_wiki
as.wiki.character <- function(x, check=TRUE, wiki_site = "species",
                              wiki = "en") {
  if (length(x) == 1) {
    make_wiki(x, check, wiki_site, wiki)
  } else {
    collapse(x, make_wiki, "wiki", check = check)
  }
}

#' @export
#' @rdname get_wiki
as.wiki.list <- function(x, check=TRUE, wiki_site = "species",
                         wiki = "en") {
  if (length(x) == 1) {
    make_wiki(x, check)
  } else {
    collapse(x, make_wiki, "wiki", check = check)
  }
}

#' @export
#' @rdname get_wiki
as.wiki.numeric <- function(x, check=TRUE, wiki_site = "species",
                            wiki = "en") {
  as.wiki(as.character(x), check)
}

#' @export
#' @rdname get_wiki
as.wiki.data.frame <- function(x, check=TRUE, wiki_site = "species",
                               wiki = "en") {

  structure(x$ids, class = "wiki", match = x$match,
            multiple_matches = x$multiple_matches,
            pattern_match = x$pattern_match,
            wiki_site = x$wiki_site,
            wiki_lang = x$wiki_lang, uri = x$uri)
}

#' @export
#' @rdname get_wiki
as.data.frame.wiki <- function(x, ...){
  data.frame(ids = unclass(x),
             class = "wiki",
             match = attr(x, "match"),
             multiple_matches = attr(x, "multiple_matches"),
             pattern_match = attr(x, "pattern_match"),
             wiki_site = attr(x, 'wiki_site'),
             wiki_lang = attr(x, 'wiki_lang'),
             uri = attr(x, "uri"),
             stringsAsFactors = FALSE)
}

make_wiki <- function(x, check = TRUE, wiki_site, wiki) {
  url <- switch(
    wiki_site,
    species = 'https://species.wikimedia.org/wiki/%s',
    pedia = paste0(sprintf('https://%s.wikipedia.org/wiki', wiki), "/%s"),
    commons = 'https://commons.wikimedia.org/wiki/%s'
  )
  make_wiki_generic(x, url, "wiki", check)
}

check_wiki <- function(x) {
  tt <- wikitaxa::wt_wiki_page(x)
  identical(tt$status_code, 200)
}

#' @export
#' @rdname get_wiki
get_wiki_ <- function(x, verbose = TRUE, wiki_site = "species",
                      wiki = "en", limit = 100, rows = NA, ...) {
  stats::setNames(
    lapply(x, get_wiki_help, verbose = verbose, wiki_site = wiki_site,
           wiki = wiki, limit = limit, rows = rows, ...),
    x
  )
}

get_wiki_help <- function(x, verbose, wiki_site = "species", wiki = "en",
                          limit = 100, rows, ...) {

  mssg(verbose, "\nRetrieving data for taxon '", x, "'\n")
  assert(x, "character")
  assert(wiki_site, "character")
  assert(wiki, "character")

  df <- switch(
    wiki_site,
    species = wikitaxa::wt_wikispecies_search(query = x, limit = limit, ...),
    pedia = wikitaxa::wt_wikipedia_search(query = x, wiki = wiki,
                                          limit = limit, ...),
    commons = wikitaxa::wt_wikicommons_search(query = x, limit = limit, ...)
  )$query$search

  if (!inherits(df, "tbl_df") || NROW(df) == 0) {
    NULL
  } else {
    df <- df[, c("title", "size", "wordcount")]
    sub_rows(df, rows)
  }
}
