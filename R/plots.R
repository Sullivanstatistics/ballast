# Display functions. ggplot2 is a suggested package; every function checks for it.
need_ggplot <- function() if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is needed for plotting")

PAL <- c(ink = "#111111", ink2 = "#5a6273", grey = "#7f7f78", light = "#c9c9c3", blue = "#2a78d6", navy = "#1e3a66",
         orange = "#e8873a", band = "#e6eaf3", grid = "#e6e8ee")

#' Plot p-value curves over a continuous perturbation
#'
#' Draws the p-value against the parameter for every family of rows that
#' carries a `param` value (from [stress_tipping()] or [stress_curve()]): one
#' line per family, the alpha reference line, the anchor point (the row of
#' `kind = "alternative"`, usually the unshifted analysis) emphasised, and a
#' dotted vertical line at each interpolated crossing with its value.
#'
#' @param rows A `stress_rows` data frame or `stress_census`; rows without a
#'   `param` are ignored.
#' @param alpha Significance level; defaults to the rows' own `alpha`.
#' @param xlab,ylab Axis labels.
#' @param log_p Draw the p-value axis on a log scale.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' tp <- stress_tipping(spec, deltas = c(0, -4, -8), m = 3)
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_pcurve(tp)
#' @export
plot_pcurve <- function(rows, alpha = NULL, xlab = "Perturbation", ylab = "p-value", log_p = FALSE) {
  need_ggplot()
  x <- as.data.frame(rows); x <- x[!is.na(x$param) & !is.na(x$p), , drop = FALSE]
  if (!nrow(x)) stop("no rows with a param value")
  if (is.null(alpha)) alpha <- x$alpha[1]
  x <- x[order(x$family, x$param), ]
  tp <- tipping_point(x, alpha); tp <- tp[!is.na(tp$crossing), , drop = FALSE]
  anchor <- x[x$kind == "alternative", , drop = FALSE]
  g <- ggplot2::ggplot(x, ggplot2::aes(x = param, y = p, colour = family, group = family)) +
    ggplot2::geom_hline(yintercept = alpha, colour = PAL[["orange"]], linewidth = 1, linetype = "22") +
    ggplot2::geom_line(linewidth = 1.2) + ggplot2::geom_point(size = 2.5)
  if (nrow(anchor)) g <- g + ggplot2::geom_point(data = anchor, colour = PAL[["orange"]], size = 5)
  if (nrow(tp)) g <- g + ggplot2::geom_vline(data = tp, ggplot2::aes(xintercept = crossing), colour = PAL[["ink2"]], linewidth = 0.5, linetype = "12") +
    ggplot2::geom_text(data = tp, ggplot2::aes(x = crossing, y = Inf, label = paste0("crosses at ", signif(crossing, 3))),
                       inherit.aes = FALSE, colour = PAL[["ink"]], hjust = -0.05, vjust = 1.5, size = 3.4)
  g <- g + ggplot2::annotate("text", x = min(x$param), y = alpha, label = paste("p =", alpha), colour = PAL[["orange"]], hjust = 0, vjust = -0.4, size = 3.4) +
    ggplot2::labs(x = xlab, y = ylab, colour = NULL) +
    ggplot2::scale_colour_manual(values = rep(c(PAL[["blue"]], PAL[["navy"]], PAL[["grey"]], PAL[["orange"]]), length.out = length(unique(x$family)))) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = if (length(unique(x$family)) > 1) "bottom" else "none")
  if (log_p) g <- g + ggplot2::scale_y_log10()
  g
}

#' Strip plot of p-values after each deletion
#'
#' Each dot is one refit with one unit removed, on a log p-value axis, one
#' strip per leave-one-out family; the diamond is the pre-specified analysis
#' with nothing removed and the dashed line is alpha. Counts of deletions
#' below alpha label each strip.
#'
#' @param x A `stress_census`, or a named list of them (one strip each).
#' @param alpha Significance level; defaults to the census's own.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_loo(spec, by = "RACE"), stress_loo(spec, by = "SEX"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_pstrip(cen)
#' @export
plot_pstrip <- function(x, alpha = NULL) {
  need_ggplot()
  cens <- if (inherits(x, "stress_census")) list(x) else x
  if (is.null(names(cens))) names(cens) <- paste("Row", seq_along(cens))
  d <- do.call(rbind, lapply(names(cens), function(nm) {
    ce <- cens[[nm]]; z <- as.data.frame(ce)[ce$counted & ce$kind == "deletion" & !is.na(ce$p), , drop = FALSE]
    if (!nrow(z)) return(NULL)
    data.frame(row = nm, strip = paste(nm, z$family, sep = " \u00b7 "), p = z$p, base_p = attr(ce, "base")$p, a = attr(ce, "alpha"), stringsAsFactors = FALSE)
  }))
  if (is.null(d) || !nrow(d)) stop("no deletion rows to plot")
  if (is.null(alpha)) alpha <- d$a[1]
  lab <- do.call(rbind, lapply(split(d, d$strip), function(g) data.frame(strip = g$strip[1], base_p = g$base_p[1], n = nrow(g), k = sum(g$p < alpha))))
  lab$text <- sprintf("%s   %d / %d", lab$strip, lab$k, lab$n)
  d$strip <- factor(d$strip, levels = rev(lab$strip)); lab$strip <- factor(lab$strip, levels = levels(d$strip))
  ggplot2::ggplot(d, ggplot2::aes(x = p, y = strip)) +
    ggplot2::geom_vline(xintercept = alpha, colour = PAL[["ink2"]], linetype = "22") +
    ggplot2::geom_jitter(colour = PAL[["blue"]], alpha = 0.6, size = 1.8, height = 0.2, width = 0) +
    ggplot2::geom_point(data = lab, ggplot2::aes(x = base_p, y = strip), shape = 23, fill = PAL[["orange"]], colour = PAL[["ink"]], size = 4) +
    ggplot2::scale_x_log10() +
    ggplot2::scale_y_discrete(labels = stats::setNames(lab$text, as.character(lab$strip))) +
    ggplot2::annotate("text", x = alpha, y = 0.4, label = paste("p =", alpha), colour = PAL[["ink2"]], hjust = -0.1, size = 3.2) +
    ggplot2::labs(x = "Two-sided p-value after deleting one unit and refitting (log scale)", y = NULL) +
    ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

utils::globalVariables(c("param", "p", "crossing", "x", "y", "yend", "id", "sig", "lab", "strip", "base_p", "ymin", "ymax"))
