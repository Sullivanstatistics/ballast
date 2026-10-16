fev <- mmrm::fev_data
fev_small <- fev[fev$USUBJID %in% paste0("PT", 1:60), ]
spec_full <- stress_spec(fev, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                         covariates = ~ RACE + SEX + FEV1_BL, contrast_visit = "VIS4")
spec_small <- stress_spec(fev_small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                          covariates = ~ FEV1_BL, method = "Satterthwaite", vcov = "Asymptotic")
