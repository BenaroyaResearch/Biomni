# Matplotlib Plotting Fix for Dev Container

## Problem
The application was configured to use matplotlib's `tkagg` backend, which requires a display server (X11/GUI). In headless dev containers, this caused plots to fail silently - the code would run without errors but no image files would be created.

## Solution  
Set matplotlib to use the `Agg` backend (non-interactive, file-only) at application startup before any plotting code runs.

## Changes Made

### 1. **biomni/agent/a1.py** (Line ~48)
Added automatic backend configuration:
```python
# Configure matplotlib for headless environments (no display required)
try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend for saving plots to files
except ImportError:
    pass  # matplotlib not installed yet
```

This ensures all tools can save plots without requiring a display.

### 2. **.env** configuration
Added optional `MPLBACKEND` environment variable for advanced users who need different backends.

## Verification

Test that plotting works:
```bash
conda run -n biomni_e1 python test_plotting.py
```

Should output:
```
✓ SUCCESS: Plot saved to /tmp/test_plot.png
✓ File size: ~58000 bytes
```

## What This Fixes

- ✅ Volcano plots from differential expression analysis
- ✅ Heatmaps from clustering analysis  
- ✅ PCA plots from dimensionality reduction
- ✅ Any other matplotlib-based visualizations
- ✅ All plots now save to files as expected

## Technical Details

**Backend options:**
- `Agg` - Non-interactive, saves to files (used now)
- `TkAgg` - Interactive GUI (requires X11/display - old setting)
- `Qt5Agg` - Interactive Qt5 GUI (requires display)

**When plots are generated:**
- Analysis tools automatically save plots to output directories
- Files are typically PNG format at 150-300 DPI
- Look for files like `*_plot.png`, `*_heatmap.png`, `*_volcano.png` etc.

## Troubleshooting

If plots still don't appear:
1. Check the output directory path is writable
2. Verify matplotlib is installed: `conda list matplotlib`
3. Check backend: `python -c "import matplotlib; print(matplotlib.get_backend())"`
   Should show: `Agg`
4. Look for error messages in the tool output logs
