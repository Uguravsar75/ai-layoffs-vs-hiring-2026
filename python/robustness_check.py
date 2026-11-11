"""
Robustness check: do the main findings hold at different reliability levels?
- All main-analysis rows (T1-T5)
- Verified core (T1-T3: manually verified, partially verified, strong source)
- Manually checked only (T1-T2)
The AI share is always reported with two definitions: strict (HEADLINE) and broad (upper bound).
The time trend is reported with two measures: people-based share and announcement-count share.
Output: robustness_check.csv (next to the input file)
"""
import sys
from pathlib import Path

import pandas as pd

INPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else \
    Path(__file__).resolve().parent.parent / "data" / "clean" / "layoffs_clean.csv"
df = pd.read_csv(INPUT)
main_set = df[df["in_main_analysis"]]
levels = {
    "1_all_rows": main_set,
    "2_core_T1_T3": main_set[main_set["in_core_verified"]],
    "3_manual_only_T1_T2": main_set[main_set["reliability_tier"].isin(["T1_manual_verified", "T2_manual_partial"])],
}


def monthly_share(d, flag, by_count=False):
    """AI share (%) per month. by_count=True -> share of announcements, else share of people."""
    d = d[d["month"].notna()]
    if by_count:
        return d.groupby("month")[flag].mean() * 100
    return d.groupby("month").apply(
        lambda g: g.loc[g[flag], "people_cut"].sum() / g["people_cut"].sum() * 100, include_groups=False)


def period_mean(series, start, end):
    return round(series.loc[start:end].mean(), 1)


def findings(d):
    ai, strict = d[d["is_ai_driven"]], d[d["is_ai_strict"]]
    industry = d.groupby("industry")["people_cut"].sum().sort_values(ascending=False)
    people_strict, people_broad = monthly_share(d, "is_ai_strict"), monthly_share(d, "is_ai_driven")
    count_strict = monthly_share(d, "is_ai_strict", by_count=True)
    return {
        "rows": len(d),
        "people": int(d["people_cut"].sum()),
        "people_share_of_all_%": None,
        "industry_1": industry.index[0], "industry_2": industry.index[1], "industry_3": industry.index[2],
        "ai_people_share_strict_%": round(strict["people_cut"].sum() / d["people_cut"].sum() * 100, 1),
        "ai_people_share_broad_%": round(ai["people_cut"].sum() / d["people_cut"].sum() * 100, 1),
        "ai_count_share_strict_%": round(len(strict) / len(d) * 100, 1),
        "ai_count_share_broad_%": round(len(ai) / len(d) * 100, 1),
        "ai_strict_median_people": float(strict["people_cut"].median()),
        "ai_broad_median_people": float(ai["people_cut"].median()),
        "non_ai_median_people": float(d.loc[~d["is_ai_driven"], "people_cut"].median()),
        "ai_median_company_size": float(ai["total_workforce"].median()),
        "non_ai_median_company_size": float(d.loc[~d["is_ai_driven"], "total_workforce"].median()),
        "people_share_strict_jan_apr_mean_%": period_mean(people_strict, "2026-01", "2026-04"),
        "people_share_strict_jun_sep_mean_%": period_mean(people_strict, "2026-06", "2026-09"),
        "people_share_broad_jan_apr_mean_%": period_mean(people_broad, "2026-01", "2026-04"),
        "people_share_broad_jun_sep_mean_%": period_mean(people_broad, "2026-06", "2026-09"),
        "count_share_strict_jan_apr_mean_%": period_mean(count_strict, "2026-01", "2026-04"),
        "count_share_strict_jun_sep_mean_%": period_mean(count_strict, "2026-06", "2026-09"),
    }


result = pd.DataFrame({name: findings(d) for name, d in levels.items()})
total = result.loc["people", "1_all_rows"]
result.loc["people_share_of_all_%"] = [round(k / total * 100, 1) for k in result.loc["people"]]
result.to_csv(INPUT.parent / "robustness_check.csv")
pd.set_option("display.width", 200)
print(result)
