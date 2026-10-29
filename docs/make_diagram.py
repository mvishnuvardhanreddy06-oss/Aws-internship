#!/usr/bin/env python3
"""Draws docs/architecture.png (used in the README and the PDF report). Needs matplotlib."""
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

NAVY, BLUE, GREEN, CREAM = "#0A1330", "#00A8FF", "#6B8E23", "#F4EFE8"
OUT = Path(__file__).resolve().parent / "architecture.png"

fig, ax = plt.subplots(figsize=(10, 7.6), dpi=170)
ax.set_xlim(0, 100)
ax.set_ylim(-9, 77)
ax.axis("off")


def box(x, y, w, h, face, edge, title, lines=(), title_size=10, lw=1.6):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.2,rounding_size=1.2",
                                facecolor=face, edgecolor=edge, linewidth=lw))
    ax.text(x + 1.8, y + h - 2.6, title, fontsize=title_size, color=NAVY, fontweight="bold", va="center")
    for i, line in enumerate(lines):
        ax.text(x + 1.8, y + h - 6.2 - i * 2.9, line, fontsize=8, color="#334155", va="center",
                family="monospace" if line[:1].isdigit() or line.startswith("App") or line.startswith("Bastion") else None)


def arrow(x1, y1, x2, y2, color=BLUE, style="-|>", lw=1.8, dashed=False):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle=style, color=color, lw=lw, linestyle="--" if dashed else "-"))


# Outer boxes
box(3, 3, 43, 48, "#E8F4FB", "#9BCFE8", "VPC A  (ewb-vpc-a)", ["10.10.0.0/16"], 11, 2)
box(54, 3, 43, 48, "#F1F6E8", "#B6D08A", "VPC B  (ewb-vpc-b)", ["10.20.0.0/16", "No internet gateway"], 11, 2)

# Subnets and hosts
box(6, 27, 37, 14, "#DDF0FA", "#9BCFE8", "ewb-a-public", ["10.10.1.0/24", "Bastion / 10.10.1.10 + public IPv4"], 9.5, 1.2)
box(6, 7, 37, 14, "#DDF0FA", "#9BCFE8", "ewb-a-private", ["10.10.2.0/24", "App-A / 10.10.2.10 (no public IP)"], 9.5, 1.2)
box(57, 7, 37, 14, "#E6F0D6", "#B6D08A", "ewb-b-private", ["10.20.1.0/24", "App-B / 10.20.1.10 (no public IP)"], 9.5, 1.2)

# Laptop and IGW
box(24, 67, 27, 8, CREAM, "#CFC7B8", "Your laptop", ["Local key + SSH config"], 9.5, 1.2)
box(24, 56, 27, 7.5, CREAM, "#CFC7B8", "ewb-igw-a", ["Attached to VPC A"], 9.5, 1.2)
arrow(37.5, 67, 37.5, 63.9)
ax.text(39, 65.4, "SSH / 22 (your /32 only)", fontsize=7.5, color="#334155", va="center")
arrow(37.5, 56, 37.5, 41.4)

# Bastion -> App-A (local route)
arrow(24.5, 27, 24.5, 21.4)
ax.text(26, 24.2, "SSH (local route)", fontsize=7.5, color="#334155", va="center")

# Bastion -> App-B (ProxyJump over the peering route)
ax.plot([43.2, 75.5], [32, 32], color=BLUE, lw=1.8, linestyle="--")
arrow(75.5, 32, 75.5, 21.4, dashed=True)
ax.text(47, 34.2, "SSH via bastion (ProxyJump), 10.20.0.0/16 -> pcx", fontsize=7.5, color="#334155", va="center")

# Peering link between the private subnets
ax.plot([43.2, 46], [14, 14], color=GREEN, lw=3)
ax.plot([54, 56.8], [14, 14], color=GREEN, lw=3)
ax.add_patch(FancyBboxPatch((46, 11.2), 8, 5.6, boxstyle="round,pad=0.1,rounding_size=1",
                            facecolor=NAVY, edgecolor=NAVY))
ax.text(50, 14, "PEERING\npcx", fontsize=6.8, color="white", ha="center", va="center", fontweight="bold")
ax.text(50, 9, "App-A <-> App-B\nprivate IPs", fontsize=7, color="#334155", ha="center", va="center")

# Notes
ax.text(3, -1.5, "Administration: laptop > bastion > App-A or App-B (SSH ProxyJump; the bastion opens a separate connection).",
        fontsize=8, color=NAVY, va="center")
ax.text(3, -4.5, "Project traffic: App-A <-> App-B over private IPs and the peering connection (routes on both sides).",
        fontsize=8, color=NAVY, va="center")
ax.text(3, -7.5, "Peering does not give VPC B internet access through VPC A. Diagram is conceptual.",
        fontsize=8, color="#64748B", va="center")

fig.savefig(OUT, bbox_inches="tight", facecolor="white")
print("wrote", OUT)
