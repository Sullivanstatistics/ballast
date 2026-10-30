cs_small <- spec_update(spec_small, covariance = "cs")

# The caller's random-number state, compared before and after a call.
rng_now <- function() if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) get(".Random.seed", envir = globalenv()) else NULL

test_that("plot_swarm labels each panel to three significant digits and leaves the caller's random-number state alone", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("us", "cs", "ar1h")), stress_loo(cs_small, by = "RACE"))
  cen2 <- cen; b <- attr(cen2, "base"); b$estimate <- 123.456789; b$lcl <- 0.473381; b$ucl <- 2.5; attr(cen2, "base") <- b
  set.seed(7); before <- rng_now()
  g <- plot_swarm(list(A = cen, B = cen2))
  expect_identical(rng_now(), before)
  set.seed(7); r1 <- runif(1); set.seed(7); invisible(plot_swarm(list(A = cen, B = cen2))); r2 <- runif(1)
  expect_identical(r1, r2)
  txt <- do.call(rbind, lapply(g$layers, function(l) if (is.data.frame(l$data) && "est_lab" %in% names(l$data)) l$data))
  txt <- txt[!duplicated(txt$row), ]
  expect_equal(txt$est_lab[txt$row == "B"], "123"); expect_equal(txt$lcl_lab[txt$row == "B"], "0.473"); expect_equal(txt$ucl_lab[txt$row == "B"], "2.5")
  expect_equal(txt$est_lab[txt$row == "A"], format(attr(cen, "base")$estimate, digits = 3))
  # the same figure on every call
  pts <- function(g) do.call(rbind, lapply(g$layers, function(l) if (is.data.frame(l$data) && "diagnostic" %in% names(l$data)) l$data))
  expect_identical(pts(g), pts(plot_swarm(list(A = cen, B = cen2))))
  # the bubble form too
  set.seed(8); before <- rng_now(); invisible(plot_swarm(cen)); expect_identical(rng_now(), before)
})

test_that("plot_swarm takes one reference value or one per panel", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("us", "cs")), stress_loo(cs_small, by = "RACE"))
  refs <- function(g) do.call(rbind, lapply(g$layers, function(l) if (is.data.frame(l$data) && "ref" %in% names(l$data) && inherits(l$geom, "GeomVline")) l$data))
  r <- refs(plot_swarm(list(A = cen, B = cen), reference = 1))
  expect_equal(as.character(r$row), c("A", "B")); expect_equal(r$ref, c(1, 1))
  r <- refs(plot_swarm(list(A = cen, B = cen), reference = c(B = 4.22, A = 1), reference_label = c(A = "1 point", B = "4.22%")))
  expect_equal(r$ref, c(1, 4.22))
  r <- refs(plot_swarm(list(A = cen, B = cen), reference = c(2, NA)))
  expect_equal(as.character(r$row), "A")
  g <- plot_swarm(list(A = cen, B = cen), reference = c(A = 1), reference_label = "1 unit")
  expect_equal(as.character(refs(g)$row), "A")
  expect_error(plot_swarm(list(A = cen, B = cen), reference = c(C = 1)), "not in x")
  expect_error(plot_swarm(list(A = cen, B = cen), reference = c(1, 2, 3)), "one per row")
})

test_that("plot_pstrip is reproducible, restores the random-number state and rings highlighted deletions", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_loo(cs_small, by = "RACE"), stress_loo(cs_small, by = "SEX"))
  set.seed(11); before <- rng_now()
  g1 <- plot_pstrip(cen, highlight = "Asian")
  expect_identical(rng_now(), before)
  g2 <- plot_pstrip(cen, highlight = "Asian")
  expect_identical(g1$data$y, g2$data$y)
  expect_false(identical(g1$data$y, plot_pstrip(cen, seed = 2)$data$y))
  hl <- Filter(function(l) is.data.frame(l$data) && "unit" %in% names(l$data) && nrow(l$data) && all(l$data$unit == "Asian") && inherits(l$geom, "GeomPoint"), g1$layers)
  expect_length(hl, 1L)
  expect_equal(hl[[1]]$data$y, g1$data$y[g1$data$unit == "Asian"])   # the ring sits on the drawn dot
  expect_warning(plot_pstrip(cen, highlight = "nobody"), "no deletion row")
})

test_that("plot_pcurve draws one panel per list element with crossings found within each panel", {
  skip_if_not_installed("ggplot2")
  shift <- function(d, v) { k <- d$ARMCD == "TRT" & !is.na(d$FEV1); d$FEV1[k] <- d$FEV1[k] + v; d }
  a <- stress_curve(cs_small, values = c(-15, -10, -5, 0, 5), modify = shift, family = "arm shift", anchor = 0)
  b <- stress_curve(cs_small, values = c(-30, -20, -10, 0), modify = shift, family = "arm shift", anchor = 0)
  g <- plot_pcurve(list("Row A" = a, "Row B" = b))
  expect_s3_class(g, "ggplot"); expect_s3_class(g$facet, "FacetWrap")
  expect_equal(levels(g$data$panel), c("Row A", "Row B"))
  tp <- do.call(rbind, lapply(g$layers, function(l) if (is.data.frame(l$data) && "crossing" %in% names(l$data) && inherits(l$geom, "GeomVline")) l$data))
  expect_equal(nrow(tp), sum(!is.na(c(tipping_point(a)$crossing, tipping_point(b)$crossing))))
  for (k in seq_len(nrow(tp))) expect_equal(tp$crossing[k], tipping_point(if (tp$panel[k] == "Row A") a else b)$crossing)
  expect_error(plot_pcurve(list(a, b)), "must be named")
  expect_null(plot_pcurve(a)$facet$params$facets)
})

test_that("the rule text says that deletions count, as stress_verdict() does", {
  expect_match(ballast:::rule_text("interval"), "counted refit \\(an alternative analysis or a deletion\\)")
  expect_match(ballast:::rule_text("interval_or_direction"), "counted refit \\(an alternative analysis or a deletion\\)")
  # a census whose only exit is a deletion is fragile
  cen <- stress_census(cs_small, stress_covariance(cs_small, "us"), stress_loo(cs_small, by = "RACE"))
  b <- attr(cen, "base"); del <- cen$kind == "deletion"
  cen$estimate[which(del)[1]] <- b$ucl + 10; cen$inside_ci[which(del)[1]] <- FALSE
  expect_equal(stress_verdict(cen)$stability, "fragile")
})
