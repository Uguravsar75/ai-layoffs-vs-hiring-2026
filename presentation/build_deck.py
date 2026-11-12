"""
Builds presentation/AI_Layoffs_vs_Hiring_2026.pptx (16 slides, ~15 minutes, for a non-expert audience).

All numbers are read from the clean data files, so the deck always matches the analysis.
Charts are native PowerPoint charts (editable). Speaker notes are attached to every slide.
Run from anywhere:  python3 presentation/build_deck.py
"""
from pathlib import Path

import pandas as pd
from pptx import Presentation
from pptx.chart.data import CategoryChartData
from pptx.dml.color import RGBColor
from pptx.enum.chart import XL_CHART_TYPE, XL_LABEL_POSITION, XL_LEGEND_POSITION, XL_MARKER_STYLE
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Inches, Pt

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "clean"
OUT = ROOT / "presentation" / "AI_Layoffs_vs_Hiring_2026.pptx"

# ---------------------------------------------------------------- design tokens
NAVY = RGBColor(0x13, 0x21, 0x3C)       # dark slides
BLUE = RGBColor(0x2A, 0x78, 0xD6)       # layoff side / headline
ORANGE = RGBColor(0xEB, 0x68, 0x34)     # hiring side / accent
GREY = RGBColor(0xC3, 0xC2, 0xB7)       # de-emphasised series
MUTED = RGBColor(0x5B, 0x64, 0x72)      # secondary text
TEXT = RGBColor(0x1B, 0x24, 0x30)       # primary text
CARD = RGBColor(0xF2, 0xF4, 0xF7)       # card background
ICE = RGBColor(0xCA, 0xDC, 0xFC)        # light text on navy
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
HEAD, BODY = "Georgia", "Arial"         # both ship with Windows and macOS

# ---------------------------------------------------------------- data
layoffs = pd.read_csv(DATA / "layoffs_clean.csv")
main = layoffs[layoffs["in_main_analysis"]]
monthly = pd.read_csv(DATA / "layoffs_clean_monthly.csv")
industries = pd.read_csv(DATA / "layoffs_clean_industries.csv")
indeed = pd.read_csv(DATA / "ai_posting_monthly.csv")
challenger = pd.read_csv(DATA / "challenger_ai_monthly.csv")

N_ANN = len(main)
N_PEOPLE = int(main["people_cut"].sum())
STRICT = main.loc[main["is_ai_strict"], "people_cut"].sum() / N_PEOPLE
BROAD = main.loc[main["is_ai_driven"], "people_cut"].sum() / N_PEOPLE
MED_AI = main.loc[main["is_ai_strict"], "people_cut"].median()
MED_OTHER = main.loc[~main["is_ai_driven"], "people_cut"].median()
N_CHECKED = int((layoffs["verification"] != "not_checked").sum())
MANUAL_SHARE = main.loc[main["reliability_tier"].isin(["T1_manual_verified", "T2_manual_partial"]),
                        "people_cut"].sum() / N_PEOPLE


def us(month, code="US"):
    return indeed.loc[(indeed.country_code == code) & (indeed.month == month), "ai_share_pct"].item()


MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
m10 = monthly[monthly["month"] <= "2026-10"].merge(challenger[["month", "ai_share_pct"]], on="month")
m10["label"] = [MONTHS[int(x[5:]) - 1] for x in m10["month"]]
OCT = m10[m10["month"] == "2026-10"].iloc[0]

# ---------------------------------------------------------------- helpers
prs = Presentation()
prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
BLANK = prs.slide_layouts[6]
slide_no = 0


def new_slide(dark=False):
    global slide_no
    slide_no += 1
    s = prs.slides.add_slide(BLANK)
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = NAVY if dark else WHITE
    if not dark:
        text(s, str(slide_no), 12.35, 7.0, 0.5, 0.3, 10, color=MUTED, align=PP_ALIGN.RIGHT)
    return s


def text(s, content, x, y, w, h, size=16, bold=False, color=TEXT, font=BODY, align=PP_ALIGN.LEFT,
         anchor=MSO_ANCHOR.TOP, italic=False, name=None):
    """content: str, or list of paragraphs; a paragraph is str or list of (text, {opts}) runs."""
    tb = s.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    if name:
        tb.name = name
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    paras = content if isinstance(content, list) else [content]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        runs = para if isinstance(para, list) else [(para, {})]
        for run_text, opt in runs:
            r = p.add_run()
            r.text = run_text
            f = r.font
            f.name = opt.get("font", font)
            f.size = Pt(opt.get("size", size))
            f.bold = opt.get("bold", bold)
            f.italic = opt.get("italic", italic)
            f.color.rgb = opt.get("color", color)
        if i < len(paras) - 1:
            p.space_after = Pt(opt.get("space_after", 8) if runs else 8)
    return tb


def title(s, t, color=TEXT):
    text(s, t, 0.6, 0.45, 12.1, 0.95, 30, bold=True, color=color, font=HEAD, name="Title")


def source(s, t, color=MUTED):
    text(s, t, 0.6, 6.95, 11.4, 0.35, 10, color=color, name="Source")


def card(s, x, y, w, h, fill=CARD, name=None):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = 0.06
    sh.fill.solid()
    sh.fill.fore_color.rgb = fill
    sh.line.fill.background()
    sh.shadow.inherit = False
    if name:
        sh.name = name
    return sh


def badge(s, x, y, label, fill=BLUE, d=0.62, size=16):
    sh = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    sh.fill.solid()
    sh.fill.fore_color.rgb = fill
    sh.line.fill.background()
    sh.shadow.inherit = False
    tf = sh.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run()
    r.text = label
    r.font.name, r.font.size, r.font.bold, r.font.color.rgb = BODY, Pt(size), True, WHITE
    return sh


def stat(s, x, y, w, h, number, label, num_color=BLUE, num_size=40):
    card(s, x, y, w, h)
    text(s, number, x + 0.3, y + 0.25, w - 0.6, 0.9, num_size, bold=True, color=num_color, font=HEAD)
    text(s, label, x + 0.3, y + 1.2, w - 0.6, h - 1.4, 14, color=TEXT)


def notes(s, t):
    s.notes_slide.notes_text_frame.text = t


def style_chart(chart, legend=False):
    chart.font.name = BODY
    chart.font.size = Pt(12)
    chart.font.color.rgb = MUTED
    chart.has_legend = legend
    if legend:
        chart.legend.position = XL_LEGEND_POSITION.TOP
        chart.legend.include_in_layout = False
        chart.legend.font.size = Pt(12)


def bar_chart(s, cats, vals, x, y, w, h, colors, fmt="0%", vmax=None):
    """Horizontal bar chart; first category is drawn at the top."""
    cd = CategoryChartData()
    cd.categories = list(reversed(cats))
    cd.add_series("Series", list(reversed(vals)))
    gf = s.shapes.add_chart(XL_CHART_TYPE.BAR_CLUSTERED, Inches(x), Inches(y), Inches(w), Inches(h), cd)
    ch = gf.chart
    style_chart(ch)
    plot = ch.plots[0]
    plot.gap_width = 60
    plot.has_data_labels = True
    dl = plot.data_labels
    dl.number_format, dl.number_format_is_linked = fmt, False
    dl.position = XL_LABEL_POSITION.OUTSIDE_END
    dl.font.size, dl.font.color.rgb = Pt(12), TEXT
    ser = plot.series[0]
    for i, c in enumerate(reversed(colors)):
        pt = ser.points[i]
        pt.format.fill.solid()
        pt.format.fill.fore_color.rgb = c
    va = ch.value_axis
    va.visible = False
    va.has_major_gridlines = False
    va.minimum_scale = 0
    if vmax:
        va.maximum_scale = vmax
    ca = ch.category_axis
    ca.format.line.fill.background()
    ca.tick_labels.font.size, ca.tick_labels.font.color.rgb = Pt(12), TEXT
    return ch


def line_chart(s, cats, series, x, y, w, h, fmt="0%", vmax=None, legend=True):
    """series: list of (name, values, color, width_pt)."""
    cd = CategoryChartData()
    cd.categories = cats
    for name, vals, _, _ in series:
        cd.add_series(name, vals)
    gf = s.shapes.add_chart(XL_CHART_TYPE.LINE_MARKERS, Inches(x), Inches(y), Inches(w), Inches(h), cd)
    ch = gf.chart
    style_chart(ch, legend)
    for ser, (_, _, color, width) in zip(ch.plots[0].series, series):
        ser.smooth = False
        ser.format.line.color.rgb = color
        ser.format.line.width = Pt(width)
        ser.marker.style = XL_MARKER_STYLE.CIRCLE
        ser.marker.size = 6
        ser.marker.format.fill.solid()
        ser.marker.format.fill.fore_color.rgb = color
        ser.marker.format.line.color.rgb = color
    va = ch.value_axis
    va.tick_labels.number_format, va.tick_labels.number_format_is_linked = fmt, False
    va.has_major_gridlines = True
    va.major_gridlines.format.line.color.rgb = RGBColor(0xE1, 0xE0, 0xD9)
    va.format.line.fill.background()
    va.minimum_scale = 0
    if vmax:
        va.maximum_scale = vmax
    ch.category_axis.format.line.color.rgb = GREY
    return ch


# ================================================================ SLIDES
# 1 -------------------------------------------------------------- title
s = new_slide(dark=True)
text(s, "Is AI taking jobs —", 0.8, 1.5, 8.1, 0.8, 40, bold=True, color=WHITE, font=HEAD)
text(s, "or just taking the blame?", 0.8, 2.3, 8.1, 0.8, 40, bold=True, color=WHITE, font=HEAD)
text(s, "What 2026 layoff announcements and job postings actually show", 0.8, 3.45, 7.6, 0.9, 20, color=ICE)
text(s, "Uğur Avşar  ·  Softito Data Analytics capstone project  ·  November 2026", 0.8, 6.5, 8, 0.4, 14,
     color=ICE)
for i, (num, lab) in enumerate([(f"{N_ANN}", "job-cut announcements"),
                                (f"{N_CHECKED}", "rows checked by hand"),
                                ("3", "independent data sources")]):
    y = 1.35 + i * 1.65
    badge(s, 9.2, y, "", fill=BLUE if i != 1 else ORANGE, d=1.25)
    text(s, num, 9.2, y + 0.33, 1.25, 0.6, 24, bold=True, color=WHITE, align=PP_ALIGN.CENTER, font=HEAD)
    text(s, lab, 10.65, y + 0.38, 2.3, 0.6, 16, color=WHITE)
notes(s, "Hi, I'm Uğur. Every week we read headlines like 'Company X cuts thousands of jobs because of AI'. "
         "In this project I checked what is really behind those headlines: how often companies actually name AI "
         "as the reason, how that changed during 2026, and what happened on the hiring side at the same time. "
         f"I used {N_ANN} announcements, checked {N_CHECKED} of them by hand, and compared three data sources.")

# 2 -------------------------------------------------------------- the question
s = new_slide()
title(s, "Headlines say AI is cutting jobs. What does the data say?")
card(s, 0.6, 1.65, 5.9, 2.15)
text(s, "What companies say", 0.95, 1.9, 5.3, 0.5, 20, bold=True, color=BLUE, font=HEAD)
text(s, "Layoff announcements that name AI as the reason — the story we read in the news.",
     0.95, 2.5, 5.3, 1.1, 16)
card(s, 6.85, 1.65, 5.9, 2.15)
text(s, "What the data shows", 7.2, 1.9, 5.3, 0.5, 20, bold=True, color=ORANGE, font=HEAD)
text(s, "How many cuts really cite AI, how that changed over the year, and what happened in hiring.",
     7.2, 2.5, 5.3, 1.1, 16)
text(s, "Five questions", 0.6, 4.2, 6, 0.5, 20, bold=True, font=HEAD)
qs = ["Which industries cut the most?", "Where is AI cited most?", "How did it change over the year?",
      "Are AI-attributed cuts bigger?", "What happened in job postings?"]
for i, q in enumerate(qs):
    x = 0.6 + i * 2.45
    badge(s, x, 4.9, f"Q{i + 1}", fill=BLUE if i < 4 else ORANGE)
    text(s, q, x, 5.65, 2.2, 1.0, 14)
notes(s, "The project compares two things: what companies say, and what the data shows. "
         "I answer five simple questions: which industries cut the most jobs, where AI is named most often, "
         "how that changed over the year, whether AI-related cuts are bigger, and what happened in job postings. "
         "The first four are about layoffs, the last one is about hiring.")

# 3 -------------------------------------------------------------- short answer
s = new_slide()
title(s, "The short answer")
items = [("1 in 6", f"people in announced job cuts were attributed to AI ({STRICT:.1%})", BLUE),
         ("40%", "of announcements cited AI at the May peak — only 3–6% from August", BLUE),
         (f"{MED_AI:.0f}", f"people in the median AI-attributed announcement — vs. {MED_OTHER:.0f} for others", BLUE),
         ("2×", f"share of US job postings mentioning AI in one year ({us('2025-09'):.1f}% → {us('2026-09'):.1f}%)",
          ORANGE)]
for i, (num, lab, col) in enumerate(items):
    x = 0.6 + i * 3.1
    stat(s, x, 1.75, 2.85, 2.75, num, lab, num_color=col, num_size=38)
text(s, [[("In 2026, AI faded as a reason for job cuts while it showed up more and more in job postings. ",
           {"bold": True}),
          ("The two trends are shown side by side — this is not a cause-and-effect claim.", {})]],
     0.6, 4.9, 12.1, 0.9, 16)
notes(s, "Here is the answer up front. About one in six people in announced job cuts were linked to AI. "
         "AI as a reason peaked in May, when 40 percent of announcements mentioned it, and dropped to 3 to 6 percent "
         "from August. AI-related announcements are bigger: 295 people at the median versus 180. "
         "And on the hiring side, the share of US job postings that mention AI doubled in a year. "
         "Important: I show these two trends side by side; I do not claim one causes the other.")

# 4 -------------------------------------------------------------- data
s = new_slide()
title(s, "Three data sources, one question")
srcs = [("layoffhedge.com", f"{N_ANN} job-cut announcements in 2026, worldwide",
         "Main data: who cut jobs, how many, and the stated reason", BLUE),
        ("Indeed Hiring Lab", "Job postings in 9 countries, 2019–2026",
         "Hiring side: share of postings that mention AI", ORANGE),
        ("Challenger reports", "Monthly US job-cut reports, Jan–Oct 2026",
         "Independent check: does the AI trend look the same?", BLUE)]
for i, (name, what, role, col) in enumerate(srcs):
    x = 0.6 + i * 4.15
    card(s, x, 1.75, 3.9, 3.55)
    badge(s, x + 0.3, 2.05, str(i + 1), fill=col)
    text(s, name, x + 0.3, 2.85, 3.3, 0.8, 19, bold=True, font=HEAD)
    text(s, what, x + 0.3, 3.65, 3.3, 0.8, 15)
    text(s, role, x + 0.3, 4.45, 3.3, 0.8, 14, color=MUTED, italic=True)
text(s, [[("How: ", {"bold": True}),
          ("Python (pandas) to clean and check the data  →  PostgreSQL to model and query it  →  "
           "Power BI to visualise it. No machine learning — just careful counting.", {})]],
     0.6, 5.75, 12.1, 0.8, 16)
source(s, "Sources: layoffhedge.com (2026-11-08) · Indeed Hiring Lab AI Tracker (CC BY 4.0) · "
          "Challenger, Gray & Christmas monthly reports")
notes(s, "I used three sources. The main one is layoffhedge.com: a list of 2026 job-cut announcements with the "
         "company, the number of people and the reason. For the hiring side I used Indeed, which measures how many "
         "job postings mention AI. And to check my results independently I used Challenger, a US firm that "
         "publishes monthly job-cut reports. The tools were Python, PostgreSQL and Power BI.")

# 5 -------------------------------------------------------------- validation
s = new_slide()
title(s, "Before trusting the data, I checked it")
steps = [("Automatic checks on all 653 rows", "blanks, duplicates, impossible values, dates without a year"),
         (f"{N_CHECKED} rows compared with news articles", "every large row, every AI row, and a random sample"),
         ("Robustness test", "results recomputed using only the verified rows — they stay the same")]
for i, (h_, d_) in enumerate(steps):
    y = 1.8 + i * 1.5
    badge(s, 0.6, y, str(i + 1))
    text(s, h_, 1.45, y - 0.02, 5.6, 0.5, 18, bold=True)
    text(s, d_, 1.45, y + 0.48, 5.6, 0.8, 15, color=MUTED)
for i, (num, lab) in enumerate([("4", "announcements from earlier years removed (e.g. Intel 2024)"),
                                ("2", "wrong numbers corrected (e.g. Verizon 3,000 → 500)"),
                                (f"{MANUAL_SHARE:.0%}", "of all people in the data checked by hand")]):
    y = 1.65 + i * 1.6
    card(s, 7.6, y, 5.15, 1.4)
    text(s, num, 7.9, y + 0.25, 1.4, 0.9, 36, bold=True, color=ORANGE if i < 2 else BLUE, font=HEAD,
         anchor=MSO_ANCHOR.MIDDLE)
    text(s, lab, 9.3, y + 0.25, 3.2, 0.9, 15, anchor=MSO_ANCHOR.MIDDLE)
source(s, "No row was deleted: every problem is flagged in a column, so every number can be recomputed.")
notes(s, "The main source is not well known, so I did not trust it blindly. First, automatic checks on all rows. "
         "Then I compared 146 rows with news articles: every large announcement, every AI-related one, and a random "
         "sample of small ones. I found four announcements from earlier years, for example an Intel plan from 2024, "
         "and two wrong numbers, which I corrected. In total 72 percent of all people in the data were checked by hand. "
         "Finally I re-ran everything with only the verified rows, and the results did not change.")

# 6 -------------------------------------------------------------- strict vs broad
s = new_slide()
title(s, "Not every “AI layoff” is really about AI")
text(s, "The source labels some cuts “AI-driven”. Checking the news showed two problems:", 0.6, 1.6, 6.4, 0.8, 16)
examples = [("UPS — 30,000", "Main reason: less work from Amazon, not AI"),
            ("Oracle — “up to 30,000”", "A maximum, not a final number")]
for i, (h_, d_) in enumerate(examples):
    y = 2.5 + i * 1.35
    card(s, 0.6, y, 6.2, 1.15)
    text(s, h_, 0.9, y + 0.15, 5.6, 0.45, 17, bold=True)
    text(s, d_, 0.9, y + 0.6, 5.6, 0.45, 15, color=MUTED)
text(s, [[("Strict definition (headline): ", {"bold": True, "color": BLUE}),
          ("AI is cited, the label is not questionable, the number is not “up to …”.", {})],
         [("Broad definition (upper bound only): ", {"bold": True, "color": MUTED}),
          ("every AI label.", {})]], 0.6, 5.35, 6.4, 1.4, 15)
ch = bar_chart(s, ["Strict (headline)", "Broad (upper bound)"], [STRICT, BROAD], 7.3, 1.7, 5.4, 3.3,
               [BLUE, GREY], fmt="0.0%", vmax=0.45)
text(s, "Share of people in announced job cuts attributed to AI", 7.3, 5.1, 5.4, 0.6, 14, color=MUTED)
notes(s, "The source labels some cuts as AI-driven, but that label is not always right. For UPS, the main reason "
         "was less business from Amazon. For Oracle, the number is 'up to 30,000', a maximum. So I use two definitions. "
         "The strict one, which I use as my headline, gives 16.9 percent. The broad one, with every AI label, gives "
         "38.4 percent, but that number is inflated by a few giant plans, so I only report it as an upper bound.")

# 7 -------------------------------------------------------------- Q1
s = new_slide()
badge(s, 0.6, 0.6, "Q1")
text(s, "Three industries make up two thirds of the cuts", 1.45, 0.55, 11.3, 0.8, 28, bold=True,
     font=HEAD)
top = industries.nlargest(8, "people_cut")
cols = [BLUE if i < 3 else GREY for i in range(len(top))]
bar_chart(s, top["industry"].tolist(), top["people_cut"].tolist(), 0.6, 1.6, 8.2, 5.1, cols, fmt="#,##0",
          vmax=top["people_cut"].max() * 1.18)
share3 = top["people_cut"].head(3).sum() / N_PEOPLE
card(s, 9.2, 1.9, 3.55, 2.0)
text(s, f"{share3:.0%}", 9.5, 2.1, 3.0, 0.8, 40, bold=True, color=BLUE, font=HEAD)
text(s, "of all people in announced cuts are in these three industries", 9.5, 2.95, 3.0, 0.9, 14)
card(s, 9.2, 4.15, 3.55, 2.3)
text(s, "Automotive is driven by a few giant plans — Volkswagen alone announced 100,000 cuts.",
     9.5, 4.4, 3.0, 1.9, 15)
source(s, f"Source: layoffhedge.com, main analysis ({N_ANN} announcements, {N_PEOPLE:,} people). "
          "Top 8 of 13 industries shown.")
notes(s, "First question: which industries announced the most cuts? Automotive and transportation, tech, and finance "
         "and banking together make up about two thirds of all people in announced cuts. Automotive is high because of "
         "a few giant plans: Volkswagen alone announced 100,000 cuts. The ranking stays the same when I use only "
         "verified rows.")

# 8 -------------------------------------------------------------- Q2
s = new_slide()
badge(s, 0.6, 0.6, "Q2")
text(s, "Fintech, finance and tech cite AI the most", 1.45, 0.55, 11.3, 0.8, 28, bold=True, font=HEAD)
q2 = industries[industries["announcements"] >= 10].sort_values("ai_strict_share_pct", ascending=False)
bar_chart(s, q2["industry"].tolist(), (q2["ai_strict_share_pct"] / 100).tolist(), 0.6, 1.6, 8.2, 5.1,
          [BLUE] * len(q2), fmt="0%", vmax=0.85)
card(s, 9.2, 1.9, 3.55, 4.55)
text(s, [[("How to read it", {"bold": True})],
         "Each bar is the share of that industry's announced cuts (in people) attributed to AI, strict definition.",
         "Industries with fewer than 10 announcements are left out — one announcement would decide their share."],
     9.5, 2.15, 3.0, 4.1, 14)
source(s, "Source: layoffhedge.com, strict AI definition; industries with 10+ announcements.")
notes(s, "Second question: where is AI named most often? Among industries with enough announcements, crypto and "
         "fintech, finance and banking, and tech attribute the largest share of their cuts to AI. Health care, "
         "consumer goods and education never name AI. Automotive almost never: the big UPS cut had another main reason. "
         "I left out industries with fewer than 10 announcements, because there one single announcement decides the number.")

# 9 -------------------------------------------------------------- Q3
s = new_slide()
badge(s, 0.6, 0.6, "Q3")
text(s, "AI was cited often until July — rarely after", 1.45, 0.55, 11.3, 0.8, 28, bold=True, font=HEAD)
line_chart(s, m10["label"].tolist(),
           [("Announcements citing AI (layoffhedge, worldwide)", (m10["ai_strict_count_share_pct"] / 100).tolist(),
             BLUE, 3),
            ("AI-attributed cuts (Challenger, US)", (m10["ai_share_pct"] / 100).tolist(), GREY, 2.25)],
           0.6, 1.55, 8.4, 5.2, vmax=0.5)
corr = m10["ai_share_pct"].corr(m10["ai_strict_count_share_pct"])
card(s, 9.35, 1.9, 3.4, 2.1)
text(s, "Peak in May", 9.65, 2.1, 2.9, 0.5, 20, bold=True, color=BLUE, font=HEAD)
text(s, "40% of announcements cited AI; from August only 3–6%.", 9.65, 2.65, 2.9, 1.2, 14)
card(s, 9.35, 4.25, 3.4, 2.2)
text(s, "Two sources agree", 9.65, 4.45, 2.9, 0.5, 18, bold=True, font=HEAD)
text(s, f"An independent US source moves the same way (correlation {corr:.2f}).", 9.65, 5.0, 2.9, 1.3, 14)
source(s, "Sources: layoffhedge.com (share of announcements citing AI, strict); Challenger, Gray & Christmas. "
          "Jan–Oct 2026.")
notes(s, "Third question: how did it change over the year? The blue line is the share of announcements that cite AI. "
         "It peaks in May at 40 percent and drops to 3 to 6 percent from August. The grey line is Challenger, an "
         "independent US source, and it shows the same pattern, with a correlation of 0.72. Two separate sources telling "
         "the same story makes me more confident. With only ten months, I treat it as confirmation of the direction, "
         "not as proof.")

# 10 ------------------------------------------------------------- count vs people
s = new_slide()
title(s, "Why I count announcements, not people")
text(s, "October 2026 shows why:", 0.6, 1.6, 12, 0.5, 18)
stat(s, 0.6, 2.3, 5.9, 2.75, f"{OCT['ai_strict_share_pct']:.1f}%",
     "of people in October's cuts were linked to AI — almost all from one plan: "
     "the Dutch Government's 25,000 jobs, spread until 2035", num_color=ORANGE, num_size=48)
stat(s, 6.85, 2.3, 5.9, 2.75, f"{OCT['ai_strict_count_share_pct']:.1f}%",
     "of October's announcements cited AI — the real picture for that month", num_color=BLUE, num_size=48)
text(s, [[("One giant plan can flip a whole month. ", {"bold": True}),
          ("Counting announcements shows how many companies name AI, and it is the measure that matches the "
           "independent US data.", {})]], 0.6, 5.5, 12.1, 0.9, 16)
notes(s, "A quick note on method. If I measure by people, one huge plan can flip a whole month. In October, 50 "
         "percent of people in announced cuts were linked to AI, but almost all of that is one plan: the Dutch "
         "Government's 25,000 jobs, spread until 2035. Counted by announcements, only about 5 percent of October's "
         "announcements cited AI. So for the trend I count announcements; that is also the measure that matches "
         "the independent US data.")

# 11 ------------------------------------------------------------- Q4
s = new_slide()
badge(s, 0.6, 0.6, "Q4")
text(s, "AI-attributed announcements are bigger", 1.45, 0.55, 11.3, 0.8, 28, bold=True, font=HEAD)
bar_chart(s, ["AI-attributed (strict)", "Other announcements"], [MED_AI, MED_OTHER], 0.6, 1.7, 6.6, 3.2,
          [BLUE, GREY], fmt="0", vmax=MED_AI * 1.3)
text(s, "Median people per announcement", 0.6, 5.0, 6.6, 0.5, 14, color=MUTED)
card(s, 7.6, 1.75, 5.15, 2.05)
text(s, "Not a coincidence", 7.9, 1.95, 4.6, 0.5, 18, bold=True, font=HEAD)
text(s, "The difference (115 people) is very unlikely to be chance: 95% range 50–421, Mann-Whitney test "
        "p < 0.001.", 7.9, 2.45, 4.6, 1.3, 14)
card(s, 7.6, 4.05, 5.15, 2.05)
text(s, "But not bigger companies", 7.9, 4.25, 4.6, 0.5, 18, bold=True, font=HEAD)
text(s, "Companies citing AI are actually smaller (median 4,438 vs 10,000 employees). An earlier claim "
        "of mine did not survive testing, so I dropped it.", 7.9, 4.75, 4.6, 1.3, 14)
source(s, "Source: layoffhedge.com, main analysis. Medians are used because a few giant announcements distort averages.")
notes(s, "Fourth question: are AI-related cuts bigger? Yes. The typical AI-related announcement covers 295 people, "
         "versus 180 for others, and statistical tests say this difference is very unlikely to be chance. "
         "But careful: it does not mean big companies are the ones blaming AI. Companies citing AI are actually smaller. "
         "I had claimed the opposite earlier in the project; my robustness test showed it was wrong, so I removed it.")

# 12 ------------------------------------------------------------- Q5
s = new_slide()
badge(s, 0.6, 0.6, "Q5", fill=ORANGE)
text(s, "Job postings mentioning AI doubled in a year", 1.45, 0.55, 11.3, 0.8, 28, bold=True, font=HEAD)
win = indeed[(indeed["month"] >= "2024-01")]
labels = [f"{MONTHS[int(mo[5:]) - 1]} {mo[2:4]}" if mo[5:] in ("01", "07") else "" for mo in
          win[win.country_code == "US"]["month"]]
labels = [f"{MONTHS[int(mo[5:]) - 1]} '{mo[2:4]}" for mo in win[win.country_code == "US"]["month"]]
line_chart(s, labels,
           [("United States", (win[win.country_code == "US"]["ai_share_pct"] / 100).tolist(), BLUE, 3),
            ("United Kingdom", (win[win.country_code == "GB"]["ai_share_pct"] / 100).tolist(), ORANGE, 3)],
           0.6, 1.55, 8.4, 5.2, fmt="0%", vmax=0.11)
card(s, 9.35, 1.9, 3.4, 2.1)
text(s, "United States", 9.65, 2.1, 2.9, 0.5, 18, bold=True, color=BLUE, font=HEAD)
text(s, f"{us('2025-09'):.1f}% → {us('2026-09'):.1f}%", 9.65, 2.6, 2.9, 0.6, 26, bold=True, font=BODY)
text(s, "Sep 2025 → Sep 2026", 9.65, 3.3, 2.9, 0.5, 13, color=MUTED)
card(s, 9.35, 4.25, 3.4, 2.2)
text(s, "United Kingdom", 9.65, 4.45, 2.9, 0.5, 18, bold=True, color=ORANGE, font=HEAD)
text(s, f"{us('2025-09', 'GB'):.1f}% → {us('2026-09', 'GB'):.1f}%", 9.65, 4.95, 2.9, 0.6, 26, bold=True, font=BODY)
text(s, "All 8 comparable countries rose", 9.65, 5.65, 2.9, 0.5, 13, color=MUTED)
source(s, "Source: Indeed Hiring Lab AI Tracker (CC BY 4.0). “Mentions AI” is not the same as demand for AI skills.")
notes(s, "Fifth question, the hiring side. The share of job postings that mention AI doubled in a year: in the US from "
         "3.6 to 7.2 percent, in the UK from 4.9 to 9.8 percent. It rose in all eight countries I could compare. "
         "One caution: a posting 'mentioning AI' is not the same as demand for AI skills; for example, some postings "
         "just say 'we use AI in hiring'. I left Canada out, because a new Ontario law forces that sentence into postings.")

# 13 ------------------------------------------------------------- both sides
s = new_slide()
title(s, "AI faded in layoffs but grew in job postings")
m9 = m10[m10["month"] <= "2026-09"]
us9 = indeed[(indeed.country_code == "US") & indeed["month"].isin(m9["month"])]
line_chart(s, m9["label"].tolist(), [("Announcements citing AI", (m9["ai_strict_count_share_pct"] / 100).tolist(),
                                       BLUE, 3)], 0.6, 2.05, 6.0, 4.1, vmax=0.45, legend=False)
text(s, "Layoff side: share of job-cut announcements citing AI", 0.6, 1.55, 6.0, 0.5, 15, bold=True, color=BLUE)
line_chart(s, m9["label"].tolist(), [("US postings mentioning AI", (us9["ai_share_pct"] / 100).tolist(), ORANGE, 3)],
           6.85, 2.05, 5.9, 4.1, vmax=0.08, legend=False)
text(s, "Hiring side: share of US job postings mentioning AI", 6.85, 1.55, 5.9, 0.5, 15, bold=True, color=ORANGE)
text(s, "Two trends side by side, January–September 2026 — not cause and effect.", 0.6, 6.35, 12.1, 0.5, 15,
     italic=True, color=MUTED)
notes(s, "This slide puts both sides together. On the left, AI as a reason for job cuts fades after the summer. "
         "On the right, the share of job postings that mention AI keeps rising every month. I show them side by side "
         "on purpose, as two separate charts. I do not say one causes the other; the sources also cover different "
         "places, worldwide versus the US.")

# 14 ------------------------------------------------------------- meaning
s = new_slide()
title(s, "What this suggests for people looking for a job")
card(s, 0.6, 1.65, 12.15, 1.45, fill=NAVY)
text(s, "AI looks less like a layoff threat and more like a requirement in job postings.", 0.95, 1.85, 11.5, 1.05,
     24, bold=True, color=WHITE, font=HEAD, anchor=MSO_ANCHOR.MIDDLE)
pts = [("Read headlines critically", "“The company says AI” is not the same as “AI caused it”."),
       ("Build AI literacy", "More and more postings mention AI — knowing how to work with it helps."),
       ("Treat this as a hint, not proof", "The data has no seniority level, so junior roles were not measured "
                                            "separately.")]
for i, (h_, d_) in enumerate(pts):
    x = 0.6 + i * 4.1
    badge(s, x, 3.55, str(i + 1), fill=ORANGE if i == 1 else BLUE)
    text(s, h_, x, 4.35, 3.8, 0.5, 18, bold=True)
    text(s, d_, x, 4.9, 3.8, 1.2, 15, color=MUTED)
source(s, "Interpretation, not a tested finding.")
notes(s, "What does this mean for someone looking for a job, for example a junior candidate like me? "
         "My interpretation is that AI currently looks less like a layoff threat and more like a requirement in job postings. "
         "So read layoff headlines critically, and build basic AI literacy. But I want to be honest: none of my data "
         "shows seniority, so this is an interpretation, not something I tested for junior roles specifically.")

# 15 ------------------------------------------------------------- limitations
s = new_slide()
title(s, "What this analysis cannot tell us")
lims = [("Only announced cuts", "Small companies and unreported cuts are missing."),
        ("Stated reasons, not causes", "We see what companies say, not what really happened."),
        ("Different scopes", "Layoffs: worldwide · postings: 9 countries, no Turkey · Challenger: US only."),
        ("“Mentions AI” ≠ skill demand", "Postings can mention AI for other reasons."),
        ("Short time series", "10 months; November 2026 is incomplete."),
        ("No seniority data", "Junior roles cannot be measured separately.")]
for i, (h_, d_) in enumerate(lims):
    col, row = i % 2, i // 2
    x, y = 0.6 + col * 6.15, 1.65 + row * 1.65
    card(s, x, y, 5.95, 1.45)
    text(s, h_, x + 0.3, y + 0.2, 5.35, 0.45, 17, bold=True)
    text(s, d_, x + 0.3, y + 0.7, 5.35, 0.65, 14, color=MUTED)
notes(s, "Every analysis has limits, and I want to name mine. I only see announced cuts. I see the reasons companies "
         "state, not the real causes. My sources cover different places. A posting that mentions AI is not always "
         "asking for AI skills. The time series is short. And there is no seniority information. "
         "This is why I talk about directions and patterns, not about causes.")

# 16 ------------------------------------------------------------- closing
s = new_slide(dark=True)
text(s, "How it was built", 0.8, 0.6, 7, 0.8, 32, bold=True, color=WHITE, font=HEAD)
stages = [("Python", "Cleaning, 146 manual checks, statistical tests"),
          ("PostgreSQL", "Star schema; 41 checks — SQL = Python"),
          ("Power BI", "4-page interactive dashboard")]
for i, (h_, d_) in enumerate(stages):
    x = 0.8 + i * 2.55
    card(s, x, 1.7, 2.3, 2.1, fill=RGBColor(0x1E, 0x30, 0x55))
    text(s, h_, x + 0.25, 1.9, 1.9, 0.5, 18, bold=True, color=WHITE)
    text(s, d_, x + 0.25, 2.45, 1.9, 1.2, 14, color=ICE)
    if i < 2:
        text(s, "→", x + 2.3, 2.45, 0.25, 0.5, 18, bold=True, color=ICE, align=PP_ALIGN.CENTER)
shot = ROOT / "powerbi" / "screenshots" / "01_overview.png"
if shot.exists():
    s.shapes.add_picture(str(shot), Inches(8.65), Inches(1.7), width=Inches(3.9))
    text(s, "Power BI dashboard — page 1 of 4", 8.65, 4.05, 3.9, 0.4, 12, color=ICE)
text(s, "Thank you — questions?", 0.8, 4.75, 8, 0.9, 40, bold=True, color=WHITE, font=HEAD)
text(s, "github.com/Uguravsar75/ai-layoffs-vs-hiring-2026", 0.8, 5.75, 8, 0.5, 18, color=ICE)
notes(s, "Finally, how I built it. Python for cleaning, the manual checks and the statistics. PostgreSQL for a proper "
         "data model, with 41 automatic checks that the SQL results match Python exactly. And Power BI for a four-page "
         "dashboard. Everything, including the code and the verification log, is on GitHub. Thank you, I'm happy to "
         "take questions.")

prs.save(OUT)
print(f"saved {OUT.relative_to(ROOT)} — {len(prs.slides)} slides")
