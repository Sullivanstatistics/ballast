#' Interactive HTML report
#'
#' Writes an HTML page (its JavaScript dependencies in a `lib` folder beside
#' it) with the verdict, the summary table and two interactive figures built
#' with `plotly`: the bubble swarm, where
#' hovering a bubble lists the specifications that give that estimate, and
#' the deletion strip, where hovering a dot names the subject removed and
#' shows the refit's estimate and p-value. Needs `plotly` and `htmlwidgets`.
#'
#' @param result A `stress_result` from [run_plan()].
#' @param file Path of the HTML file to write. There is no default, so nothing is written unless a path is given.
#' @param digits Rounding used to group estimates into bubbles.
#' @param mask_ids Replace subject identifiers with sequence numbers (on by
#'   default: the page is the deliverable most likely to leave the organisation).
#' @return The file path, invisibly.
#' @examples
#' \donttest{
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
#'                     covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
#'                     reference = NULL, estimator = NULL, fragility = NULL)
#' if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE))
#'   stress_html(run_plan(plan), file.path(tempdir(), "stress.html"))
#' }
#' @export
stress_html <- function(result, file, digits = 2, mask_ids = TRUE) {
  if (!inherits(result, "stress_result")) stop("result must be a stress_result")
  if (!requireNamespace("plotly", quietly = TRUE) || !requireNamespace("htmlwidgets", quietly = TRUE)) stop("plotly and htmlwidgets are needed")
  cen <- result$census; b <- result$base; v <- result$verdict
  if (mask_ids) cen <- ballast::mask_ids(cen, result$plan$spec)
  d <- as.data.frame(cen)[cen$counted & !is.na(cen$estimate), , drop = FALSE]
  alt <- d[d$kind == "alternative", , drop = FALSE]; del <- d[d$kind == "deletion", , drop = FALSE]
  pct <- function(e) 100 * e / b$estimate
  old_rng <- rng_state(); on.exit(rng_restore(old_rng), add = TRUE); seed_rng(1L)   # cosmetic scatter of the deletion strips: reproducible, caller's stream restored
  # swarm: distinct values, packed
  val <- round(alt$estimate, digits)
  agg <- stats::aggregate(list(n = rep(1, nrow(alt))), list(val = val), sum)
  agg$x <- pct(agg$val); agg$text <- vapply(agg$val, function(vv) { z <- alt[val == vv, ]
    paste0("<b>", format(vv, nsmall = digits), "</b> (", round(100 * vv / b$estimate), "% of pre-specified)<br>", nrow(z), " analys", if (nrow(z) == 1) "is" else "es",
           ", ", sum(z$p < attr(cen, "alpha"), na.rm = TRUE), " significant<br>", paste(utils::head(paste0(z$family, ": ", z$label, " (p ", formatC(z$p, digits = 3, format = "f"), ")"), 12), collapse = "<br>"),
           if (nrow(z) > 12) sprintf("<br>... and %d more", nrow(z) - 12) else "") }, "")
  xr <- range(c(0, agg$x, pct(del$estimate), 100)); R0 <- 0.006 * diff(xr); agg$r <- R0 * sqrt(agg$n); agg$y <- swarm_pack(agg$x, agg$r)
  agg$sig <- vapply(agg$val, function(vv) mean(alt$p[val == vv] < attr(cen, "alpha"), na.rm = TRUE), 0)
  q <- if (nrow(agg) >= 2) stats::quantile(agg$x, c(0.025, 0.975)) else c(NA, NA)
  p1 <- plotly::plot_ly()
  if (!anyNA(q)) p1 <- plotly::add_polygons(p1, x = c(q[1], q[2], q[2], q[1]), y = c(-1, -1, 1, 1) * (max(abs(agg$y)) + 2 * R0) / diff(xr) * 100, fillcolor = "rgba(230,234,243,0.8)", line = list(width = 0), hoverinfo = "none", showlegend = FALSE)
  p1 <- plotly::add_markers(p1, data = agg, x = ~x, y = ~y / diff(xr) * 100, text = ~text, hoverinfo = "text", marker = list(size = ~20 * sqrt(n), sizemode = "diameter", color = ~sig, colorscale = list(c(0, "#c9c9c3"), c(1, "#7f7f78")), showscale = FALSE, line = list(width = 0)), showlegend = FALSE)
  if (nrow(del)) p1 <- plotly::add_markers(p1, data = del, x = ~pct(estimate), y = -(max(abs(agg$y)) + 4 * R0) / diff(xr) * 100 + stats::runif(nrow(del), -0.5, 0.5),
                                           text = ~paste0("<b>", family, "</b>: ", label, "<br>estimate ", formatC(estimate, digits = 3, format = "f"), " (", round(pct(estimate)), "%), p ", formatC(p, digits = 3, format = "f")),
                                           hoverinfo = "text", marker = list(size = 6, color = "#c9c9c3"), showlegend = FALSE)
  p1 <- plotly::add_markers(p1, x = 100, y = 0, marker = list(size = 22, color = "rgba(0,0,0,0)", line = list(color = "#2a78d6", width = 2.5)), text = sprintf("<b>Pre-specified</b>: %s (p %s)", formatC(b$estimate, digits = 3, format = "f"), formatC(b$p, digits = 3, format = "f")), hoverinfo = "text", showlegend = FALSE)
  p1 <- plotly::layout(p1, title = "Alternative analyses (bubbles) and deletions (strip), % of the pre-specified estimate", xaxis = list(title = "% of pre-specified estimate", zeroline = TRUE, zerolinewidth = 2, zerolinecolor = "#111"),
                       yaxis = list(visible = FALSE, scaleanchor = "x"), hoverlabel = list(align = "left"), plot_bgcolor = "white")
  # deletion strip on a log p axis
  p2 <- NULL
  if (nrow(del)) {
    del$strip <- factor(del$family); del$jit <- as.integer(del$strip) + stats::runif(nrow(del), -0.2, 0.2)
    p2 <- plotly::plot_ly(del, x = ~p, y = ~jit, type = "scatter", mode = "markers", text = ~paste0("<b>", label, "</b><br>estimate ", formatC(estimate, digits = 3, format = "f"), ", p ", formatC(p, digits = 4, format = "f")),
                          hoverinfo = "text", marker = list(size = 7, color = "#2a78d6", opacity = 0.6))
    p2 <- plotly::add_markers(p2, x = b$p, y = seq_along(levels(del$strip)), marker = list(symbol = "diamond", size = 12, color = "#e8873a", line = list(color = "#111", width = 1)), text = "pre-specified", hoverinfo = "text", inherit = FALSE)
    p2 <- plotly::layout(p2, title = "p-value after deleting one unit (log scale)", xaxis = list(type = "log", title = "p-value"), shapes = list(list(type = "line", x0 = attr(cen, "alpha"), x1 = attr(cen, "alpha"), y0 = 0, y1 = 1, yref = "paper", line = list(dash = "dash", color = "#5a6273"))),
                         yaxis = list(tickvals = seq_along(levels(del$strip)), ticktext = levels(del$strip), title = ""), showlegend = FALSE)
  }
  s <- as.data.frame(summary(cen)); s$pct_min <- round(s$pct_min); s$pct_max <- round(s$pct_max); s$max_shift_se <- round(s$max_shift_se, 2)
  tab <- paste0("<table><tr>", paste0("<th>", names(s), "</th>", collapse = ""), "</tr>", paste(apply(s, 1, function(r) paste0("<tr>", paste0("<td>", r, "</td>", collapse = ""), "</tr>")), collapse = ""), "</table>")
  head_html <- sprintf("<h1>%s</h1><p>Pre-specified: estimate %s (SE %s), 95%% CI %s to %s, p %s.</p><p><b>Verdict: %s</b> over all counted rows; <b>%s</b> over the sensitivity analyses%s. %d crossed alpha, %d outside the interval, %d reversed.</p>",
                       result$plan$title, formatC(b$estimate, digits = 3, format = "f"), formatC(b$stderr, digits = 3, format = "f"), formatC(b$lcl, digits = 3, format = "f"), formatC(b$ucl, digits = 3, format = "f"), formatC(b$p, digits = 3, format = "f"),
                       toupper(v$stability), toupper(v$stability_sensitivity), if (v$marginal) " (marginal)" else "", v$n_crossed, v$n_outside_ci, v$n_reversed)
  css <- "<style>body{font-family:Arial,sans-serif;margin:24px;color:#111}table{border-collapse:collapse;font-size:13px}th,td{border:1px solid #ddd;padding:4px 8px;text-align:right}th{background:#f3f4f7}td:first-child,th:first-child{text-align:left}pre{background:#f7f7f7;padding:8px;font-size:12px}</style>"
  widgets <- list(htmltools_tag(p1), if (!is.null(p2)) htmltools_tag(p2))
  page <- htmltools::tagList(htmltools::HTML(css), htmltools::HTML(head_html), widgets[[1]], if (!is.null(p2)) widgets[[2]], htmltools::HTML("<h2>Summary by family</h2>"), htmltools::HTML(tab),
                             htmltools::HTML("<h2>Plan</h2><pre>"), htmltools::HTML(paste(plan_lines(result$plan), collapse = "\n")), htmltools::HTML("</pre>"))
  htmltools::save_html(page, file = file, background = "white")
  invisible(file)
}
htmltools_tag <- function(w) htmltools::div(style = "max-width:1100px", w)
