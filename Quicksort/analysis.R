# Install packages (run once)
# install.packages("ggplot2")
# install.packages("dplyr")

library(ggplot2)
library(dplyr)

# ============================================================
# STEP 1: LOAD YOUR DATA
# ============================================================
data_dirs <- list.dirs("data", full.names = TRUE, recursive = FALSE)
latest_dir <- data_dirs[which.max(file.info(data_dirs)$mtime)]
measurements_file <- list.files(latest_dir, pattern = "measurements_.*\\.txt$", full.names = TRUE)[1]

raw_data <- read.csv(measurements_file, header = FALSE, skip = 0)

data_list <- list()
current_size <- NA
rep_count <- 0

for (i in 1:nrow(raw_data)) {
  line <- as.character(raw_data[i, 1])
  
  if (grepl("^Size:", line)) {
    current_size <- as.numeric(sub("Size: ", "", line))
    rep_count <- 0
  } else if (grepl("quicksort took:", line)) {
    rep_count <- rep_count + 1
    time_value <- as.numeric(sub(".*took: ([0-9.]+) sec.*", "\\1", line))
    algorithm <- sub(" quicksort.*", "", line)
    
    data_list[[length(data_list) + 1]] <- data.frame(
      size = current_size,
      repetition = rep_count,
      time_sec = time_value,
      algorithm = algorithm
    )
  }
}

df <- do.call(rbind, data_list)
rownames(df) <- NULL

# ============================================================
# STEP 2: CALCULATE CONFIDENCE INTERVALS
# ============================================================
summary_stats <- df %>%
  group_by(size, algorithm) %>%
  summarise(
    mean_time = mean(time_sec),
    sd_time = sd(time_sec),
    n = n(),
    se = sd_time / sqrt(n),
    ci_lower = mean_time - 1.96 * se,
    ci_upper = mean_time + 1.96 * se,
    .groups = 'drop'
  )

print("Summary Statistics with Confidence Intervals:")
print(summary_stats)

# ============================================================
# STEP 3: CREATE PLOT WITH ggplot2
# ============================================================

plot <- ggplot(summary_stats, aes(x = size, y = mean_time, color = algorithm, fill = algorithm)) +
  
  geom_smooth(method = "loess", se = TRUE, linewidth = 1.2, span = 0.8, alpha = 0.2) +
  
  geom_point(size = 3, alpha = 0.8) +
  
  scale_x_log10(labels = scales::comma) +
  scale_y_log10() +
  
  scale_color_manual(values = c("Sequential" = "#E74C3C", 
                                 "Parallel" = "#3498DB", 
                                 "Built-in" = "#2ECC71")) +
  scale_fill_manual(values = c("Sequential" = "#E74C3C", 
                                "Parallel" = "#3498DB", 
                                "Built-in" = "#2ECC71")) +
  
  labs(
    title = "Quicksort Performance Comparison",
    subtitle = "LOESS smoothing with 95% confidence bands on log-log scale",
    x = "Array Size (log scale, elements)",
    y = "Execution Time (log scale, seconds)",
    color = "Algorithm",
    fill = "Algorithm"
  ) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray50"),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "bottom",
    legend.title = element_text(size = 11, face = "bold"),
    panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
    panel.grid.minor = element_line(color = "gray95", linewidth = 0.2),
    panel.border = element_rect(fill = NA, color = "gray50", linewidth = 0.5)
  )

print(plot)

# ============================================================
# STEP 4: SAVE THE PLOT
# ============================================================
output_file <- file.path(latest_dir, "performance_analysis_final.png")
ggsave(output_file, plot, width = 12, height = 7, dpi = 300)
print(paste("✓ Plot saved to:", output_file))

cat("\n========== ANALYSIS COMPLETE ==========\n")
cat("Data loaded from:", latest_dir, "\n")
cat("Total data points:", nrow(df), "\n")
cat("Array sizes tested:", paste(unique(summary_stats$size), collapse = ", "), "\n")
cat("Algorithms compared:", paste(unique(summary_stats$algorithm), collapse = ", "), "\n")