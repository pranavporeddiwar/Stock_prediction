import matplotlib.pyplot as plt
import numpy as np

# Set dark background style
plt.style.use('dark_background')

fig, ax = plt.subplots(figsize=(12, 6))
fig.patch.set_facecolor('#111317')
ax.set_facecolor('#111317')

x_labels = ['30', '90', '180', '360', '720', '1440']
x = np.arange(len(x_labels))

actual = [532.14] * 6
predicted = [485, 510, 525, 531, 532.0, 532.1]

# Plot lines
ax.plot(x, actual, color='#4ade80', marker='s', linestyle='-', linewidth=2, markersize=8, label='Actual Stock Price (Hexaware)')
ax.plot(x, predicted, color='#3b82f6', marker='o', linestyle=':', linewidth=3, markersize=8, label='NeuroTick AI Prediction')

# Y-axis limits
ax.set_ylim(480, 570)

# Grid
ax.grid(color='#2d3748', linestyle='-', linewidth=0.5)

# Labels
ax.set_xticks(x)
ax.set_xticklabels(x_labels)
ax.set_xlabel('AMOUNT OF TRAINING DATA (Number of Days)', color='white')
ax.set_ylabel('STOCK PRICE / PREDICTION VALUE (INR)', color='white')
ax.set_title('EXPERIMENTAL RESULTS: DATA TRAINED vs PREDICTION vs ACTUAL MOVEMENT\nProject Start Day: 11/07/2025', color='white', pad=20, fontsize=14, fontweight='bold')

# Legend
ax.legend(loc='upper left', facecolor='#111317', edgecolor='#4a5568', fontsize=11)

# Annotations
ax.text(0, 525, 'Actual: 532.14\n(Large error)', color='white', ha='center', va='top', fontsize=10)
ax.text(0, 480, 'Pred: 485', color='white', ha='left', va='top', fontsize=10)
ax.text(1, 505, 'Pred: 510', color='white', ha='left', va='top', fontsize=10)

# Experiment 3 Annotation
ax.annotate('EXPERIMENT 3:\n180 DAYS TRAINING,\n98.6% MATCH', 
            xy=(2, 525), xytext=(2.2, 495),
            arrowprops=dict(facecolor='white', arrowstyle='->', color='white', lw=1.5),
            color='white', fontsize=10, ha='left')
ax.text(1.9, 520, 'Pred: 525', color='white', ha='right', va='top', fontsize=10)

ax.text(3, 527, 'Pred: 531', color='white', ha='center', va='top', fontsize=10)

# Experiment 5 Annotation
ax.annotate('EXPERIMENT 5:\n720 DAYS TRAINING,\nNEAR PERFECT MATCH', 
            xy=(4, 532.14), xytext=(3.5, 550),
            arrowprops=dict(facecolor='white', arrowstyle='->', color='white', lw=1.5),
            color='white', fontsize=10, ha='center')
ax.text(4, 527, 'Pred: 532.0\nActual: 532.14', color='white', ha='center', va='top', fontsize=10)

ax.text(5, 527, 'Pred: 532.1\nActual: 532.14', color='white', ha='center', va='top', fontsize=10)

# Make spines gray
for spine in ax.spines.values():
    spine.set_color('#4a5568')

plt.tight_layout()
plt.savefig('experiment_results.png', dpi=300, bbox_inches='tight', facecolor=fig.get_facecolor())
print("Graph generated successfully as experiment_results.png")
