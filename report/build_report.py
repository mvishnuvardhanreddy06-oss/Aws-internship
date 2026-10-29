#!/usr/bin/env python3
"""
Builds the submission PDF  <YourName>_EWB_VPC_Peering.pdf  from YOUR evidence.

  pip install reportlab pillow
  python3 report/build_report.py            # draft is allowed, missing items are shown as placeholders
  python3 report/build_report.py --strict   # fail unless every required evidence item exists

Reads:  report/report_config.json, report/learning-note.txt,
        evidence/terraform-outputs.json, evidence/logs/*.txt, evidence/screenshots/*.(png|jpg|jpeg)
It never invents results: anything it cannot find is printed as a clearly marked placeholder.
"""
import argparse
import datetime
import json
import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (Image, KeepTogether, PageBreak, Paragraph, Preformatted,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

ROOT = Path(__file__).resolve().parent.parent
EVID = ROOT / "evidence"
LOGS = EVID / "logs"
SHOTS = EVID / "screenshots"
DIAGRAM = ROOT / "docs" / "architecture.png"

NAVY = colors.HexColor("#0A1330")
BLUE = colors.HexColor("#00A8FF")
LIME = colors.HexColor("#A6FF00")
CREAM = colors.HexColor("#F4EFE8")
GREY = colors.HexColor("#64748B")
LIGHT = colors.HexColor("#F3F5F8")
WARN = colors.HexColor("#FFF4CE")

# (file name, title, required)
LOG_FILES = {
    "inv_before": ("00a-inventory-before-peering.txt", "Inventory before peering (stage 1)", True),
    "inv_after": ("00b-inventory-after-peering.txt", "Inventory after peering (stage 2)", True),
    "t01": ("01-baseline.txt", "Test 01 - Baseline failure (App-A to App-B, before peering)", True),
    "t02": ("02-forward-path.txt", "Test 02 - Forward path (App-A to App-B, after routes)", True),
    "t03": ("03-reverse-path.txt", "Test 03 - Reverse path (App-B to App-A, after routes)", True),
    "t04": ("04-private-ssh.txt", "Test 04 - Private SSH to App-B through the bastion", True),
    "t05": ("05-isolation.txt", "Test 05 - Isolation (no public IPv4 on App-A / App-B)", True),
    "t06": ("06-controlled-failure.txt", "Controlled ICMP failure and recovery", True),
    "t07": ("07-cleanup.txt", "Cleanup verification", True),
}
# (file stem, caption, required)
SHOT_FILES = {
    "s01a": ("s01a-subnet-associations", "Checkpoint 01 - subnet associations of ewb-rt-a-public and ewb-rt-a-private", True),
    "s01b": ("s01b-public-default-route", "Checkpoint 01 - ewb-rt-a-public default route to ewb-igw-a", True),
    "s01c": ("s01c-private-rt-local-only", "Checkpoint 01 - ewb-rt-a-private has only its local route (before peering)", True),
    "s02": ("s02-instances", "Checkpoint 02 - instance IDs, private IPs and the bastion public IPv4", True),
    "s03": ("s03-peering-active", "Checkpoint 03 - ewb-a-b-peer is Active (both VPC IDs and CIDRs)", True),
    "s04a": ("s04a-rt-a-private-routes", "Checkpoint 04 - ewb-rt-a-private routes and association", True),
    "s04b": ("s04b-rt-b-private-routes", "Checkpoint 04 - ewb-rt-b-private routes and association", True),
    "s04c": ("s04c-rt-a-public-routes", "Checkpoint 04 - ewb-rt-a-public routes and association", True),
    "s05a": ("s05a-sg-bastion-inbound", "ewb-sg-bastion inbound rules", True),
    "s05b": ("s05b-sg-app-a-inbound", "ewb-sg-app-a inbound rules", True),
    "s05c": ("s05c-sg-app-b-inbound", "ewb-sg-app-b inbound rules", True),
    "s06a": ("s06a-app-a-no-public-ip", "App-A instance details - Public IPv4 address is empty", True),
    "s06b": ("s06b-app-b-no-public-ip", "App-B instance details - Public IPv4 address is empty", True),
    "s07": ("s07-sg-app-b-icmp-removed", "ewb-sg-app-b while the ICMP Echo rule is removed", False),
    "s08": ("s08-cleanup-console", "Console filtered by the project tag after cleanup", False),
}

missing_required = []   # human-readable list of required items not found
found_items = []        # (kind, name)


# ---------------------------------------------------------------- helpers
def latin1(text):
    """Built-in PDF fonts are Latin-1 only; avoid black boxes."""
    return text.expandtabs(4).encode("latin-1", "replace").decode("latin-1")


def check_secrets(name, text):
    bad = [r"PRIVATE KEY-----", r"\bAKIA[0-9A-Z]{16}\b", r"\bASIA[0-9A-Z]{16}\b",
           r"aws_secret_access_key", r"aws_session_token"]
    for pat in bad:
        if re.search(pat, text, re.I):
            sys.exit(f"REFUSING to build: {name} contains something that looks like a secret ({pat}). "
                     "Remove it and run again.")


def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def find_shot(stem):
    for ext in (".png", ".jpg", ".jpeg", ".PNG", ".JPG", ".JPEG"):
        p = SHOTS / f"{stem}{ext}"
        if p.exists():
            return p
    return None


def load_outputs():
    p = EVID / "terraform-outputs.json"
    if not p.exists():
        return {}
    try:
        raw = json.loads(p.read_text())
        return {k: v.get("value") for k, v in raw.items()}
    except Exception as exc:  # noqa: BLE001
        print(f"warning: could not read {p}: {exc}")
        return {}


# ---------------------------------------------------------------- styles
ss = getSampleStyleSheet()
BODY = ParagraphStyle("body", parent=ss["Normal"], fontName="Helvetica", fontSize=9.6, leading=13.6, textColor=NAVY)
SMALL = ParagraphStyle("small", parent=BODY, fontSize=8, leading=10.5, textColor=GREY)
H1 = ParagraphStyle("h1", parent=BODY, fontName="Helvetica-Bold", fontSize=17, leading=21, spaceBefore=4, spaceAfter=6)
H2 = ParagraphStyle("h2", parent=BODY, fontName="Helvetica-Bold", fontSize=11.5, leading=15, spaceBefore=9, spaceAfter=3)
CAP = ParagraphStyle("cap", parent=BODY, fontName="Helvetica-Bold", fontSize=8.6, leading=11, spaceBefore=6, spaceAfter=2)
CELL = ParagraphStyle("cell", parent=BODY, fontSize=8.4, leading=10.6)
CELLB = ParagraphStyle("cellb", parent=CELL, fontName="Helvetica-Bold", textColor=colors.white)
MONO = ParagraphStyle("mono", fontName="Courier", fontSize=6.7, leading=8.1, textColor=NAVY,
                      backColor=LIGHT, borderPadding=4, leftIndent=3, rightIndent=3, spaceAfter=6)
TITLE = ParagraphStyle("title", parent=BODY, fontName="Helvetica-Bold", fontSize=30, leading=34, textColor=colors.white)
SUB = ParagraphStyle("sub", parent=BODY, fontSize=13, leading=18, textColor=colors.HexColor("#C7D2E5"))


def table(rows, widths, header=True, font=CELL):
    data = []
    for i, r in enumerate(rows):
        st = CELLB if (header and i == 0) else font
        data.append([Paragraph(esc(c), st) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [("VALIGN", (0, 0), (-1, -1), "TOP"),
             ("LINEBELOW", (0, 0), (-1, -1), 0.3, colors.HexColor("#DDE3EA")),
             ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    if header:
        style += [("BACKGROUND", (0, 0), (-1, 0), NAVY)]
        style += [("BACKGROUND", (0, i), (-1, i), LIGHT) for i in range(2, len(rows), 2)]
    t.setStyle(TableStyle(style))
    return t


def placeholder(text):
    t = Table([[Paragraph(f"<b>EVIDENCE PENDING</b> - {esc(text)}", CELL)]], colWidths=[17 * cm])
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), WARN), ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#E0B100")),
                           ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
    return t


def log_block(key):
    fname, title, required = LOG_FILES[key]
    path = LOGS / fname
    out = [Paragraph(esc(title), CAP)]
    if path.exists() and path.read_text(errors="replace").strip():
        text = path.read_text(errors="replace")
        check_secrets(fname, text)
        found_items.append(("log", fname))
        out.append(Preformatted(latin1(text.rstrip()), MONO, maxLineLength=120))
        out.append(Paragraph(f"Source: evidence/logs/{esc(fname)}", SMALL))
    else:
        if required:
            missing_required.append(f"evidence/logs/{fname}")
        out.append(placeholder(f"evidence/logs/{fname} not found yet. Create it with the script named in docs/EVIDENCE-CHECKLIST.md."))
    out.append(Spacer(1, 4))
    return out


def shot_block(key):
    stem, caption, required = SHOT_FILES[key]
    p = find_shot(stem)
    out = []
    if p:
        found_items.append(("screenshot", p.name))
        iw, ih = ImageReader(str(p)).getSize()
        scale = min(16.5 * cm / iw, 11.5 * cm / ih)
        img = Image(str(p), width=iw * scale, height=ih * scale)
        img.hAlign = "LEFT"
        out.append(KeepTogether([Paragraph(esc(caption), CAP), img, Paragraph(f"Source: evidence/screenshots/{esc(p.name)}", SMALL), Spacer(1, 6)]))
    else:
        if not required:
            return []  # optional and absent: leave it out of the report
        missing_required.append(f"evidence/screenshots/{stem}.png")
        out.append(Paragraph(esc(caption), CAP))
        out.append(placeholder(f"screenshot evidence/screenshots/{stem}.png not found yet."))
        out.append(Spacer(1, 6))
    return out


# ---------------------------------------------------------------- content
def build(strict):
    cfg = json.loads((Path(__file__).parent / "report_config.json").read_text())
    outs = load_outputs()
    name = cfg.get("name", "Student")
    compact = re.sub(r"[^A-Za-z0-9]", "", name) or "Student"
    out_pdf = Path(__file__).parent / f"{compact}_EWB_VPC_Peering.pdf"
    date_txt = cfg.get("completion_date") or datetime.date.today().strftime("%d %B %Y")
    batch = cfg.get("batch") or "______________________"
    region = cfg.get("region", "ap-south-1 (Mumbai)")

    def ident(key, default="pending - run terraform apply, then scripts/collect-inventory.sh"):
        v = outs.get(key)
        return str(v) if v else default

    story = []

    # --- content sections first (so we know what is missing before writing the cover)
    body = []
    body += [Paragraph("1. Project summary", H1)]
    body += [Paragraph(
        "EWB has an application in VPC A and a second workload in VPC B. Both application servers must stay private. "
        "This project connects the two VPCs with a VPC peering connection so that App-A and App-B exchange traffic over "
        "their private IPv4 addresses, with one public bastion host in VPC A for administration. "
        "The environment was built with Terraform (see the repository), and every test below was run with the scripts in "
        "<font face='Courier'>scripts/</font>.", BODY)]
    body += [Paragraph("What this report demonstrates", H2)]
    for t in ["Non-overlapping VPC and subnet CIDRs (10.10.0.0/16 and 10.20.0.0/16).",
              "Public and private subnets with explicit route table associations.",
              "Active peering, forward and return routes, and inbound rules limited to the required hosts.",
              "A failed test before peering, successful tests after peering, and a controlled failure with recovery."]:
        body.append(Paragraph("&bull; " + esc(t), BODY))

    # 2 architecture + inventory
    body += [PageBreak(), Paragraph("2. Architecture diagram and resource inventory", H1)]
    if DIAGRAM.exists():
        iw, ih = ImageReader(str(DIAGRAM)).getSize()
        s = min(17 * cm / iw, 11.5 * cm / ih)
        body.append(Image(str(DIAGRAM), width=iw * s, height=ih * s))
    body += [Paragraph("Address plan and resource IDs", H2)]
    pending = "pending"
    inv = [["Name tag", "Type", "Resource ID", "CIDR / private IP"],
           ["ewb-vpc-a", "VPC", ident("vpc_a_id", pending), "10.10.0.0/16"],
           ["ewb-a-public", "Subnet", ident("subnet_a_public_id", pending), "10.10.1.0/24"],
           ["ewb-a-private", "Subnet", ident("subnet_a_private_id", pending), "10.10.2.0/24"],
           ["ewb-vpc-b", "VPC", ident("vpc_b_id", pending), "10.20.0.0/16"],
           ["ewb-b-private", "Subnet", ident("subnet_b_private_id", pending), "10.20.1.0/24"],
           ["ewb-igw-a", "Internet gateway", ident("igw_id", pending), "attached to ewb-vpc-a"],
           ["ewb-rt-a-public", "Route table", ident("rt_a_public_id", pending), "-> ewb-a-public"],
           ["ewb-rt-a-private", "Route table", ident("rt_a_private_id", pending), "-> ewb-a-private"],
           ["ewb-rt-b-private", "Route table", ident("rt_b_private_id", pending), "-> ewb-b-private"],
           ["ewb-sg-bastion", "Security group", ident("sg_bastion_id", pending), "VPC A"],
           ["ewb-sg-app-a", "Security group", ident("sg_app_a_id", pending), "VPC A"],
           ["ewb-sg-app-b", "Security group", ident("sg_app_b_id", pending), "VPC B"],
           ["ewb-a-b-peer", "Peering connection", ident("peering_id", pending), "requester VPC A, accepter VPC B"],
           ["ewb-bastion", "EC2 instance", ident("instance_bastion_id", pending),
            "10.10.1.10 + public IPv4 " + ident("bastion_public_ip", "(pending)")],
           ["ewb-app-a", "EC2 instance", ident("instance_app_a_id", pending), "10.10.2.10, no public IP"],
           ["ewb-app-b", "EC2 instance", ident("instance_app_b_id", pending), "10.20.1.10, no public IP"],
           ["ewb-lab", "Key pair", ident("key_name", "ewb-lab"), "private key kept on my laptop only"]]
    body.append(table(inv, [3.2 * cm, 3.0 * cm, 5.6 * cm, 5.2 * cm]))
    body.append(Paragraph(f"Region: {esc(region)}. All resources are tagged Project = EWB-VPC-Peering and Student = {esc(name)}.", SMALL))
    if not outs:
        missing_required.append("evidence/terraform-outputs.json (run scripts/collect-inventory.sh)")
    else:
        found_items.append(("data", "terraform-outputs.json"))

    # 3 subnets and route tables
    body += [PageBreak(), Paragraph("3. Subnets, internet gateway and route tables", H1)]
    body.append(Paragraph(
        "A subnet is public only because its route table has a route to the internet gateway. "
        "<b>ewb-rt-a-public</b> has 0.0.0.0/0 to ewb-igw-a; the two private route tables have no internet route. "
        "VPC B has no internet gateway at all. Each subnet is associated explicitly with its own route table.", BODY))
    rt = [["Route table / associated subnet", "Destination", "Target", "Purpose"],
          ["ewb-rt-a-public / ewb-a-public", "10.10.0.0/16", "local", "Bastion to App-A"],
          ["", "0.0.0.0/0", "ewb-igw-a", "Bastion internet access"],
          ["", "10.20.0.0/16", "pcx (ewb-a-b-peer)", "Bastion SSH to App-B (ProxyJump)"],
          ["ewb-rt-a-private / ewb-a-private", "10.10.0.0/16", "local", "Existing VPC A route"],
          ["", "10.20.0.0/16", "pcx (ewb-a-b-peer)", "App-A to VPC B"],
          ["ewb-rt-b-private / ewb-b-private", "10.20.0.0/16", "local", "Existing VPC B route"],
          ["", "10.10.0.0/16", "pcx (ewb-a-b-peer)", "Return path to VPC A"]]
    body.append(table(rt, [5.4 * cm, 3.0 * cm, 3.6 * cm, 5.0 * cm]))
    body.append(Paragraph("The peering routes are added in stage 2; before peering the private route tables contain only their local route.", SMALL))
    for k in ("s01a", "s01b", "s01c"):
        body += shot_block(k)
    body += log_block("inv_before")
    for k in ("s04a", "s04b", "s04c"):
        body += shot_block(k)

    # 4 peering + SG
    body += [PageBreak(), Paragraph("4. Peering connection and security group rules", H1)]
    body.append(Paragraph(
        "The peering request was created from ewb-vpc-a (requester) to ewb-vpc-b (accepter) in the same account and Region and "
        "accepted. Active status only means the link exists: route tables and security groups decide whether traffic can use it.", BODY))
    body += shot_block("s03")
    sg = [["Security group", "Type / port", "Source", "Why"],
          ["ewb-sg-bastion (VPC A)", "SSH / TCP 22", "my current public IPv4 /32", "Only I can reach the bastion"],
          ["ewb-sg-app-a (VPC A)", "SSH / TCP 22", "10.10.1.10/32 (bastion)", "Administration through the bastion only"],
          ["ewb-sg-app-a (VPC A)", "ICMP Echo request (type 8, code 0)", "10.20.1.10/32 (App-B)", "App-B may ping App-A"],
          ["ewb-sg-app-b (VPC B)", "SSH / TCP 22", "10.10.1.10/32 (bastion)", "ProxyJump source is the bastion private IP"],
          ["ewb-sg-app-b (VPC B)", "ICMP Echo request (type 8, code 0)", "10.10.2.10/32 (App-A)", "App-A may ping App-B"]]
    body.append(table(sg, [4.0 * cm, 4.2 * cm, 4.2 * cm, 4.6 * cm]))
    body.append(Paragraph("Outbound rules stay at the default allow-all; security groups are stateful so replies are allowed automatically. "
                          "Network ACLs are the default allow-all. No rule opens SSH or ICMP to 0.0.0.0/0.", SMALL))
    for k in ("s05a", "s05b", "s05c"):
        body += shot_block(k)
    body += log_block("inv_after")

    # 5 tests
    body += [PageBreak(), Paragraph("5. Test evidence", H1)]
    body.append(Paragraph("Each log below is real output captured by <font face='Courier'>scripts/run-tests.sh</font> from my own run. "
                          "The RESULT lines compare the output with the expected result from the workbook.", BODY))
    exp = [["Test", "Where / command", "Expected result"],
           ["01 Baseline", "App-A, before peering: ping -c 4 10.20.1.10", "No replies"],
           ["02 Forward path", "App-A, after routes: ping -c 4 10.20.1.10", "4 replies; 0% packet loss"],
           ["03 Reverse path", "App-B, after routes: ping -c 4 10.10.2.10", "4 replies; 0% packet loss"],
           ["04 Private SSH", "Laptop: ssh ewb-app-b", "Shell on App-B through bastion"],
           ["05 Isolation", "EC2 instance details: App-A and App-B", "No public IPv4 on either host"]]
    body.append(table(exp, [3.2 * cm, 8.3 * cm, 5.5 * cm]))
    for k in ("t01", "t02", "t03", "t04", "t05"):
        body += log_block(k)
    body += shot_block("s02")
    body += shot_block("s06a")
    body += shot_block("s06b")

    # 6 controlled failure
    body += [PageBreak(), Paragraph("6. Controlled ICMP failure and recovery", H1)]
    body.append(Paragraph(
        "I removed only the inbound ICMP Echo request rule (source 10.10.2.10/32) from <b>ewb-sg-app-b</b> and left the SSH rule in place. "
        "Pinging App-B from App-A then gets no replies, because the destination security group no longer admits the echo requests, "
        "even though peering and both routes are still correct. After restoring the exact rule, replies resumed. "
        "This shows that a working route is necessary but not sufficient: the security group is a separate control.", BODY))
    body += log_block("t06")
    body += shot_block("s07")

    # 7 paths + Q&A
    body += [PageBreak(), Paragraph("7. Forward path and return path", H1)]
    body.append(Paragraph(
        "<b>Forward path.</b> App-A (10.10.2.10) sends an ICMP echo request to 10.20.1.10. The route table ewb-rt-a-private matches "
        "10.20.0.0/16 and sends the packet to the peering connection. It arrives in VPC B, where ewb-sg-app-b allows it because the "
        "source is 10.10.2.10/32.", BODY))
    body.append(Spacer(1, 4))
    body.append(Paragraph(
        "<b>Return path.</b> App-B replies to 10.10.2.10. The route table ewb-rt-b-private matches 10.10.0.0/16 and sends the reply back "
        "through the peering connection. Because security groups are stateful, the reply is allowed without a separate inbound rule on App-A.", BODY))
    body.append(Spacer(1, 4))
    body.append(Paragraph(
        "<b>Administration path.</b> Laptop to the bastion over the internet gateway (SSH from my /32), then from the bastion to App-A over the "
        "local route or to App-B over the peering route. That is why ewb-rt-a-public also needs 10.20.0.0/16 to the peering connection; the more "
        "specific 10.20.0.0/16 route is chosen instead of the 0.0.0.0/0 internet route.", BODY))
    body += [Paragraph("Questions I should be able to explain", H2)]
    qa = [("Why is the return route needed?",
           "Peering does not add routes automatically. VPC B only knows 10.20.0.0/16 until ewb-rt-b-private gets 10.10.0.0/16 to the peering "
           "connection, so a reply to App-A would be dropped and the ping would time out. Routing is needed in both directions."),
          ("Why is the App-B SSH source the bastion private IP?",
           "With ProxyJump the bastion opens its own connection to App-B, so App-B sees 10.10.1.10 as the source. Peering keeps private addresses "
           "(no NAT), so the rule uses 10.10.1.10/32 rather than my laptop's public IP."),
          ("Why does Active peering not guarantee a successful ping?",
           "Active only means the link exists. Traffic also needs routes on both sides, a security group rule on the destination (and a permissive "
           "network ACL), and the correct private addresses."),
          ("Can VPC B use VPC A's internet gateway over peering?",
           "No. Peering is one-to-one and non-transitive; it carries traffic only between the two VPCs' own addresses. It does not share an internet "
           "gateway, NAT or VPN, and VPC B has neither an internet gateway nor a 0.0.0.0/0 route.")]
    for i, (q, a) in enumerate(qa, 1):
        body.append(KeepTogether([Paragraph(f"{i}. {esc(q)}", CAP), Paragraph(esc(a), BODY)]))

    # 8 cleanup + learning
    body += [PageBreak(), Paragraph("8. Cleanup evidence and what I learned", H1)]
    body.append(Paragraph(
        "After saving the evidence I terminated the instances, deleted the peering connection, routes, security groups, subnets, route tables, "
        "internet gateway and both VPCs, deleted the lab key pair, and verified by the project tag that nothing remains.", BODY))
    body += log_block("t07")
    body += shot_block("s08")
    body.append(Paragraph("What I learned", H2))
    note_path = Path(__file__).parent / "learning-note.txt"
    note = note_path.read_text().strip() if note_path.exists() else ""
    if note.startswith("Replace this paragraph"):
        missing_required.append("report/learning-note.txt (still the template text - write it in your own words)")
    for para in [p for p in note.split("\n\n") if p.strip()]:
        body.append(Paragraph(esc(" ".join(para.split())), BODY))

    # appendix
    body += [Paragraph("Appendix - evidence status", H2)]
    rows = [["Item", "Status"]]
    for k, (f, _, req) in LOG_FILES.items():
        rows.append([f"logs/{f}", "found" if ("log", f) in found_items else ("MISSING" if req else "optional, not provided")])
    for k, (stem, _, req) in SHOT_FILES.items():
        p = find_shot(stem)
        rows.append([f"screenshots/{stem}", "found" if p else ("MISSING" if req else "optional, not provided")])
    body.append(table(rows, [11 * cm, 6 * cm]))
    body.append(Paragraph("Repository layout: terraform/ (infrastructure), scripts/ (tests and evidence), docs/ (design and answers), evidence/ (logs and screenshots), report/ (this report).", SMALL))

    # --- cover
    cover = []
    cover.append(Spacer(1, 1.2 * cm))
    cover.append(Paragraph("EWB CLOUD LABS &nbsp;/&nbsp; STUDENT PROJECT REPORT", ParagraphStyle("k", parent=SMALL, textColor=BLUE)))
    cover.append(Spacer(1, 0.6 * cm))
    cover_tbl = Table([[Paragraph("AWS", ParagraphStyle("a", parent=SUB, textColor=BLUE, fontSize=15))],
                       [Paragraph("VPC Peering", TITLE)],
                       [Paragraph("Connect two VPCs.<br/>Prove private connectivity.", SUB)],
                       [Paragraph("A guided networking project with EC2, custom route tables, security groups and a bastion host.",
                                  ParagraphStyle("d", parent=SUB, fontSize=10, leading=14))]], colWidths=[17 * cm])
    cover_tbl.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), NAVY), ("LEFTPADDING", (0, 0), (-1, -1), 18),
                                   ("TOPPADDING", (0, 0), (-1, -1), 10), ("BOTTOMPADDING", (0, 0), (-1, -1), 10)]))
    cover.append(cover_tbl)
    cover.append(Spacer(1, 1.0 * cm))
    cover.append(Paragraph("AWS ARCHITECT ASSOCIATE &nbsp;/&nbsp; PROJECT 01", ParagraphStyle("l", parent=BODY, fontName="Helvetica-Bold")))
    cover.append(Spacer(1, 0.4 * cm))
    cover.append(table([["Name", name], ["Batch", batch], ["Project title", cfg.get("project_title", "")],
                        ["Region", region], ["Completion date", date_txt]],
                       [4 * cm, 13 * cm], header=False))
    cover.append(Spacer(1, 0.8 * cm))
    cover.append(Paragraph("Submission file: " + esc(out_pdf.name), SMALL))
    cover.append(Spacer(1, 0.6 * cm))
    if missing_required:
        msg = (f"<b>DRAFT - {len(missing_required)} required item(s) still pending.</b> "
               "Placeholders in this document are marked EVIDENCE PENDING. Run the lab, collect the evidence "
               "(docs/EVIDENCE-CHECKLIST.md) and rebuild with <font face='Courier'>python3 report/build_report.py --strict</font> before submitting.")
        box = Table([[Paragraph(msg, CELL)]], colWidths=[17 * cm])
        box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), WARN), ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#E0B100")),
                                 ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
    else:
        box = Table([[Paragraph("<b>Evidence complete.</b> All required logs and screenshots were found.", CELL)]], colWidths=[17 * cm])
        box.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#E6F6D8")),
                                 ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#7FB336")),
                                 ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
    cover.append(box)
    cover.append(PageBreak())

    if strict and missing_required:
        print("STRICT MODE: required evidence is missing:")
        for m in missing_required:
            print("  -", m)
        sys.exit(1)

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(GREY)
        canvas.drawString(2 * cm, 1.1 * cm, f"{name}  |  EWB Courses  |  AWS VPC Peering")
        canvas.drawRightString(A4[0] - 2 * cm, 1.1 * cm, f"Page {doc.page}")
        canvas.restoreState()

    doc = SimpleDocTemplate(str(out_pdf), pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=1.8 * cm,
                            bottomMargin=1.9 * cm, title=f"{name} - EWB VPC Peering", author=name,
                            subject="AWS VPC Peering project report")
    doc.build(cover + body, onFirstPage=footer, onLaterPages=footer)
    print(f"Wrote {out_pdf}")
    print(f"Required evidence missing: {len(missing_required)}")
    for m in missing_required:
        print("  -", m)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true", help="fail if any required evidence is missing")
    build(ap.parse_args().strict)
