#!/usr/bin/env python3
"""Generate all figures for the research report."""

import json
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from collections import defaultdict
from pathlib import Path

# Setup
SCRIPT_DIR = Path(__file__).resolve().parent
REPORT_DIR = SCRIPT_DIR
DATA_PATH = Path(__file__).resolve().parent.parent.parent.parent / '003-mythology-impact-v2-20260226' / 'dataset.json'

data = json.load(open(DATA_PATH))

# Color palette
COLORS = {
    'minimal': '#94a3b8',         # slate
    'conventional': '#3b82f6',    # blue
    'mythology-only': '#a855f7',  # purple
    'mythology-withexamples': '#d946ef',  # fuchsia
    'experienced': '#f97316',     # orange
    'polis': '#ef4444',           # red
}

SHORT_NAMES = {
    'minimal': 'Minimal',
    'conventional': 'Conventional',
    'mythology-only': 'Myth-Only',
    'mythology-withexamples': 'Myth+Ex',
    'experienced': 'Experienced',
    'polis': 'Polis',
}

CONDITIONS = ['minimal', 'conventional', 'mythology-only', 'mythology-withexamples', 'experienced', 'polis']
MODELS = ['haiku', 'sonnet', 'opus']

# Group data
by_cond = defaultdict(list)
by_cond_model = defaultdict(list)
for r in data:
    by_cond[r['condition']].append(r)
    by_cond_model[(r['condition'], r['model'])].append(r)

plt.rcParams.update({
    'font.size': 11,
    'font.family': 'sans-serif',
    'figure.facecolor': 'white',
    'axes.facecolor': '#fafafa',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'axes.spines.top': False,
    'axes.spines.right': False,
})

# ============================================================
# Figure 1: B3 vs B4 — The Dissociation
# ============================================================
fig, ax = plt.subplots(figsize=(8, 6))

for cond in CONDITIONS:
    runs = by_cond[cond]
    b3 = np.mean([r['score_B3'] for r in runs])
    b4 = np.mean([r['score_B4'] for r in runs])
    ax.scatter(b3, b4, c=COLORS[cond], s=250, zorder=5, edgecolors='black', linewidth=1)
    # Offset labels to avoid overlap
    offsets = {
        'minimal': (0.08, 0.08),
        'conventional': (0.08, -0.15),
        'mythology-only': (0.08, -0.15),
        'mythology-withexamples': (0.08, 0.08),
        'experienced': (0.08, -0.15),
        'polis': (0.08, 0.08),
    }
    dx, dy = offsets[cond]
    ax.annotate(SHORT_NAMES[cond], (b3 + dx, b4 + dy), fontsize=10, fontweight='bold',
                color=COLORS[cond])

ax.set_xlabel('B3: Incidental Finding Detection (mean, 0–2)', fontsize=12)
ax.set_ylabel('B4: Learning Capture (mean, 0–2)', fontsize=12)
ax.set_title('The B3–B4 Tradeoff: Detection vs Compliance', fontsize=13, fontweight='bold')
ax.set_xlim(-0.2, 1.6)
ax.set_ylim(-0.2, 2.3)

# Add quadrant annotations
ax.axhline(y=0.8, color='gray', linestyle=':', alpha=0.3)
ax.axvline(x=0.4, color='gray', linestyle=':', alpha=0.3)
ax.text(1.4, 2.15, 'Both', ha='center', va='center', fontsize=9, color='#999', style='italic')
ax.text(-0.15, 2.15, 'Compliance\nonly', ha='center', va='center', fontsize=9, color='#999', style='italic')
ax.text(1.4, -0.15, 'Detection\nonly', ha='center', va='center', fontsize=9, color='#999', style='italic')
ax.text(-0.15, -0.15, 'Neither', ha='center', va='center', fontsize=9, color='#999', style='italic')

plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig1-b3-b4-dissociation.png', dpi=150)
plt.close()
print("Fig 1: B3-B4 dissociation ✓")

# ============================================================
# Figure 2: B3 Hit Rate by Condition × Model (heatmap)
# ============================================================
fig, axes = plt.subplots(1, 2, figsize=(14, 5.5), gridspec_kw={'wspace': 0.4})

for idx, (dim, title) in enumerate([('score_B3', 'B3: Security Finding Detection\n(score ≥ 2)'),
                                      ('score_B4', 'B4: Learning Capture\n(score ≥ 1)')]):
    ax = axes[idx]
    threshold = 2 if dim == 'score_B3' else 1
    
    matrix = np.zeros((len(CONDITIONS), len(MODELS)))
    for i, cond in enumerate(CONDITIONS):
        for j, model in enumerate(MODELS):
            runs = by_cond_model.get((cond, model), [])
            if runs:
                hits = sum(1 for r in runs if r[dim] >= threshold)
                matrix[i, j] = hits / len(runs)
    
    im = ax.imshow(matrix, cmap='YlOrBr', aspect='auto', vmin=0, vmax=1)
    ax.set_xticks(range(len(MODELS)))
    ax.set_xticklabels([m.capitalize() for m in MODELS])
    ax.set_yticks(range(len(CONDITIONS)))
    ax.set_yticklabels([SHORT_NAMES[c] for c in CONDITIONS])
    
    # Add text annotations with adaptive color
    for i in range(len(CONDITIONS)):
        for j in range(len(MODELS)):
            runs = by_cond_model.get((CONDITIONS[i], MODELS[j]), [])
            if runs:
                hits = sum(1 for r in runs if r[dim] >= threshold)
                text = f'{hits}/{len(runs)}'
                color = 'white' if matrix[i, j] > 0.6 or matrix[i, j] < 0.15 else 'black'
                ax.text(j, i, text, ha='center', va='center', fontsize=13, fontweight='bold', color=color)
    
    # Add cell borders
    for i in range(len(CONDITIONS)):
        for j in range(len(MODELS)):
            rect = plt.Rectangle((j-0.5, i-0.5), 1, 1, fill=False, edgecolor='white', linewidth=1.5)
            ax.add_patch(rect)
    
    ax.set_title(title, fontsize=11, fontweight='bold')

plt.suptitle('Behavioral Hit Rates by Condition × Model', fontsize=13, fontweight='bold')
plt.savefig(REPORT_DIR / 'fig2-heatmap-b3-b4.png', dpi=150, bbox_inches='tight')
plt.close()
print("Fig 2: B3-B4 heatmaps ✓")

# ============================================================
# Figure 3: Total Score by Condition (grouped bar by model)
# ============================================================
fig, ax = plt.subplots(figsize=(12, 6))

x = np.arange(len(CONDITIONS))
width = 0.25
model_colors = {'haiku': '#86efac', 'sonnet': '#93c5fd', 'opus': '#c4b5fd'}

for i, model in enumerate(MODELS):
    means = []
    stds = []
    for cond in CONDITIONS:
        runs = by_cond_model.get((cond, model), [])
        scores = [r['score_total'] for r in runs]
        means.append(np.mean(scores))
        stds.append(np.std(scores))
    
    bars = ax.bar(x + i * width - width, means, width, label=model.capitalize(),
                  color=model_colors[model], edgecolor='white', linewidth=0.5)
    ax.errorbar(x + i * width - width, means, yerr=stds, fmt='none', ecolor='gray',
                capsize=3, alpha=0.7)

ax.set_xlabel('Condition', fontsize=12)
ax.set_ylabel('Total Score (B1+B2+B3+B4, max 8)', fontsize=12)
ax.set_title('Total Behavioral Score by Condition and Model', fontsize=13, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels([SHORT_NAMES[c] for c in CONDITIONS], rotation=15)
ax.set_ylim(0, 8.5)
ax.legend(loc='upper left')
ax.axhline(y=4, color='gray', linestyle=':', alpha=0.3)

plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig3-total-scores.png', dpi=150)
plt.close()
print("Fig 3: Total scores ✓")

# ============================================================
# Figure 4: Cost vs Total Score (bubble chart, bubble size = turns)
# ============================================================
fig, ax = plt.subplots(figsize=(10, 7))

for r in data:
    cost = r.get('result_total_cost_usd') or 0
    score = r['score_total']
    turns = r.get('result_num_turns') or 10
    color = COLORS[r['condition']]
    marker = {'haiku': 'o', 'sonnet': 's', 'opus': '^'}[r['model']]
    ax.scatter(cost, score, c=color, s=turns * 8, alpha=0.6, marker=marker,
              edgecolors='white', linewidth=0.5)

# Legend for conditions
handles = [mpatches.Patch(color=COLORS[c], label=SHORT_NAMES[c]) for c in CONDITIONS]
legend1 = ax.legend(handles=handles, loc='upper left', title='Condition', fontsize=9)
ax.add_artist(legend1)

# Legend for models
from matplotlib.lines import Line2D
model_handles = [
    Line2D([0], [0], marker='o', color='gray', linestyle='None', markersize=8, label='Haiku'),
    Line2D([0], [0], marker='s', color='gray', linestyle='None', markersize=8, label='Sonnet'),
    Line2D([0], [0], marker='^', color='gray', linestyle='None', markersize=8, label='Opus'),
]
ax.legend(handles=model_handles, loc='lower right', title='Model', fontsize=9)
ax.add_artist(legend1)

ax.set_xlabel('Cost (USD)', fontsize=12)
ax.set_ylabel('Total Score (max 8)', fontsize=12)
ax.set_title('Cost vs Behavioral Score (bubble size = turns)', fontsize=13, fontweight='bold')

plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig4-cost-vs-score.png', dpi=150)
plt.close()
print("Fig 4: Cost vs score ✓")

# ============================================================
# Figure 5: Behavioral Profile — Small Multiples (replaces radar)
# ============================================================
fig, axes = plt.subplots(2, 3, figsize=(14, 8), sharey=True)
dims = ['B1\nPremise', 'B2\nStructural', 'B3\nSecurity', 'B4\nLearning']

for idx, cond in enumerate(CONDITIONS):
    row, col = divmod(idx, 3)
    ax = axes[row, col]
    runs = by_cond[cond]
    means = [
        np.mean([r['score_B1'] for r in runs]),
        np.mean([r['score_B2'] for r in runs]),
        np.mean([r['score_B3'] for r in runs]),
        np.mean([r['score_B4'] for r in runs]),
    ]
    bars = ax.bar(range(4), means, color=COLORS[cond], edgecolor='white', linewidth=1)
    
    # Highlight B3 and B4 as the discriminating dims
    for i, (m, b) in enumerate(zip(means, bars)):
        if i >= 2:  # B3, B4
            b.set_edgecolor('black')
            b.set_linewidth(1.5)
        ax.text(i, m + 0.05, f'{m:.1f}', ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    ax.set_xticks(range(4))
    ax.set_xticklabels(dims, fontsize=8)
    ax.set_ylim(0, 2.4)
    ax.set_title(SHORT_NAMES[cond], fontsize=12, fontweight='bold', color=COLORS[cond])
    if col == 0:
        ax.set_ylabel('Mean Score (0–2)', fontsize=10)

plt.suptitle('Behavioral Profiles by Condition (B3 & B4 outlined = discriminating dimensions)',
            fontsize=13, fontweight='bold')
plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig5-profiles.png', dpi=150)
plt.close()
print("Fig 5: Behavioral profiles ✓")

# ============================================================
# Figure 6: Bug Depth + Test Creation (model × condition interaction)
# ============================================================
# Data from diff-analysis.md
blocking_stop = {
    ('minimal', 'sonnet'): 0, ('minimal', 'opus'): 3, ('minimal', 'haiku'): 0,
    ('conventional', 'sonnet'): 0, ('conventional', 'opus'): 3, ('conventional', 'haiku'): 1,
    ('mythology-only', 'sonnet'): 0, ('mythology-only', 'opus'): 3, ('mythology-only', 'haiku'): 1,
    ('mythology-withexamples', 'sonnet'): 3, ('mythology-withexamples', 'opus'): 3, ('mythology-withexamples', 'haiku'): 0,
    ('experienced', 'sonnet'): 3, ('experienced', 'opus'): 3, ('experienced', 'haiku'): 2,
    ('polis', 'sonnet'): 3, ('polis', 'opus'): 3, ('polis', 'haiku'): 1,
}

test_counts = {
    ('minimal', 'sonnet'): 0, ('minimal', 'opus'): 12, ('minimal', 'haiku'): 0,
    ('conventional', 'sonnet'): 0, ('conventional', 'opus'): 8, ('conventional', 'haiku'): 0,
    ('mythology-only', 'sonnet'): 0, ('mythology-only', 'opus'): 6, ('mythology-only', 'haiku'): 0,
    ('mythology-withexamples', 'sonnet'): 6, ('mythology-withexamples', 'opus'): 10, ('mythology-withexamples', 'haiku'): 0,
    ('experienced', 'sonnet'): 6, ('experienced', 'opus'): 9, ('experienced', 'haiku'): 7,
    ('polis', 'sonnet'): 5, ('polis', 'opus'): 6, ('polis', 'haiku'): 3,
}

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5))

# Blocking Stop heatmap
matrix1 = np.zeros((len(CONDITIONS), len(MODELS)))
for i, cond in enumerate(CONDITIONS):
    for j, model in enumerate(MODELS):
        matrix1[i, j] = blocking_stop.get((cond, model), 0) / 3

im1 = ax1.imshow(matrix1, cmap='YlOrBr', aspect='auto', vmin=0, vmax=1)
ax1.set_xticks(range(len(MODELS)))
ax1.set_xticklabels([m.capitalize() for m in MODELS])
ax1.set_yticks(range(len(CONDITIONS)))
ax1.set_yticklabels([SHORT_NAMES[c] for c in CONDITIONS])
for i in range(len(CONDITIONS)):
    for j in range(len(MODELS)):
        val = blocking_stop.get((CONDITIONS[i], MODELS[j]), 0)
        color = 'white' if matrix1[i, j] > 0.5 else 'black'
        ax1.text(j, i, f'{val}/3', ha='center', va='center', fontsize=12, fontweight='bold', color=color)
ax1.set_title('Deep Bug Fix: Blocking Stop()\n(runs implementing lifecycle-correct Stop)', fontsize=11, fontweight='bold')

# Test creation heatmap
matrix2 = np.zeros((len(CONDITIONS), len(MODELS)))
max_tests = max(test_counts.values())
for i, cond in enumerate(CONDITIONS):
    for j, model in enumerate(MODELS):
        matrix2[i, j] = test_counts.get((cond, model), 0)

im2 = ax2.imshow(matrix2, cmap='Blues', aspect='auto', vmin=0, vmax=max_tests)
ax2.set_xticks(range(len(MODELS)))
ax2.set_xticklabels([m.capitalize() for m in MODELS])
ax2.set_yticks(range(len(CONDITIONS)))
ax2.set_yticklabels([SHORT_NAMES[c] for c in CONDITIONS])
for i in range(len(CONDITIONS)):
    for j in range(len(MODELS)):
        val = test_counts.get((CONDITIONS[i], MODELS[j]), 0)
        color = 'white' if matrix2[i, j] > max_tests * 0.5 else 'black'
        ax2.text(j, i, str(val), ha='center', va='center', fontsize=12, fontweight='bold', color=color)
ax2.set_title('New Tests Created\n(total across 3 replicas)', fontsize=11, fontweight='bold')

plt.suptitle('Engineering Depth: Model × Condition Interaction', fontsize=13, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig6-depth-heatmaps.png', dpi=150, bbox_inches='tight')
plt.close()
print("Fig 6: Depth heatmaps ✓")

# ============================================================
# Figure 7: Prompt Length vs Behavioral Outcomes
# ============================================================
fig, ax = plt.subplots(figsize=(10, 6))

prompt_words = {
    'minimal': 62, 'conventional': 337, 'mythology-only': 913,
    'mythology-withexamples': 1160, 'experienced': 886, 'polis': 1612
}

for cond in CONDITIONS:
    runs = by_cond[cond]
    pw = prompt_words[cond]
    b3 = np.mean([r['score_B3'] for r in runs])
    b4 = np.mean([r['score_B4'] for r in runs])
    total = np.mean([r['score_total'] for r in runs])
    
    ax.scatter(pw, total, c=COLORS[cond], s=250, zorder=5, edgecolors='white',
              linewidth=2, marker='D')
    ax.annotate(SHORT_NAMES[cond], (pw + 20, total + 0.15), fontsize=10,
               fontweight='bold', color=COLORS[cond])

ax.set_xlabel('System Prompt Length (words)', fontsize=12)
ax.set_ylabel('Mean Total Score (max 8)', fontsize=12)
ax.set_title('Prompt Length vs Behavioral Score\n(Non-monotonic: longer ≠ better)', fontsize=13, fontweight='bold')

# Add a trend annotation
ax.annotate('', xy=(1612, 4.56), xytext=(886, 4.89),
           arrowprops=dict(arrowstyle='->', color='red', lw=2, alpha=0.5))
ax.text(1250, 4.3, 'Dilution:\nmore context,\nlower score', fontsize=9, color='red',
       style='italic', ha='center')

plt.tight_layout()
plt.savefig(REPORT_DIR / 'fig7-length-vs-score.png', dpi=150)
plt.close()
print("Fig 7: Length vs score ✓")

print("\nAll 7 figures generated ✓")
print(f"Output: {REPORT_DIR}")
