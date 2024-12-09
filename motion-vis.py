import os
import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from matplotlib.animation import FuncAnimation

csv_file_path = os.path.join("csv", "exampleLog.csv")  # (CHANGE HERE: set the file name)

# Load the CSV file
df = pd.read_csv(csv_file_path)

# Group data by frames
grouped = df.groupby('Frame')

# Extract unique frames and timestamps
frames = sorted(df['Frame'].unique())
timestamps = df.groupby('Frame')['Timestamp'].first().sort_index().values

# Calculate frame intervals (convert to milliseconds for FuncAnimation)
frame_intervals = [(timestamps[i + 1] - timestamps[i]) * 1000 for i in range(len(timestamps) - 1)]
frame_intervals.append(frame_intervals[-1])  # Repeat the last interval to match the number of frames

# Setup the figure
fig = plt.figure(figsize=(10, 10))
ax = fig.add_subplot(111, projection='3d')

# Set axes limits (adjust based on your data range)
ax.set_xlim([-1, 1])
ax.set_ylim([-1, 1])
ax.set_zlim([-1, 1])
ax.set_xlabel('PositionX')
ax.set_ylabel('PositionY')
ax.set_zlabel('PositionZ')

# Initialize scatter plot (this will be updated during animation)
scatter = None

# Animation update function
def update(frame_index):
    global scatter
    frame = frames[frame_index]  # Get current frame ID
    # Clear previous scatter plot
    if scatter is not None:
        scatter.remove()

    # Get data for the current frame
    data = grouped.get_group(frame)

    # Plot the current frame's points with positions
    scatter = ax.scatter(data['PositionX'], data['PositionY'], data['PositionZ'], s=50, color='blue', label=f"Frame: {frame}")

    # Display rotation information for each joint
    for _, row in data.iterrows():
        joint_name = row['JointName']
        rotation_info = f"R: ({row['RotationX']:.2f}, {row['RotationY']:.2f}, {row['RotationZ']:.2f}, {row['RotationW']:.2f})"

    # Update the title with the frame and timestamp
    ax.set_title(f"Frame: {frame}, Timestamp: {timestamps[frame_index]:.3f}s")
    return scatter,

# Create the animation with dynamic intervals
ani = FuncAnimation(fig, update, frames=len(frames), interval=frame_intervals[0], blit=False)

# Display the animation
plt.show()
