import pandas as pd
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from sklearn.model_selection import train_test_split
import numpy as np
import random

# Fixing random seeds for reproducibility
torch.manual_seed(4)
np.random.seed(4)
random.seed(4)

# Load dataset (RNA-Seq gene expressions and labels)
X_df = pd.read_csv("filtered_data.csv")  # Features (genes)
y_df = pd.read_csv("label_pca.csv")  # Labels

X = X_df.to_numpy(dtype="float32")  # Convert features to NumPy array
y, class_names = pd.factorize(y_df.iloc[:, 0])  # Convert labels to categorical

# Convert to PyTorch tensors
X_tensor = torch.tensor(X, dtype=torch.float32)
y_tensor = torch.tensor(y, dtype=torch.long)

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X_tensor, y_tensor, test_size=0.2, random_state=4)

# Batch size
batch_size = 6

# Create DataLoaders
train_loader = DataLoader(TensorDataset(X_train, y_train), batch_size=batch_size, shuffle=True)
test_loader = DataLoader(TensorDataset(X_test, y_test), batch_size=batch_size, shuffle=False)

# Define Neural Network
class NNet(nn.Module):
    def __init__(self, input_size, num_classes):
        super(NNet, self).__init__()
        self.fc1 = nn.Linear(input_size, 218)  # Hidden layer
        self.fc2 = nn.Linear(218, num_classes)  # Output layer
    
    def forward(self, x):
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

# Initialize model
input_size = X.shape[1]  # Number of genes
num_classes = len(class_names)  # Number of tumor classes

model = NNet(input_size, num_classes).to(torch.device("cpu"))
optimizer = optim.Adadelta(model.parameters(), lr=0.01)
criterion = nn.NLLLoss()

# Training loop
epochs = 20
for epoch in range(epochs):
    model.train()
    for batch_idx, (data, target) in enumerate(train_loader):
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        
        if batch_idx % 10 == 0:
            print(f'Train Epoch: {epoch+1} [{batch_idx * len(data)}/{len(train_loader.dataset)}]  Loss: {loss.item():.6f}')

# Evaluation
total, correct = 0, 0
model.eval()
with torch.no_grad():
    for data, target in test_loader:
        output = model(data)
        pred = output.argmax(dim=1, keepdim=True)
        correct += pred.eq(target.view_as(pred)).sum().item()
        total += target.size(0)

accuracy = 100. * correct / total
print(f'Test Accuracy: {accuracy:.2f}%')

