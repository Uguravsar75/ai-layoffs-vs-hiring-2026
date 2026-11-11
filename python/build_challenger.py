"""
Step 3 - Challenger, Gray & Christmas monthly table (US, Jan-Oct 2026)
Source: Challenger monthly job-cut reports (challengergray.com) and news coverage of those reports.
Figures collected on 2026-11-11.

Challenger figures are ANNOUNCED job-cut plans by US-based employers, and the AI figure is the
reason the employer STATES; it is not a verified cause.

Check: the monthly figures must add up exactly to the year-to-date (YTD) totals that Challenger
publishes in its own reports. If they do not, the script stops with an error.

Outputs:
- data/clean/challenger_ai_monthly.csv     : 10 rows, each with its source
- data/clean/challenger_vs_layoffhedge.csv : side by side with the layoffhedge AI shares
"""
from pathlib import Path

import pandas as pd

DATA = Path(__file__).resolve().parent.parent / "data" / "clean"

# month: (total US job cuts, AI-attributed cuts, source, note)
CHALLENGER = {
    "2026-01": (108435, 7624,
                "https://www.challengergray.com/blog/challenger-report-february-cuts-plunge-hiring-falls-56-percent/",
                "Total from the February report; AI = February YTD 12,304 - February 4,680 (derived)"),
    "2026-02": (48307, 4680,
                "https://www.challengergray.com/blog/challenger-report-february-cuts-plunge-hiring-falls-56-percent/",
                "AI YTD 12,304 (8%)"),
    "2026-03": (60620, 15341,
                "https://searchenginejournal.com/ai-leads-all-reasons-for-u-s-job-cuts-in-march-report-says/571065",
                "AI ranked first for the first time; secondary source, confirmed by the YTD chain"),
    "2026-04": (83387, 21490,
                "https://www.cbsnews.com/news/ai-layoffs-job-cuts-challenger-report-april-2026/",
                "Total YTD 300,749"),
    "2026-05": (97006, 38579,
                "https://foxbusiness.com/economy/ai-remains-top-reason-us-job-cuts-third-straight-month-employers-axed-97000-workers-may",
                "Record month for AI; AI YTD 87,714 (22%)"),
    "2026-06": (45849, 14029,
                "https://www.challengergray.com/?p=28455",
                "AI YTD 101,743 (23%)"),
    "2026-07": (33429, 10970,
                "https://www.challengergray.com/?p=28706",
                "AI ranked first for the 5th month in a row; AI YTD 112,713, total YTD 477,033"),
    "2026-08": (52881, 3462,
                "https://www.challengergray.com/?p=28858",
                "AI fell to 4th (restructuring 1st with 16,173); AI YTD 116,175"),
    "2026-09": (43281, 3961,
                "https://www.cpapracticeadvisor.com/2026/10/01/u-s-companies-announce-fewest-job-cuts-for-a-september-since-2022/190969",
                "AI ranked 5th; AI YTD 120,136, total YTD 573,195. A '7,000' figure in one article does not fit the YTD chain and was not used"),
    "2026-10": (43994, 1265,
                "https://tradingeconomics.com/united-states/challenger-job-cuts/news/598602",
                "Lowest AI month of the year; AI YTD 121,401, total YTD 617,189 (-44% year over year)"),
}

# YTD totals as published in Challenger's reports (used as checkpoints)
YTD_AI = {"2026-02": 12304, "2026-05": 87714, "2026-06": 101743, "2026-07": 112713,
          "2026-08": 116175, "2026-09": 120136, "2026-10": 121401}
YTD_TOTAL = {"2026-04": 300749, "2026-07": 477033, "2026-09": 573195, "2026-10": 617189}


def main():
    ch = pd.DataFrame([{"month": month, "total_us_cuts": t, "ai_attributed_cuts": a,
                        "source_url": url, "note": note}
                       for month, (t, a, url, note) in CHALLENGER.items()])
    ch["ai_share_pct"] = (ch["ai_attributed_cuts"] / ch["total_us_cuts"] * 100).round(1)
    ch["ai_ytd_cuts"] = ch["ai_attributed_cuts"].cumsum()
    ch["total_ytd_cuts"] = ch["total_us_cuts"].cumsum()

    # Consistency check: cumulative sum of the monthly figures = published YTD totals
    for month, expected in YTD_AI.items():
        found = ch.loc[ch["month"] == month, "ai_ytd_cuts"].item()
        assert found == expected, f"AI YTD mismatch {month}: {found} != {expected}"
    for month, expected in YTD_TOTAL.items():
        found = ch.loc[ch["month"] == month, "total_ytd_cuts"].item()
        assert found == expected, f"Total YTD mismatch {month}: {found} != {expected}"
    print(f"YTD check: {len(YTD_AI)} AI + {len(YTD_TOTAL)} total checkpoints passed")

    columns = ["month", "total_us_cuts", "ai_attributed_cuts", "ai_share_pct",
               "ai_ytd_cuts", "total_ytd_cuts", "source_url", "note"]
    ch[columns].to_csv(DATA / "challenger_ai_monthly.csv", index=False)

    # Comparison with layoffhedge (same months)
    lh = pd.read_csv(DATA / "layoffs_clean_monthly.csv")[
        ["month", "ai_strict_share_pct", "ai_share_pct_upper", "ai_strict_count_share_pct"]]
    comp = ch[["month", "ai_share_pct"]].rename(columns={"ai_share_pct": "challenger_ai_share_pct"}) \
        .merge(lh.rename(columns={"ai_strict_share_pct": "lh_ai_strict_people_pct",
                                  "ai_share_pct_upper": "lh_ai_upper_people_pct",
                                  "ai_strict_count_share_pct": "lh_ai_strict_count_pct"}), on="month")
    comp.to_csv(DATA / "challenger_vs_layoffhedge.csv", index=False)

    pd.set_option("display.width", 200)
    print(ch[["month", "total_us_cuts", "ai_attributed_cuts", "ai_share_pct"]].to_string(index=False))
    print()
    print(comp.to_string(index=False))
    print()
    for col in ["lh_ai_strict_people_pct", "lh_ai_upper_people_pct", "lh_ai_strict_count_pct"]:
        print(f"Correlation with Challenger ({col}): Pearson {comp['challenger_ai_share_pct'].corr(comp[col]):.2f}"
              f" | Spearman {comp['challenger_ai_share_pct'].corr(comp[col], method='spearman'):.2f}")
    early, late = comp[comp.month <= "2026-07"], comp[comp.month >= "2026-08"]
    print("\nPeriod means (Jan-Jul | Aug-Oct):")
    for col in ["challenger_ai_share_pct", "lh_ai_strict_people_pct", "lh_ai_strict_count_pct"]:
        print(f"  {col}: {early[col].mean():.1f} | {late[col].mean():.1f}")


if __name__ == "__main__":
    main()
