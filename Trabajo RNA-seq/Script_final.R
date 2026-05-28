# Install and load required packages
library(stats)
library(ggplot2)
library(gplots)
library(readr)
library(RColorBrewer)
library(class)  
library(caret)
library(edgeR)
library(Rtsne)

# Load data
data_pca <- read.csv("data.csv", row.names = 1)  # Use row names
label_pca <- read.csv("labels.csv", row.names = 1)  # Ensure labels have row names

# Filter genes that have only zeros
data_pca <- data_pca[, colSums(data_pca != 0) > 0]

# Normalize using edgeR
dge <- DGEList(counts = data_pca)
dge <- calcNormFactors(dge)
logCPM <- cpm(dge, log = TRUE)

# Filter genes with low variance
keep <- apply(logCPM, 1, var) > quantile(apply(logCPM, 1, var), 0.25)  
filtered_data <- logCPM[keep, ]

# Ensure `label_pca` and `filtered_data` have the same samples
common_samples <- intersect(rownames(filtered_data), rownames(label_pca))
filtered_data <- filtered_data[common_samples, ]
label_pca <- label_pca[common_samples, , drop = FALSE]  # Maintain data frame structure

#################################################################

# Perform t-SNE
tsne_result <- Rtsne(filtered_data, perplexity = 30, verbose = TRUE)

# Create a data frame for visualization
df_tsne <- data.frame(
  X = tsne_result$Y[,1],
  Y = tsne_result$Y[,2],
  Cluster = as.factor(label_pca[, 1])
)

# Visualize the results
ggplot(df_tsne, aes(x = X, y = Y, color = Cluster)) + 
  geom_point(size = 2.5) + 
  theme_minimal() +
  labs(title="t-SNE Analysis")

#######################################################

# Perform PCA
pca_result <- prcomp(filtered_data)
df_pca <- data.frame(
  PC1 = pca_result$x[,1],  
  PC2 = pca_result$x[,2],  
  Cluster = as.factor(label_pca$Class)  
)

# Plot PCA results
ggplot(df_pca, aes(x = PC1, y = PC2, color = Cluster)) +
  geom_point(size = 2.5) +
  theme_minimal() +
  labs(title = "PCA Analysis")

#############################################

# Elbow method to determine the optimal number of clusters for KMeans
wss <- numeric(10)  # Store WSS for different k values
for (k in 1:10) {
  kmeans_model <- kmeans(filtered_data, centers = k)
  wss[k] <- kmeans_model$tot.withinss
}

# Plot the elbow method
plot(1:10, wss, type="b", xlab="Number of Clusters",
     ylab="Within-cluster Sum of Squares", main="Elbow Method")

#######################################

# True labels
tf <- as.factor(label_pca$Class)

# Apply KMeans clustering using filtered_data
kmeans_result <- kmeans(filtered_data, centers = 5, nstart = 10)

# Reduce dimensionality using PCA
#pca_result <- prcomp(filtered_data)
Xlowdim <- pca_result$x[, 1:2]  # Take the first two principal components

# Create a data frame for visualization
df <- data.frame(
  PC1 = Xlowdim[, 1],
  PC2 = Xlowdim[, 2],
  KMeans_Cluster = as.factor(kmeans_result$cluster),
  True_Labels = tf
)

# Plot KMeans clustering results
plot_kmeans <- ggplot(df, aes(x = PC1, y = PC2, color = KMeans_Cluster)) +
  geom_point() +
  labs(title = "KMeans Clustering", x = "PC1", y = "PC2") +
  theme_minimal()

# Plot true labels
plot_true_labels <- ggplot(df, aes(x = PC1, y = PC2, color = True_Labels)) +
  geom_point() +
  labs(title = "True Labels", x = "PC1", y = "PC2") +
  theme_minimal()

# Combine both plots
library(gridExtra)
combined_plot <- grid.arrange(plot_kmeans, plot_true_labels, ncol = 2)
print(combined_plot)

##############################################
library(RColorBrewer)

# Compute the standard deviation of each gene (column)
genes_sd <- apply(filtered_data, 2, sd)  # Use 2 because we analyze genes (columns)

# Define a threshold to select the top 10% most variable genes
percentile_cutoff <- 0.9  
threshold <- quantile(genes_sd, percentile_cutoff)

# Filter columns (genes) with higher variability
filtered_genes <- which(genes_sd >= threshold)

# If fewer than 50 genes are selected, take at most 50
dx <- filtered_genes[1:min(50, length(filtered_genes))]

# Define colors for the heatmap
hmcol <- colorRampPalette(brewer.pal(9, "GnBu"))(100)

# Ensure tf has the same length as the number of samples
idxcols <- as.numeric(factor(tf))  

# Generate colors for the samples
cols <- brewer.pal(8, "Dark2")[idxcols]

# Filter sample colors according to selected columns
cols_selected <- cols[1:length(dx)]  # Ensure the length matches ncol(x)

# Generate heatmap with the most variable genes
heatmap.2(filtered_data[, dx, drop = FALSE],  
          labCol = colnames(filtered_data)[dx],  
          labRow = tf,  
          ColSideColors = cols_selected,  # Ensure it matches the selected columns' length
          trace = "none",  
          col = hmcol,  
          scale = "row")

##############################################

# Split data into training and test sets
set.seed(123)
train_index <- sample(1:nrow(filtered_data), size = 0.5 * nrow(filtered_data))
train_x <- as.matrix(filtered_data[train_index, 1:10])  
test_x <- as.matrix(filtered_data[-train_index, 1:10])

train_y <- tf[train_index]
test_y <- tf[-train_index]

# Run KNN with k = 3
knn_pred <- knn(train_x, test_x, train_y, k = 5)

# Compute confusion matrix and error rate
conf_matrix <- confusionMatrix(factor(knn_pred), factor(test_y))
error_rate <- 1 - conf_matrix$overall["Accuracy"]

# Display results
print(conf_matrix)
print(paste("Error Rate:", round(error_rate, 4)))

######################################################

set.seed(123)

# Define training sizes (from 10% to 90% of total data)
train_sizes <- seq(0.1, 0.9, by = 0.1) * nrow(filtered_data)

# Store errors
train_errors <- numeric(length(train_sizes))
test_errors <- numeric(length(train_sizes))

# Loop over different training sizes
for (i in seq_along(train_sizes)) {
  size <- train_sizes[i]
  
  train_index <- sample(1:nrow(filtered_data), size = size)
  train_x <- filtered_data[train_index, ]
  test_x <- filtered_data[-train_index, ]
  
  train_y <- tf[train_index]
  test_y <- tf[-train_index]
  
  # Run KNN
  knn_train_pred <- knn(train_x, train_x, train_y, k = 5)
  knn_test_pred <- knn(train_x, test_x, train_y, k = 5)
  
  # Compute errors
  train_errors[i] <- 1 - mean(knn_train_pred == train_y)
  test_errors[i] <- 1 - mean(knn_test_pred == test_y)
}

# Create a dataframe for plotting
error_df <- data.frame(
  TrainingSize = train_sizes / nrow(filtered_data),
  TrainError = train_errors,
  TestError = test_errors
)

# Plot the error curve
ggplot(error_df, aes(x = TrainingSize)) +
  geom_line(aes(y = TrainError, color = "Training Error"), size = 1) +
  geom_line(aes(y = TestError, color = "Testing Error"), size = 1) +
  labs(title = "Error curve of KNN",
       x = "Proportion of Train Data",
       y = "Error Rate") +
  theme_minimal() +
  scale_color_manual(name = "Error Type", values = c("Training Error" = "blue", "Testing Error" = "red"))
