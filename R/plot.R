#' Plot a census: one row per family on the percent-of-base axis
#'
#' Each counted analysis is a point at its estimate as a percent of the base
#' estimate, filled by significance; the shaded band is the base confidence
#' interval on the same axis and the vertical line is the base estimate.
#' Deletions are drawn in a separate panel from alternative analyses.
#'
#' @param x A `stress_census`.
#' @param ... Unused.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")),
#'                      stress_loo(spec, by = "RACE"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot(cen)
#' @export
plot.stress_census <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is needed for plotting")
  b <- attr(x, "base")
  d <- as.data.frame(x)[x$counted & !is.na(x$estimate), , drop = FALSE]
  d$kind <- factor(d$kind, levels = c("alternative", "deletion"), labels = c("Alternative analyses", "Deletions"))
  d$family <- factor(d$family, levels = rev(unique(d$family)))
  d$Significant <- ifelse(d$significant, "yes", "no")
  band <- data.frame(xmin = 100 * b$lcl / b$estimate, xmax = 100 * b$ucl / b$estimate)
  ggplot2::ggplot(d, ggplot2::aes(x = pct_of_base, y = family)) +
    ggplot2::geom_rect(data = band, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
                       inherit.aes = FALSE, fill = "grey85", alpha = 0.6) +
    ggplot2::geom_vline(xintercept = 100, colour = "grey30") +
    ggplot2::geom_vline(xintercept = 0, colour = "grey60", linetype = 2) +
    ggplot2::geom_jitter(ggplot2::aes(fill = Significant), shape = 21, size = 2.2, height = 0.2, width = 0, alpha = 0.85) +
    ggplot2::scale_fill_manual(values = c(yes = "#1f5fa6", no = "#f2a541")) +
    ggplot2::facet_grid(rows = ggplot2::vars(kind), scales = "free_y", space = "free_y") +
    ggplot2::labs(x = "Estimate as % of the pre-specified estimate (band: its 95% CI)", y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank())
}

utils::globalVariables(c("pct_of_base", "family", "xmin", "xmax", "Significant", "kind"))
