# run_all.R — master script for the ECON 5560 replication.
# Runs the full pipeline: raw data (data/) -> Tobit WTP estimates -> outputs/.
# Run from the repository root:
#   Rscript run_all.R > logs/run_log.txt 2>&1
#
# Based on the team script tobitModel_econProject_092526.R. Changes from that file:
#   - hard-coded C:/Users/... data path replaced with a relative path (data/)
#   - tobit_results() is run once per group instead of three times
#   - the finished Table 6 is now written to outputs/ (CSV and LaTeX)
#   - run time and sessionInfo() are printed at the end for the log

start_time <- Sys.time()

library(readxl)
library(stats)

dir.create("outputs", showWarnings = FALSE)
dir.create("logs", showWarnings = FALSE)

#########################################
#
#           Assumptions I made while Coding-
#               Separate from paper assumptions
#
# 1.) Omitted Ci term in equation (2) from the paper because
#  I do not see an explicit calculation for it in the paper
#         - This is the "between-individual error term"
#             --> (random effects varying across the individual bidder but not the plant)
# 2.) We use a plant dummy variable while the paper gives plant types
#          - Data Dictionary for specific plants was not provided along with the data
#
# 3.) Calculated WTP SE usin' delta-method, paper did not say how SEs were calculated.
#
# 4.) Calculated p-values usin' a Normal z-test, then used those p-values
#     to assign * confidence interval values, as their p-value procedure wasn't stated
#
# 5.) Dropped att_importance responses from the subgroup to avoid missing rows
#         - These are people who were indecisive about responding.
#
spa <- as.data.frame(read_excel("data/SPA_combined_sample.xls"))
cat("Loaded data/SPA_combined_sample.xls:", nrow(spa), "rows,", ncol(spa), "columns\n")

# The paper says plant type is an attribute, so it's bein' treated
# as a qualitative variable, so usin' dummies. see: table 1
plant_controls <- model.matrix(~ factor(plant), spa)[, -1, drop = FALSE]
colnames(plant_controls) <- paste0("plant_code_", levels(factor(spa$plant))[-1])
# First plant is the reference

spa <- cbind(spa, plant_controls) # plugging the plant labels into the dataset

# The three different types of neonic's bein' tested, straight from the table/data
Label_columns <- c(
  "neonic_text",
  "neonic_logo",
  "neonic_treat"
)

# Settin' up the explanatory variables for the model ("xij" in the paper):
# xij is a vector of plant attributes and individual characteristics that
# influence the consumer's bidding price.
Model_columns <- c(
  Label_columns,
  "bio_pot", # biodegradable container
  colnames(plant_controls)
)

# Labels for recreatin' table 6
Display_labels <- c(
  "Neonicotinoid-free text label",
  "Neonicotinoid-free logo",
  "Neonicotinoid-treated text label"
)

#########################################
# Tobit modelin' equation 1
#########################################

tobit_results <- function(data) {
  X <- cbind(
    1, # intercept column, constant 1
    as.matrix(data[Model_columns]) # adds the explanatory data
  )

  bid <- as.numeric(data$bid)
  zero_bid <- bid == 0

  # Equation 1, found under table 5- simplified to:
  # bid = max(0, X beta + u), u ~ Normal(0, sigma^2)
  negative_log_likelihood <- function(theta) {
    beta <- theta[-length(theta)]
    sigma <- exp(theta[length(theta)])
    xb <- drop(X %*% beta)

    # Probability contribution of zero bids
    zero_part <- -sum(pnorm(-xb[zero_bid] / sigma, log.p = TRUE))
    # Normal density contribution of positive bids
    positive_part <- sum(
      0.5 * ((bid[!zero_bid] - xb[!zero_bid]) / sigma)^2 +
        log(sigma) + 0.5 * log(2 * pi)
    )
    zero_part + positive_part
  }

  # OLS on the positive bids gives starting values for the Tobit
  start_beta <- coef(lm.fit(
    X[!zero_bid, , drop = FALSE],
    bid[!zero_bid]
  ))

  fit <- optim(
    c(start_beta, 0),
    negative_log_likelihood,
    method = "BFGS",
    hessian = TRUE
  )

  theta <- fit$par
  covariance <- solve(fit$hessian)

  #########################################
  # Tobit model equation 2 work
  #########################################

  # wtp function is recreatin' equation 2 from the paper (without the Ci term)
  wtp <- function(theta, k) {
    beta <- theta[-length(theta)]
    sigma <- exp(theta[length(theta)])
    mean(pnorm(drop(X %*% beta) / sigma) * beta[k])
  }

  results <- list()

  # The first three coefficients after the intercept are the three labels
  for (k in 2:4) {
    estimate <- wtp(theta, k)

    # Delta-method standard error with a numerical gradient
    gradient <- numeric(length(theta))
    for (j in seq_along(theta)) {
      change <- numeric(length(theta))
      change[j] <- 1e-5
      gradient[j] <- (wtp(theta + change, k) - wtp(theta - change, k)) / (2e-5)
    }

    se <- sqrt(max(drop(t(gradient) %*% covariance %*% gradient), 0))

    p_value <- 2 * pnorm(-abs(estimate / se)) # two-sided z-test
    if (p_value < 0.001) {
      stars <- "***"
    } else if (p_value < 0.01) {
      stars <- "**"
    } else if (p_value < 0.05) {
      stars <- "*"
    } else {
      stars <- ""
    }

    results[[k - 1]] <- c(estimate, stars, se)
  }

  results
}

#########################################
# Table Creation
#########################################

groups <- list(
  "Sample Total" = spa,
  "Attitude toward pollinator: Agree Group" = spa[spa$att_polen == 1, ],
  "Attitude toward pollinator: Disagree Group" = spa[spa$att_polen == 0, ],
  "Attitude toward neonicotinoid regulation: Agree Group" = spa[spa$att_regulation == 1, ],
  "Attitude toward neonicotinoid regulation: Disagree Group" = spa[spa$att_regulation == 0, ],
  "Attitude toward labeling importance: Important Group" = spa[!is.na(spa$att_importance) & spa$att_importance == 1, ],
  "Attitude toward labeling importance: Unimportant Group" = spa[!is.na(spa$att_importance) & spa$att_importance == 0, ],
  "Overall PEB attitude: PEB Group" = spa[spa$att_overall == 1, ],
  "Overall PEB attitude: Non-PEB Group" = spa[spa$att_overall == 0, ]
)

rows <- list()

for (group_name in names(groups)) {
  group_data <- groups[[group_name]]
  cat("Estimating:", group_name, "(n =", nrow(group_data), ")\n")
  group_results <- tobit_results(group_data) # estimate once per group
  rows[[length(rows) + 1]] <- c(group_name, "", "", "")
  for (i in seq_along(Display_labels)) {
    rows[[length(rows) + 1]] <- c(Display_labels[i], group_results[[i]])
  }
}

tobit_table6 <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
colnames(tobit_table6) <- c("Experimental Auction / Tobit", "WTP Mean", "Significance", "SE")

for (column in c("WTP Mean", "SE")) {
  values <- suppressWarnings(as.numeric(tobit_table6[[column]]))
  tobit_table6[[column]] <- ifelse(is.na(values), "", format(round(values, 3), nsmall = 3))
}

#########################################
# Write outputs
#########################################

write.csv(tobit_table6, "outputs/table6_tobit_wtp.csv", row.names = FALSE)

is_header <- tobit_table6[["WTP Mean"]] == ""
tex_lines <- c(
  "\\begin{tabular}{l r c r}",
  "\\hline",
  "Experimental Auction / Tobit & WTP Mean & Significance & SE \\\\",
  "\\hline"
)
for (r in seq_len(nrow(tobit_table6))) {
  if (is_header[r]) {
    tex_lines <- c(tex_lines, "\\hline",
                   paste0("\\multicolumn{4}{l}{", tobit_table6[r, 1], "} \\\\"), "\\hline")
  } else {
    tex_lines <- c(tex_lines, paste0(paste(tobit_table6[r, ], collapse = " & "), " \\\\"))
  }
}
tex_lines <- c(tex_lines, "\\hline", "\\end{tabular}")
writeLines(tex_lines, "outputs/table6_tobit_wtp.tex")

cat("\nReplicated Table 6:\n")
print(tobit_table6, row.names = FALSE)
cat("\nWrote outputs/table6_tobit_wtp.csv and outputs/table6_tobit_wtp.tex\n")

cat("Total run time:", format(Sys.time() - start_time), "\n\n")
print(sessionInfo())
