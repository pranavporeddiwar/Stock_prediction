import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report

# 1. Define the confusion matrix values based on our model's evaluation
TN = 43
FP = 13
FN = 33
TP = 10

# 2. Reconstruct y_true and y_pred to generate a perfect classification report string
y_true = [0]*TN + [0]*FP + [1]*FN + [1]*TP
y_pred = [0]*TN + [1]*FP + [0]*FN + [1]*TP

# Generate the classification report text
report_text = classification_report(y_true, y_pred, digits=2)

# Structure the data as a 2D Numpy Array
cm = np.array([[TN, FP],
               [FN, TP]])

# 3. Set up the plotting canvas with enough height for text at the top
fig = plt.figure(figsize=(8, 8))

# 4. Add the classification report text at the very top using a monospace font
# Note: we use fig.text to place it in figure coordinates
fig.text(0.1, 0.95, "Classification Report:\n" + report_text, 
         family='monospace', fontsize=12, va='top', ha='left')

# 5. Create a beautiful heatmap using Seaborn, positioned below the text
# [left, bottom, width, height]
ax = fig.add_axes([0.15, 0.05, 0.7, 0.5]) 
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=ax,
            xticklabels=['0', '1'],
            yticklabels=['0', '1'],
            annot_kws={"size": 14})

# 6. Add Titles and Labels to match the requested style
ax.set_title('Confusion Matrix', fontsize=16, pad=15)
ax.set_xlabel('Predicted', fontsize=14, labelpad=10)
ax.set_ylabel('Actual', fontsize=14, labelpad=10)

# 7. Save the image
image_path = 'confusion_matrix_styled.png'
plt.savefig(image_path, dpi=300, bbox_inches='tight')

print(f"Styled confusion matrix successfully generated and saved as: {image_path}")
