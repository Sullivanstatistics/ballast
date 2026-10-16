# Swarm packing: for circles of radius r at horizontal positions x (same units), the smallest |y| that avoids overlap.
swarm_pack <- function(x, r) {
  o <- order(x); y <- numeric(length(x))
  for (k in seq_along(o)) {
    i <- o[k]; placed <- o[seq_len(k - 1)]
    nb <- placed[abs(x[placed] - x[i]) < r[placed] + r[i]]
    cands <- 0
    for (j in nb) { d <- (r[i] + r[j])^2 - (x[i] - x[j])^2; if (d > 0) cands <- c(cands, y[j] + sqrt(d), y[j] - sqrt(d)) }
    cands <- cands[order(abs(cands))]
    for (c0 in cands) {
      ok <- TRUE
      for (j in nb) if ((x[i] - x[j])^2 + (c0 - y[j])^2 < (r[i] + r[j])^2 - 1e-9) { ok <- FALSE; break }
      if (ok) { y[i] <- c0; break }
    }
  }
  y
}
circle <- function(cx, cy, r, id, n = 48) { t <- seq(0, 2 * pi, length.out = n); data.frame(id = id, x = cx + r * cos(t), y = cy + r * sin(t)) }

#' Bubble-swarm plot of a census against the no-difference line
#'
#' One row per census. Each bubble is one distinct estimate among the counted
#' alternative analyses (rounded to `digits`), with area proportional to the
#' number of analyses giving that value and shade by the share of those
#' analyses that are significant; bubbles holding five or more analyses are
#' numbered. A ring marks the pre-specified estimate, the shaded band holds
#' the central 95% of the distinct values, the heavy vertical line is no
#' difference, and the least favourable alternative is labelled. Deletions
#' are a strip of small light dots beneath the swarm.
#'
#' @param x A `stress_census`, or a named list of them (one row each, drawn on
#'   a shared axis; the first is drawn at the top).
#' @param scale `"percent"` draws estimates as a percent of the pre-specified
#'   estimate, so several endpoints share an axis; `"estimate"` uses the
#'   response units (only sensible for one census or censuses on one scale).
#' @param digits Rounding used to decide which estimates are "the same value".
#' @param r0 Radius of a count-one bubble as a fraction of the x-axis range.
#' @param favours Labels for the two sides of no difference, in the order
#'   (reference arm, active arm). Defaults to the treatment level names.
#' @param xlab Axis label; `NULL` for a default.
#' @param xlim Axis limits; `NULL` for automatic limits that include zero.
#' @return A `ggplot` object (uses a fixed aspect ratio so bubbles are round).
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' cen <- stress_census(spec, stress_covariance(spec, c("us", "cs", "ar1h", "toep")),
#'                      stress_covariates(spec), stress_loo(spec, by = "RACE"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_swarm(cen)
#' @export
plot_swarm <- function(x, scale = c("percent", "estimate"), digits = 2, r0 = 0.004, favours = NULL, xlab = NULL, xlim = NULL) {
  need_ggplot(); scale <- match.arg(scale)
  cens <- if (inherits(x, "stress_census")) list(x) else x
  if (!length(cens) || !all(vapply(cens, inherits, TRUE, "stress_census"))) stop("x must be a stress_census or a list of them")
  if (is.null(names(cens))) names(cens) <- paste("Row", seq_along(cens))
  prep <- lapply(cens, function(ce) {
    b <- attr(ce, "base"); d <- as.data.frame(ce)[ce$counted & !is.na(ce$estimate), , drop = FALSE]
    f <- if (scale == "percent") function(v) 100 * v / b$estimate else identity
    alt <- d[d$kind == "alternative", , drop = FALSE]; del <- d[d$kind == "deletion", , drop = FALSE]
    val <- round(alt$estimate, digits)
    agg <- if (nrow(alt)) stats::aggregate(list(n = rep(1, nrow(alt))), list(val = val), sum) else data.frame(val = numeric(), n = numeric())
    agg$x <- f(agg$val); agg$sig <- vapply(agg$val, function(v) mean(alt$p[val == v] < attr(ce, "alpha"), na.rm = TRUE), 0)
    list(base = b, f = f, agg = agg, del_x = f(del$estimate), n_alt = nrow(alt), n_del = nrow(del),
         n_sig = sum(alt$p < attr(ce, "alpha"), na.rm = TRUE), n_del_sig = sum(del$p < attr(ce, "alpha"), na.rm = TRUE))
  })
  if (is.null(xlim)) {
    allx <- c(0, unlist(lapply(prep, function(p) c(p$agg$x, p$del_x, p$f(p$base$estimate)))))
    xr <- range(allx); pad <- 0.08 * diff(xr); xlim <- c(xr[1] - pad, xr[2] + pad)
  }
  R0 <- r0 * diff(xlim); LH <- 0.028 * diff(xlim)   # LH: one text line, in axis units (the aspect ratio is fixed)
  # pass 1: pack every row; pass 2: stack rows from the bottom, each with its own height
  for (k in seq_along(prep)) {
    agg <- prep[[k]]$agg
    if (nrow(agg)) { agg$r <- R0 * sqrt(agg$n); agg$yp <- swarm_pack(agg$x, agg$r); prep[[k]]$amp <- max(abs(agg$yp) + agg$r) }
    else { agg$r <- numeric(); agg$yp <- numeric(); prep[[k]]$amp <- R0 }
    prep[[k]]$agg <- agg
    prep[[k]]$below <- prep[[k]]$amp + (if (length(prep[[k]]$del_x)) 1.3 * LH else 0.4 * LH)   # extent under the centre line
    prep[[k]]$above <- prep[[k]]$amp + 1.5 * LH                                                  # extent over it, title included
  }
  polys <- list(); rings <- list(); labs <- list(); dels <- list(); bands <- list(); notes <- list(); titles <- list(); segs <- list(); id <- 0
  y0 <- 0
  for (k in rev(seq_along(prep))) {
    p <- prep[[k]]; agg <- p$agg
    if (k < length(prep)) y0 <- y0 + prep[[k + 1]]$above + p$below + 0.5 * LH
    for (i in seq_len(nrow(agg))) { id <- id + 1; polys[[id]] <- cbind(circle(agg$x[i], y0 + agg$yp[i], agg$r[i], id), sig = agg$sig[i]) }
    big <- agg[agg$n >= 5, ]; if (nrow(big)) labs[[k]] <- data.frame(x = big$x, y = y0 + big$yp, lab = big$n)
    id <- id + 1; rings[[k]] <- circle(p$f(p$base$estimate), y0, 1.9 * R0, id)
    if (length(p$del_x)) dels[[k]] <- data.frame(x = p$del_x, y = y0 - p$amp - 0.75 * LH + stats::runif(length(p$del_x), -0.2 * LH, 0.2 * LH))
    if (nrow(agg) >= 2) { q <- stats::quantile(agg$x, c(0.025, 0.975)); bands[[k]] <- data.frame(xmin = q[1], xmax = q[2], ymin = y0 - p$amp - 0.15 * LH, ymax = y0 + p$amp + 0.15 * LH) }
    if (nrow(agg)) {
      lf <- agg[if (scale == "percent" || p$base$estimate >= 0) which.min(agg$x) else which.max(agg$x), ]
      notes[[k]] <- data.frame(x = lf$x - lf$r - 0.8 * R0, y = y0, lab = sprintf("Least favourable: %s%s", format(lf$val, nsmall = digits), if (scale == "percent") sprintf(" (%d%%)", round(lf$x)) else ""))
    }
    segs[[k]] <- data.frame(y = y0 - p$below, yend = y0 + p$amp + 0.35 * LH)
    titles[[k]] <- data.frame(x = xlim[1], y = y0 + p$amp + 0.9 * LH, lab = sprintf("%s  \u00b7  %d alternative analyses, %d distinct values, %d significant  \u00b7  %d deletions below, %d significant",
                                                                               names(cens)[k], p$n_alt, nrow(agg), p$n_sig, p$n_del, p$n_del_sig))
  }
  P <- do.call(rbind, polys); Rg <- do.call(rbind, rings); L <- if (length(labs)) do.call(rbind, labs) else NULL
  D <- if (length(dels)) do.call(rbind, dels) else NULL; B <- if (length(bands)) do.call(rbind, bands) else NULL
  N <- if (length(notes)) do.call(rbind, notes) else NULL; Tt <- do.call(rbind, titles); S <- do.call(rbind, segs)
  if (is.null(favours)) { lv <- attr(cens[[1]], "arms"); favours <- if (is.null(lv)) c("Favours reference", "Favours active") else paste("Favours", lv) }
  ybot <- -prep[[length(prep)]]$below - 0.6 * LH
  g <- ggplot2::ggplot() +
    { if (!is.null(B)) ggplot2::geom_rect(data = B, ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = PAL[["band"]]) } +
    ggplot2::geom_segment(data = S, ggplot2::aes(x = 0, xend = 0, y = y, yend = yend), colour = PAL[["ink"]], linewidth = 0.9) +
    { if (!is.null(D)) ggplot2::geom_point(data = D, ggplot2::aes(x = x, y = y), colour = PAL[["light"]], size = 1.4, alpha = 0.9) } +
    ggplot2::geom_polygon(data = P, ggplot2::aes(x = x, y = y, group = id, fill = sig), colour = NA) +
    { if (!is.null(L)) ggplot2::geom_text(data = L, ggplot2::aes(x = x, y = y, label = lab), colour = "white", size = 2.6, fontface = "bold") } +
    ggplot2::geom_polygon(data = Rg, ggplot2::aes(x = x, y = y, group = id), fill = NA, colour = PAL[["blue"]], linewidth = 1) +
    { if (!is.null(N)) ggplot2::geom_text(data = N, ggplot2::aes(x = x, y = y, label = lab), colour = PAL[["ink2"]], size = 3, hjust = 1) } +
    ggplot2::geom_text(data = Tt, ggplot2::aes(x = x, y = y, label = lab), colour = PAL[["ink"]], size = 3.2, hjust = 0, fontface = "bold") +
    ggplot2::annotate("text", x = 0.012 * diff(xlim), y = ybot, label = "No difference", colour = PAL[["ink"]], size = 3, fontface = "bold", hjust = 0) +
    ggplot2::annotate("text", x = 0.012 * diff(xlim), y = ybot - LH, label = paste("\u2190", favours[1]), colour = PAL[["ink2"]], size = 3, hjust = 0) +
    ggplot2::annotate("text", x = 0.012 * diff(xlim), y = ybot - 2 * LH, label = paste(favours[2], "\u2192"), colour = PAL[["ink2"]], size = 3, hjust = 0) +
    ggplot2::scale_fill_gradient(low = PAL[["light"]], high = PAL[["grey"]], limits = c(0, 1), guide = "none") +
    ggplot2::scale_x_continuous(limits = xlim, expand = c(0, 0), labels = if (scale == "percent") function(v) paste0(v, "%") else ggplot2::waiver()) +
    ggplot2::coord_fixed(ratio = 1, clip = "off") +
    ggplot2::labs(x = if (!is.null(xlab)) xlab else if (scale == "percent") "Estimate as a percentage of the pre-specified result" else "Treatment difference", y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text.y = ggplot2::element_blank(),
                   axis.line.x = ggplot2::element_line(colour = PAL[["light"]]), axis.ticks.x = ggplot2::element_line(colour = PAL[["light"]]),
                   plot.background = ggplot2::element_rect(fill = "white", colour = NA), plot.margin = ggplot2::margin(8, 12, 8, 8))
  g
}
