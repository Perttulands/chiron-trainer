#!/usr/bin/env python3
"""Generate publication-quality figures for the 5-page paper."""

import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D
from collections import defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_PATH = SCRIPT_DIR.parent.parent / 'dataset.json'
OUT_DIR = SCRIPT_DIR

data = json.load(open(DATA_PATH))

# Consistent palette
C = {
    'minimal': '#64748b',
    'conventional': '#2563eb',
    'mythology-only': '#7c3aed',
    'mythology-withexamples': '#c026d3',
    'experienced': '#ea580c',
    'polis': '#dc2626',
}
NAMES = {
    'minimal': 'Minimal',
    'conventional': 'Conventional',
    'mythology-only': 'Myth-Only',
    'mythology-withexamples': 'Myth+Examples',
    'experienced': 'Experienced',
    'polis': 'Polis (Full Stack)',
}
CONDITIONS = ['minimal', 'conventional', 'mythology-only', 'mythology-withexamples', 'experienced', 'polis']
MODELS = ['haiku', 'sonnet', 'opus']

by_cond = defaultdict(list)
by_cm = defaultdict(list)
for r in data:
    by_cond[r['condition']].append(r)
    by_cm[(r['condition'], r['model'])].append(r)

# Publication style
plt.rcParams.update({
    'font.family': 'Liberation Sans',
    'font.size': 9,
    'axes.labelsize': 10,
    'axes.titlesize': 11,
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'axes.grid': False,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.linewidth': 0.8,
    'xtick.major.width': 0.8,
    'ytick.major.width': 0.8,
    'legend.frameon': False,
    'legend.fontsize': 8,
    'figure.dpi': 200,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.1,
})

# ============================================================
# Figure 1: The B3-B4 Tradeoff (hero figure)
# ============================================================
fig, ax = plt.subplots(figsize=(5.5, 4))

for cond in CONDITIONS:
    runs = by_cond[cond]
    b3 = np.mean([r['score_B3'] for r in runs])
    b4 = np.mean([r['score_B4'] for r in runs])
    ax.scatter(b3, b4, c=C[cond], s=180, zorder=5, edgecolors='black', linewidth=0.6)

# Labels with manual offsets to prevent overlap
label_offsets = {
    'minimal': (0.06, 0.06),
    'conventional': (-0.02, -0.18),
    'mythology-only': (0.06, 0.06),
    'mythology-withexamples': (0.06, 0.06),
    'experienced': (0.06, 0.06),
    'polis': (0.06, -0.16),
}
for cond in CONDITIONS:
    runs = by_cond[cond]
    b3 = np.mean([r['score_B3'] for r in runs])
    b4 = np.mean([r['score_B4'] for r in runs])
    dx, dy = label_offsets[cond]
    ax.annotate(NAMES[cond], (b3 + dx, b4 + dy), fontsize=8, fontweight='bold', color=C[cond])

# Quadrant shading
ax.axhspan(0.6, 2.3, xmin=0, xmax=0.35, alpha=0.04, color='blue')
ax.axhspan(-0.25, 0.6, xmin=0.55, xmax=1.0, alpha=0.04, color='orange')
ax.axhspan(0.6, 2.3, xmin=0.55, xmax=1.0, alpha=0.04, color='green')

ax.axhline(y=0.6, color='#ccc', linestyle='-', linewidth=0.5)
ax.axvline(x=0.35, color='#ccc', linestyle='-', linewidth=0.5)

ax.text(1.25, 1.85, 'Both', fontsize=7, color='#888', ha='center', style='italic')
ax.text(-0.12, 1.85, 'Compliance\nonly', fontsize=7, color='#888', ha='center', style='italic')
ax.text(1.25, -0.12, 'Detection\nonly', fontsize=7, color='#888', ha='center', style='italic')

ax.set_xlabel('B3: Incidental Finding Detection (mean)')
ax.set_ylabel('B4: Learning Capture (mean)')
ax.set_xlim(-0.2, 1.5)
ax.set_ylim(-0.25, 2.2)

plt.savefig(OUT_DIR / 'fig1-tradeoff.png', dpi=200)
plt.close()
print("✓ Fig 1")

# ============================================================
# Figure 2: Engineering Depth Unlock (the key finding)
# ============================================================
fig, ax = plt.subplots(figsize=(5.5, 3.2))

# Done-channel rate for Sonnet
done_channel_sonnet = {
    'minimal': 0, 'conventional': 0, 'mythology-only': 0,
    'mythology-withexamples': 3, 'experienced': 3, 'polis': 3,
}
done_channel_haiku = {
    'minimal': 1, 'conventional': 0, 'mythology-only': 1,
    'mythology-withexamples': 1, 'experienced': 3, 'polis': 3,
}

x = np.arange(len(CONDITIONS))
width = 0.35

bars_s = ax.bar(x - width/2, [done_channel_sonnet[c]/3 * 100 for c in CONDITIONS],
               width, label='Sonnet', color='#93c5fd', edgecolor='black', linewidth=0.5)
bars_h = ax.bar(x + width/2, [done_channel_haiku[c]/3 * 100 for c in CONDITIONS],
               width, label='Haiku', color='#bbf7d0', edgecolor='black', linewidth=0.5)

# Opus reference line
ax.axhline(y=100, color='#c4b5fd', linewidth=2, linestyle='--', alpha=0.7)
ax.text(5.3, 98, 'Opus\n(always)', fontsize=7, color='#7c3aed', va='top')

# Annotations for the unlock
ax.annotate('', xy=(2.7, 95), xytext=(2.3, 5),
           arrowprops=dict(arrowstyle='->', color='#c026d3', lw=1.5))
ax.text(2.0, 50, 'Depth\nunlock', fontsize=7, color='#c026d3', ha='center', fontweight='bold')

ax.set_xticks(x)
ax.set_xticklabels([NAMES[c] for c in CONDITIONS], rotation=30, ha='right', fontsize=8)
ax.set_ylabel('Deep Fix Rate (%)')
ax.set_ylim(0, 115)
ax.set_yticks([0, 25, 50, 75, 100])
ax.legend(loc='upper left')

plt.savefig(OUT_DIR / 'fig2-depth-unlock.png', dpi=200)
plt.close()
print("✓ Fig 2")

# ============================================================
# Figure 3: Hit Rate Heatmaps (B3 + B4, condition × model)
# ============================================================
fig, axes = plt.subplots(1, 2, figsize=(5.5, 3.0), gridspec_kw={'wspace': 0.5})

for idx, (dim, title, threshold) in enumerate([
    ('score_B3', 'B3: Security Detection (≥2)', 2),
    ('score_B4', 'B4: Learning Capture (≥1)', 1),
]):
    ax = axes[idx]
    matrix = np.zeros((len(CONDITIONS), len(MODELS)))
    for i, cond in enumerate(CONDITIONS):
        for j, model in enumerate(MODELS):
            runs = by_cm.get((cond, model), [])
            if runs:
                hits = sum(1 for r in runs if r[dim] >= threshold)
                matrix[i, j] = hits / len(runs)

    im = ax.imshow(matrix, cmap='YlOrBr', aspect='auto', vmin=0, vmax=1)
    ax.set_xticks(range(len(MODELS)))
    ax.set_xticklabels([m.capitalize() for m in MODELS], fontsize=8)
    ax.set_yticks(range(len(CONDITIONS)))
    ax.set_yticklabels([NAMES[c] for c in CONDITIONS], fontsize=7)

    for i in range(len(CONDITIONS)):
        for j in range(len(MODELS)):
            runs = by_cm.get((CONDITIONS[i], MODELS[j]), [])
            if runs:
                hits = sum(1 for r in runs if r[dim] >= threshold)
                color = 'white' if matrix[i, j] > 0.55 else 'black'
                ax.text(j, i, f'{hits}/3', ha='center', va='center', fontsize=8,
                       fontweight='bold', color=color)
            # Cell borders
            rect = plt.Rectangle((j-0.5, i-0.5), 1, 1, fill=False,
                               edgecolor='white', linewidth=1)
            ax.add_patch(rect)

    ax.set_title(title, fontsize=9, fontweight='bold', pad=6)

plt.savefig(OUT_DIR / 'fig3-heatmaps.png', dpi=200)
plt.close()
print("✓ Fig 3")

# ============================================================
# Figure 4: Cost by condition × model
# ============================================================
fig, ax = plt.subplots(figsize=(5.5, 3.0))

x = np.arange(len(CONDITIONS))
width = 0.25
model_colors = {'haiku': '#86efac', 'sonnet': '#60a5fa', 'opus': '#a78bfa'}

for i, model in enumerate(MODELS):
    costs = []
    for cond in CONDITIONS:
        runs = by_cm.get((cond, model), [])
        costs.append(np.mean([r.get('result_total_cost_usd') or 0 for r in runs]))
    ax.bar(x + (i-1) * width, costs, width, label=model.capitalize(),
          color=model_colors[model], edgecolor='black', linewidth=0.4)

ax.set_xticks(x)
ax.set_xticklabels([NAMES[c] for c in CONDITIONS], rotation=30, ha='right', fontsize=8)
ax.set_ylabel('Cost per Run (USD)')
ax.legend(loc='upper left', fontsize=7)

# Annotate the Sonnet cost spike
ax.annotate('$1.85\n(3.7× conv.)', xy=(4 - 0.0, 1.85), xytext=(4.5, 1.5),
           fontsize=7, fontweight='bold', color='#2563eb',
           arrowprops=dict(arrowstyle='->', color='#2563eb', lw=1))

plt.savefig(OUT_DIR / 'fig4-cost.png', dpi=200)
plt.close()
print("✓ Fig 4")

print("\nAll figures generated in", OUT_DIR)
