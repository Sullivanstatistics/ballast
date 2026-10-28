# The displays of 0.7.1: the multi-row swarm (one panel per endpoint-metric row, every refit against the filed result),
# the forest of supplementary rows, and the helpers that let every plotting function take censuses or results.

# Censuses from whatever the user passes: a census, a stress_result (run_plan), a stress_results (run_plans), or a list
# of any of these. Names come from the list, else from the plan title, else from the census label, else "Row k".
as_census_list <- function(x) {
  one <- function(z, nm) {
    if (inherits(z, "stress_result")) { ce <- z$census; if (is.null(nm) || nm == "") nm <- z$plan$title }
    else if (inherits(z, "stress_census")) { ce <- z; if (is.null(nm) || nm == "") nm <- attr(z, "label") }
    else stop("x must be a stress_census, a stress_result, or a list of them")
    list(census = ce, name = nm)
  }
  items <- if (inherits(x, "stress_census") || inherits(x, "stress_result")) list(x) else if (is.list(x)) x else stop("x must be a stress_census, a stress_result, or a list of them")
  nms <- names(items); if (is.null(nms)) nms <- rep("", length(items))
  out <- lapply(seq_along(items), function(i) one(items[[i]], nms[i]))
  cens <- lapply(out, `[[`, "census")
  names(cens) <- vapply(seq_along(out), function(i) { nm <- out[[i]]$name; if (is.null(nm) || !nzchar(nm)) paste("Row", i) else nm }, "")
  cens
}

# Which decision a family varies. Statistical decisions change the model or the inference on the same data; data-handling
# decisions change what is analysed (data set, population, intercurrent-event strategy, imputation). Deletions are their
# own group. Anything unknown is "other", so a user family is drawn, not dropped.
decision_group <- function(family, kind) {
  stat <- c("covariance structure", "inference", "covariate set", "LS-mean weighting", "specification grid", "estimator", "rank test", "contrast visit", "re-randomisation test")
  data <- c("data handling", "analysis population", "intercurrent-event strategy", "reference-based multiple imputation", "delta-adjusted imputation", "tipping point", "perturbation curve")
  g <- ifelse(kind == "deletion", "deletion",
       ifelse(family %in% stat | grepl("^estimator|^rank|randomi[sz]ation|permutation", family), "statistical",
       ifelse(family %in% data | grepl("imputation|tipping|population|data set|strategy", family), "data-handling", "other")))
  factor(g, levels = c("statistical", "data-handling", "other", "deletion"), labels = c("Statistical decision varied", "Data-handling decision varied", "Other family", "One unit removed"))
}

#' Swarm of every re-analysis against the filed result
#'
#' Two forms. **Single census** (`style = "bubbles"`, the default for one census): the bubble swarm of earlier
#' versions, one row per census on a percent-of-filed axis. **Several rows** (`style = "dots"`, the default for a
#' list): one panel per endpoint-metric row, the filed estimate and its 95% interval drawn as the axis of the
#' panel with the filed value labelled, every counted alternative analysis as a dot placed by its estimate and
#' coloured by the decision it varies (statistical: covariance, inference, covariate set, weighting, grid,
#' estimator; data-handling: data set, population, intercurrent-event strategy, imputation), the counted deletions
#' as a strip of small light dots beneath the axis, a vertical line at no difference, and an optional labelled
#' reference line. Counted rows that return no estimate (rank tests) are not drawn; their number per row is in
#' the `caption` attribute of the returned plot, with the counts of alternatives and deletions.
#'
#' @param x A `stress_census`, a `stress_result` (from [run_plan()]), the `stress_results` list of [run_plans()],
#'   or a list of censuses or results (one row each). List names, plan titles or census labels name the rows.
#' @param style `"bubbles"` or `"dots"`; `"auto"` chooses bubbles for one census and dots for a list.
#' @param reference Optional x position of a reference line (a clinically meaningful difference, say).
#' @param reference_label Text printed at the reference line.
#' @param scale,digits,r0,favours,xlab,xlim Settings of the bubble form (see the earlier documentation): axis
#'   scale, rounding for "the same value", bubble radius, side labels, axis label and limits.
#' @return A `ggplot` object. In the dots form the attribute `caption` is a character vector, one entry per
#'   row, with the counts of alternatives drawn, deletions drawn and rows without an estimate.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' cen <- stress_census(spec, stress_covariance(spec, c("us", "cs", "ar1h")),
#'                      stress_covariates(spec), stress_loo(spec, by = "RACE"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_swarm(cen)                                           # one census: bubbles
#'   spec2 <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                        covariates = ~ FEV1_BL, contrast_visit = "VIS3")
#'   cen2 <- stress_census(spec2, stress_covariance(spec2, c("us", "cs")),
#'                         stress_loo(spec2, by = "SEX"))
#'   g <- plot_swarm(list("FEV1 at visit 4" = cen, "FEV1 at visit 3" = cen2), reference = 1,
#'                   reference_label = "1 unit")
#'   attr(g, "caption")
#' }
#' @export
plot_swarm <- function(x, style = c("auto", "bubbles", "dots"), reference = NULL, reference_label = NULL,
                       scale = c("percent", "estimate"), digits = 2, r0 = 0.004, favours = NULL, xlab = NULL, xlim = NULL) {
  need_ggplot(); style <- match.arg(style)
  single <- inherits(x, "stress_census")
  if (style == "auto") style <- if (single) "bubbles" else "dots"
  if (style == "bubbles") {
    cens <- as_census_list(x)
    return(swarm_bubbles(if (single) x else cens, scale = scale, digits = digits, r0 = r0, favours = favours, xlab = xlab, xlim = xlim))
  }
  cens <- as_census_list(x)
  rows <- names(cens)
  pts <- list(); axes <- list(); caption <- character()
  for (k in seq_along(cens)) {
    ce <- cens[[k]]; b <- attr(ce, "base"); d <- as.data.frame(ce)[ce$counted, , drop = FALSE]
    no_est <- sum(is.na(d$estimate)); d <- d[!is.na(d$estimate), , drop = FALSE]
    d$group <- decision_group(d$family, d$kind)
    alt <- d[d$kind != "deletion", , drop = FALSE]; del <- d[d$kind == "deletion", , drop = FALSE]
    set.seed(1L)   # the vertical scatter is cosmetic; fixed so the figure is reproducible
    if (nrow(alt)) pts[[length(pts) + 1]] <- data.frame(row = rows[k], x = alt$estimate, y = stats::runif(nrow(alt), 0.18, 0.55), group = alt$group, stringsAsFactors = FALSE)
    if (nrow(del)) pts[[length(pts) + 1]] <- data.frame(row = rows[k], x = del$estimate, y = stats::runif(nrow(del), -0.5, -0.18), group = del$group, stringsAsFactors = FALSE)
    axes[[k]] <- data.frame(row = rows[k], est = b$estimate, lcl = b$lcl, ucl = b$ucl, stringsAsFactors = FALSE)
    caption[k] <- sprintf("%s: %d alternative analyses drawn, %d deletions drawn, %d counted rows without an estimate", rows[k], nrow(alt), nrow(del), no_est)
  }
  P <- if (length(pts)) do.call(rbind, pts) else data.frame(row = character(), x = numeric(), y = numeric(), group = factor(character(), levels = levels(decision_group("a", "b"))))
  A <- do.call(rbind, axes)
  P$row <- factor(P$row, levels = rows); A$row <- factor(A$row, levels = rows)
  cols <- c("Statistical decision varied" = PAL[["blue"]], "Data-handling decision varied" = PAL[["orange"]], "Other family" = PAL[["navy"]], "One unit removed" = PAL[["light"]])
  g <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = A, ggplot2::aes(xmin = lcl, xmax = ucl, ymin = -0.62, ymax = 0.66), fill = PAL[["band"]]) +
    ggplot2::geom_vline(xintercept = 0, colour = PAL[["ink"]], linewidth = 0.8) +
    ggplot2::geom_point(data = P, ggplot2::aes(x = x, y = y, colour = group), size = 1.8, alpha = 0.85) +
    ggplot2::geom_segment(data = A, ggplot2::aes(x = lcl, xend = ucl, y = 0, yend = 0), colour = PAL[["navy"]], linewidth = 2.2, lineend = "round") +
    ggplot2::geom_point(data = A, ggplot2::aes(x = est, y = 0), shape = 23, fill = "white", colour = PAL[["navy"]], size = 3.6, stroke = 1.2) +
    ggplot2::geom_text(data = A, ggplot2::aes(x = est, y = -0.08, label = format(est, digits = 3)), colour = PAL[["navy"]], size = 3.1, fontface = "bold", vjust = 1) +
    ggplot2::geom_text(data = A, ggplot2::aes(x = lcl, y = 0.07, label = format(lcl, digits = 3)), colour = PAL[["navy"]], size = 2.6, vjust = 0, hjust = 0.3) +
    ggplot2::geom_text(data = A, ggplot2::aes(x = ucl, y = 0.07, label = format(ucl, digits = 3)), colour = PAL[["navy"]], size = 2.6, vjust = 0, hjust = 0.7) +
    ggplot2::scale_colour_manual(values = cols, drop = TRUE, name = NULL) +
    ggplot2::scale_y_continuous(limits = c(-0.66, 0.7), breaks = NULL) +
    ggplot2::facet_wrap(~ row, ncol = 1, scales = "free_x") +
    ggplot2::labs(x = if (is.null(xlab)) "Treatment difference (filed estimate and 95% interval as the axis)" else xlab, y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), strip.text = ggplot2::element_text(hjust = 0, face = "bold"), legend.position = "bottom",
                   axis.line.x = ggplot2::element_line(colour = PAL[["light"]]), plot.background = ggplot2::element_rect(fill = "white", colour = NA)) +
    ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(size = 3, alpha = 1)))
  if (!is.null(reference)) {
    g <- g + ggplot2::geom_vline(xintercept = reference, colour = "#1baf7a", linewidth = 0.9, linetype = "22")
    if (!is.null(reference_label)) g <- g + ggplot2::annotate("text", x = reference, y = 0.66, label = reference_label, colour = "#1baf7a", size = 3, hjust = -0.05, vjust = 1)
  }
  attr(g, "caption") <- caption
  g
}

#' Forest plot of the filed analysis and the supplementary rows
#'
#' Estimate and 95% interval for the filed analysis and the named rows of each census, one panel per endpoint-metric
#' row, the filed row first. When several results objects are given (a trial alone and pooled with an earlier trial,
#' say), the objects are drawn side by side within each row in different colours.
#'
#' @param ... One or more `stress_census` or `stress_result` objects (or lists of them, as in [plot_swarm()]). Several
#'   objects are compared side by side; name the arguments to label them.
#' @param rows Character vector of census row labels to show. The default is every counted row with
#'   `role = "supplementary"`.
#' @param xlab Axis label.
#' @return A `ggplot` object.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' d <- mmrm::fev_data
#' cen <- stress_census(spec, stress_covariance(spec, "cs"),
#'                      stress_data(spec, list("Black and White only" = d[d$RACE != "Asian", ],
#'                                             "Female only" = d[d$SEX == "Female", ])))
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_forest(cen)
#'   plot_forest("All" = cen, "Complete cases" = cen, rows = "Black and White only")
#' }
#' @export
plot_forest <- function(..., rows = NULL, xlab = "Treatment difference (95% interval)") {
  need_ggplot()
  objs <- list(...)
  if (length(objs) == 1L && is.list(objs[[1]]) && !inherits(objs[[1]], c("stress_census", "stress_result"))) objs <- objs[[1]]
  onames <- names(objs); if (is.null(onames)) onames <- rep("", length(objs))
  onames <- ifelse(nzchar(onames), onames, paste("Results", seq_along(objs)))
  D <- list()
  for (i in seq_along(objs)) {
    cens <- as_census_list(objs[[i]])
    for (k in seq_along(cens)) {
      ce <- cens[[k]]; b <- attr(ce, "base"); d <- as.data.frame(ce)[ce$counted & !is.na(ce$estimate), , drop = FALSE]
      sel <- if (is.null(rows)) d[d$role == "supplementary", , drop = FALSE] else d[d$label %in% rows, , drop = FALSE]
      D[[length(D) + 1]] <- data.frame(object = onames[i], panel = names(cens)[k], label = c("As filed", sel$label), est = c(b$estimate, sel$estimate),
                                       lo = c(b$lcl, sel$lcl), hi = c(b$ucl, sel$ucl), stringsAsFactors = FALSE)
    }
  }
  D <- do.call(rbind, D)
  if (!any(D$label != "As filed")) stop("no supplementary rows to draw (none with role = \"supplementary\", or none matching `rows`)")
  labs_order <- unique(c("As filed", if (is.null(rows)) unique(D$label[D$label != "As filed"]) else rows))
  D$label <- factor(D$label, levels = rev(labs_order)); D$object <- factor(D$object, levels = unique(onames)); D$panel <- factor(D$panel, levels = unique(D$panel))
  n_obj <- nlevels(D$object); off <- if (n_obj > 1) (as.numeric(D$object) - (n_obj + 1) / 2) * (0.5 / n_obj) else 0
  D$y <- as.numeric(D$label) - off
  g <- ggplot2::ggplot(D) +
    ggplot2::geom_vline(xintercept = 0, colour = PAL[["ink"]], linewidth = 0.7) +
    ggplot2::geom_segment(ggplot2::aes(x = lo, xend = hi, y = y, yend = y, colour = object), linewidth = 1.4) +
    ggplot2::geom_point(ggplot2::aes(x = est, y = y, colour = object, shape = object), size = 3) +
    ggplot2::scale_y_continuous(breaks = seq_along(levels(D$label)), labels = levels(D$label)) +
    ggplot2::scale_colour_manual(values = rep(c("#4a3aa7", "#1baf7a", PAL[["orange"]], PAL[["grey"]]), length.out = n_obj), name = NULL) +
    ggplot2::scale_shape_manual(values = rep(c(16, 18, 17, 15), length.out = n_obj), name = NULL) +
    ggplot2::labs(x = xlab, y = NULL) + ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(), strip.text = ggplot2::element_text(hjust = 0, face = "bold"),
                   legend.position = if (n_obj > 1) "bottom" else "none", plot.background = ggplot2::element_rect(fill = "white", colour = NA))
  if (nlevels(D$panel) > 1) g <- g + ggplot2::facet_wrap(~ panel, scales = "free_x")
  g
}

utils::globalVariables(c("group", "lcl", "ucl", "est", "lo", "hi", "object", "panel"))
