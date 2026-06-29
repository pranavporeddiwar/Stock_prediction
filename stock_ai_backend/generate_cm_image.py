import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# 1. Define the confusion matrix values based on our model's evaluation
TN = 43
FP = 13
FN = 33
TP = 10

# 2. Structure the data as a 2D Numpy Array (matching sklearn's format)
# Format:
# [[ True Negative,  False Positive ],
#  [ False Negative, True Positive ]]
cm = np.array([[TN, FP],
               [FN, TP]])

# 3. Set up the plotting canvas
plt.figure(figsize=(8, 6))

# 4. Create a beautiful heatmap using Seaborn
# We use a custom purple-to-blue colormap to match the app's cyberpunk aesthetic
sns.heatmap(cm, annot=True, fmt='d', cmap='Purples', 
            xticklabels=['Predicted DOWN', 'Predicted UP'],
            yticklabels=['Actual DOWN', 'Actual UP'],
            annot_kws={"size": 16, "weight": "bold"})

# 5. Add Titles and Labels
plt.title('LSTM Model Directional Forecast Confusion Matrix', fontsize=16, fontweight='bold', pad=20)
plt.xlabel('AI Predictions', fontsize=14, labelpad=10)
plt.ylabel('Actual Market Reality', fontsize=14, labelpad=10)

# 6. Adjust layout and save the image
plt.tight_layout()
image_path = 'confusion_matrix.png'
plt.savefig(image_path, dpi=300, bbox_inches='tight')

print(f"Confusion matrix successfully generated and saved as: {image_path}")
