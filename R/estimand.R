#' Perturbation family: intercurrent-event strategies (ICH E9(R1))
#'
#' Declares the intercurrent events that occurred and derives the analysis
#' data set implied by each handling strategy, then refits the pre-specified
#' model on each. Strategies per event type:
#'
#' * `"treatment_policy"`: use the data as observed, whatever happened.
#' * `"hypothetical"`: set the responses at and after the event to missing;
#'   the model's missing-at-random assumption then supplies the value the
#'   subject would have had without the event.
#' * `"while_on_treatment"`: drop the records at and after the event.
#' * `"composite"`: replace the responses at and after the event with an
#'   unfavourable value: a number, or a function `function(data, rows)`
#'   returning one value per affected row (the worst observed change in the
#'   subject's arm at that visit, say).
#'
#' With several event types the strategies are crossed, one row per
#' combination, and the row that applies `"treatment_policy"` to every type
#' reproduces the pre-specified data and is flagged `is_base`. Every other row
#' targets a different estimand, so they are `role = "supplementary"`; a
#' hypothetical strategy can be followed by [stress_reference()] on the
#' derived data for its reference-based sensitivity analyses.
#'
#' @inheritParams stress_covariance
#' @param ice A data frame with one row per intercurrent event: the subject
#'   identifier (column named as the spec's `subject`), the first visit
#'   affected (column named as the spec's `visit`) and `type` (a label such as
#'   `"discontinuation"` or `"rescue"`).
#' @param strategies Named list, one element per event type, each a character
#'   vector of strategies to apply; or a single character vector applied to
#'   every type.
#' @param composite_value A number or function used by the composite strategy.
#' @return A `stress_rows` data frame, one row per strategy combination;
#'   `attr(, "data")` holds the derived data sets by label.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' ice <- data.frame(USUBJID = c("PT2", "PT5", "PT9"), AVISIT = c("VIS3", "VIS2", "VIS4"),
#'                   type = c("discontinuation", "discontinuation", "rescue"))
#' stress_estimand(spec, ice, strategies = list(discontinuation = c("treatment_policy", "hypothetical"),
#'                                               rescue = c("treatment_policy", "composite")),
#'                 composite_value = 20)
#' @export
stress_estimand <- function(spec, ice, strategies = c("treatment_policy", "hypothetical", "while_on_treatment", "composite"),
                            composite_value = NULL, cores = 1L) {
  check_spec(spec); force_args()
  sub <- spec$subject; vis <- spec$visit; y <- spec$response
  ice <- as.data.frame(ice)
  if (!all(c(sub, vis, "type") %in% names(ice))) stop("ice needs columns ", sub, ", ", vis, " and type")
  ice[[sub]] <- as.character(ice[[sub]]); ice[[vis]] <- as.character(ice[[vis]]); ice$type <- as.character(ice$type)
  if (!all(ice[[vis]] %in% spec$visit_levels)) stop("ice visits must be visit levels")
  types <- unique(ice$type)
  if (!is.list(strategies)) strategies <- stats::setNames(rep(list(strategies), length(types)), types)
  if (!all(types %in% names(strategies))) stop("strategies must name every event type: ", paste(setdiff(types, names(strategies)), collapse = ", "))
  ok <- c("treatment_policy", "hypothetical", "while_on_treatment", "composite")
  for (t in types) if (!all(strategies[[t]] %in% ok)) stop("unknown strategy for ", t)
  if (any(vapply(types, function(t) "composite" %in% strategies[[t]], TRUE)) && is.null(composite_value)) stop("composite strategy needs composite_value")
  d0 <- spec$data
  apply_one <- function(d, type, strategy) {
    ev <- ice[ice$type == type, , drop = FALSE]; vnum <- match(as.character(d[[vis]]), spec$visit_levels)
    rows <- rep(FALSE, nrow(d))
    for (i in seq_len(nrow(ev))) rows <- rows | (as.character(d[[sub]]) == ev[[sub]][i] & vnum >= match(ev[[vis]][i], spec$visit_levels))
    switch(strategy,
      treatment_policy = d,
      hypothetical = { d[[y]][rows] <- NA; d },
      while_on_treatment = d[!rows, , drop = FALSE],
      composite = { d[[y]][rows] <- if (is.function(composite_value)) composite_value(d, rows) else composite_value; d })
  }
  combos <- expand.grid(lapply(stats::setNames(types, types), function(t) strategies[[t]]), stringsAsFactors = FALSE)
  labels <- apply(combos, 1, function(r) paste(paste0(names(r), ": ", r), collapse = " | "))
  datasets <- lapply(seq_len(nrow(combos)), function(i) { d <- d0; for (t in types) d <- apply_one(d, t, combos[i, t]); d })
  names(datasets) <- labels
  all_tp <- apply(combos, 1, function(r) all(r == "treatment_policy"))
  rows <- bind_rows_(stress_map(seq_along(labels), function(i)
    stress_fit(spec, data = if (all_tp[i]) NULL else datasets[[i]], label = labels[i], family = "intercurrent-event strategy", is_base = all_tp[i],
               role = if (all_tp[i]) "sensitivity" else "supplementary", note = sprintf("%d event%s", nrow(ice), if (nrow(ice) == 1L) "" else "s")), cores))
  attr(rows, "data") <- datasets
  rows
}
