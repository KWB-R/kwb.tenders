# Internal Chrome DevTools Protocol (chromote) helpers -------------------------
# The portal performs cross-origin SSO redirects that the higher-level selenider
# wrapper could not survive, so navigation/interaction is driven via chromote's
# CDP session directly (proven robust).

#' JS string literal (double-quoted, escaped)
#' @noRd
cdp_str <- function(x) {
  paste0('"', gsub('"', '\\\\"', gsub('\\\\', '\\\\\\\\', x)), '"')
}

#' Evaluate a JS expression in the page and return its value
#' @noRd
cdp_eval <- function(session, expr) {
  session$Runtime$evaluate(expr)$result$value
}

#' Navigate to `url` and wait a fixed number of seconds
#' @noRd
cdp_navigate <- function(session, url, wait = 4) {
  session$Page$navigate(url)
  Sys.sleep(wait)
  invisible(session)
}

#' Poll until `selector` is present; return TRUE/FALSE
#' @noRd
cdp_wait_for <- function(session, selector, timeout = 20, poll = 0.3) {
  t0 <- Sys.time()
  repeat {
    if (isTRUE(cdp_eval(session, sprintf("!!document.querySelector(%s)", cdp_str(selector))))) {
      return(TRUE)
    }
    if (as.numeric(difftime(Sys.time(), t0, units = "secs")) > timeout) return(FALSE)
    Sys.sleep(poll)
  }
}

#' Click the first present selector; return the clicked selector or `NA`
#' @noRd
cdp_click_first <- function(session, selectors) {
  arr <- paste(vapply(selectors, cdp_str, character(1)), collapse = ",")
  expr <- sprintf(
    "(function(){var s=[%s];for(var i=0;i<s.length;i++){var e=document.querySelector(s[i]);if(e){e.click();return s[i];}}return null;})()",
    arr
  )
  res <- cdp_eval(session, expr)
  if (is.null(res)) NA_character_ else res
}

#' Set an input value and dispatch input/change events
#' @noRd
cdp_set_value <- function(session, selector, value) {
  expr <- sprintf(
    "(function(){var e=document.querySelector(%s);if(!e)return false;e.focus();e.value=%s;e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return true;})()",
    cdp_str(selector), cdp_str(value)
  )
  isTRUE(cdp_eval(session, expr))
}

#' Read the ".browsePagesText" counter -> list(cur, max, total)
#' @noRd
cdp_read_counter <- function(session) {
  txt <- cdp_eval(session, sprintf(
    "(function(){var e=document.querySelector(%s);return e?e.innerText:'';})()",
    cdp_str(".browsePagesText")
  ))
  if (is.null(txt)) txt <- ""
  nums <- as.integer(stringr::str_extract_all(txt, "[0-9]+")[[1]])
  list(
    cur   = if (length(nums) >= 1) nums[1] else NA_integer_,
    max   = if (length(nums) >= 2) nums[2] else NA_integer_,
    total = if (length(nums) >= 3) nums[3] else NA_integer_
  )
}
