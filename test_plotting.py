#!/usr/bin/env python
"""
Test script to verify matplotlib plotting works in headless mode
"""
import sys
sys.path.insert(0, '/workspace')

# Import biomni agent first to configure matplotlib
from biomni.agent import a1
import matplotlib.pyplot as plt
import numpy as np
import os

# Create a test plot
print("Creating test plot...")
fig, ax = plt.subplots(figsize=(8, 6))
x = np.linspace(0, 10, 100)
y = np.sin(x)
ax.plot(x, y, 'b-', linewidth=2, label='sin(x)')
ax.set_xlabel('X axis')
ax.set_ylabel('Y axis')
ax.set_title('Test Plot - Headless Mode')
ax.legend()
ax.grid(True)

# Save the plot
test_file = '/tmp/test_plot.png'
plt.savefig(test_file, dpi=150, bbox_inches='tight')
plt.close()

# Verify file was created
if os.path.exists(test_file):
    file_size = os.path.getsize(test_file)
    print(f"✓ SUCCESS: Plot saved to {test_file}")
    print(f"✓ File size: {file_size} bytes")
else:
    print("✗ FAILED: Plot file was not created")
    sys.exit(1)
