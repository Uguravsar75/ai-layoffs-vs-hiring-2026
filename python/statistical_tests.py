"""
Statistical tests (no machine learning; descriptive statistics + resampling).

Goal: check whether the findings could be due to chance or to the chosen time window.

1) Median difference (strict AI vs non-AI): bootstrap 95% CI + Mann-Whitney U test
2) Headline AI share (16.9%): bootstrap 95% CI (how much does it depend on a few giant rows?)
3) Split-month sensitivity: does "high first, low later" hold when the split month is moved
   between May and September? (answers the criticism that August was chosen after the fact)
4) Challenger correlation: permutation test (10 months; how likely by chance?)
5) Missed-AI-label sensitivity: non-AI rows were checked less often than AI rows;
   how much would the headline change if AI labels were missed there?

Output: data/clean/statistical_tests.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

DATA = Path(__file__).resolve().parent.parent / "data" / "clean"
RNG = np.random.default_rng(2026)   # fixed seed -> identical results on every run
B = 10_000                          # bootstrap / permutation repetitions

df = pd.read_csv(DATA / "layoffs_clean.csv")
main_set = df[df["in_main_analysis"]].copy()
results = []


def record(test, value, low=None, high=None, p=None, comment=""):
    results.append({"test": test, "value": value, "ci95_low": low, "ci95_high": high,
                    "p_value": p, "comment": comment})


# ---------------------------------------------------------------------------
# 1) Median difference
# ---------------------------------------------------------------------------
ai = main_set.loc[main_set["is_ai_strict"], "people_cut"].to_numpy()
other = main_set.loc[~main_set["is_ai_driven"], "people_cut"].to_numpy()
diff = np.median(ai) - np.median(other)
boot = np.array([np.median(RNG.choice(ai, ai.size)) - np.median(RNG.choice(other, other.size))
                 for _ in range(B)])
low, high = np.percentile(boot, [2.5, 97.5])
mw = stats.mannwhitneyu(ai, other, alternative="greater")
record("1a_median_diff_ai_strict_minus_non_ai", diff, low, high, None,
       f"AI strict median {np.median(ai):.0f} (n={ai.size}) vs non-AI {np.median(other):.0f} (n={other.size}); "
       f"CI {'excludes' if low > 0 else 'INCLUDES'} zero")
record("1b_mann_whitney_ai_greater", mw.statistic, None, None, mw.pvalue,
       "One-sided: do AI announcements cover more people? (rank-based, no normality assumption)")

# ---------------------------------------------------------------------------
# 2) Confidence interval of the headline AI share (resample rows)
# ---------------------------------------------------------------------------
people = main_set["people_cut"].to_numpy()
strict = main_set["is_ai_strict"].to_numpy()
broad = main_set["is_ai_driven"].to_numpy()
idx = RNG.integers(0, len(main_set), size=(B, len(main_set)))
share_strict = (people[idx] * strict[idx]).sum(1) / people[idx].sum(1) * 100
share_broad = (people[idx] * broad[idx]).sum(1) / people[idx].sum(1) * 100
record("2a_ai_people_share_strict_%", people[strict].sum() / people.sum() * 100,
       *np.percentile(share_strict, [2.5, 97.5]), None, "Wide CI = result depends on a few giant rows")
record("2b_ai_people_share_broad_%", people[broad].sum() / people.sum() * 100,
       *np.percentile(share_broad, [2.5, 97.5]), None, "Upper bound")
share_count = strict[idx].mean(1) * 100
record("2c_ai_count_share_strict_%", strict.mean() * 100, *np.percentile(share_count, [2.5, 97.5]), None,
       "Count share is not driven by giant rows -> narrow CI")

# ---------------------------------------------------------------------------
# 3) Split-month sensitivity (Jan..Oct; November is a partial month and excluded)
# ---------------------------------------------------------------------------
monthly = pd.read_csv(DATA / "layoffs_clean_monthly.csv")
monthly = monthly[monthly["month"] <= "2026-10"].set_index("month")
ch = pd.read_csv(DATA / "challenger_ai_monthly.csv").set_index("month")
for split in ["2026-05", "2026-06", "2026-07", "2026-08", "2026-09"]:
    before, after = monthly.index < split, monthly.index >= split
    lh_b, lh_a = monthly.loc[before, "ai_strict_count_share_pct"].mean(), monthly.loc[after, "ai_strict_count_share_pct"].mean()
    ch_b, ch_a = ch.loc[ch.index < split, "ai_share_pct"].mean(), ch.loc[ch.index >= split, "ai_share_pct"].mean()
    record(f"3_split_{split}_layoffhedge_count_share", lh_b - lh_a, lh_b, lh_a, None,
           f"before {lh_b:.1f} -> after {lh_a:.1f} (value = difference; low/high = before/after mean) | "
           f"Challenger before {ch_b:.1f} -> after {ch_a:.1f}")

# ---------------------------------------------------------------------------
# 4) Challenger correlation: permutation test
# ---------------------------------------------------------------------------
comp = pd.read_csv(DATA / "challenger_vs_layoffhedge.csv")
x, y = comp["challenger_ai_share_pct"].to_numpy(), comp["lh_ai_strict_count_pct"].to_numpy()
r = np.corrcoef(x, y)[0, 1]
perm = np.array([np.corrcoef(x, RNG.permutation(y))[0, 1] for _ in range(B)])
record("4a_corr_challenger_vs_count_share", r, None, None, (np.sum(perm >= r) + 1) / (B + 1),
       f"n={len(x)} months; one-sided permutation p. Monthly series are autocorrelated, "
       "so p may be optimistic -> read as confirmation of direction")
x2 = comp["lh_ai_strict_people_pct"].to_numpy()
r2 = np.corrcoef(x, x2)[0, 1]
perm2 = np.array([np.corrcoef(x, RNG.permutation(x2))[0, 1] for _ in range(B)])
record("4b_corr_challenger_vs_people_share", r2, None, None, (np.sum(perm2 >= r2) + 1) / (B + 1),
       "People share does not track Challenger")

# ---------------------------------------------------------------------------
# 5) Missed-AI-label sensitivity
# ---------------------------------------------------------------------------
P = people.sum()
strict_people = people[strict].sum()
non_ai = main_set[~main_set["is_ai_driven"]]
checked = non_ai[non_ai["verification"] != "not_checked"]
unchecked = non_ai[non_ai["verification"] == "not_checked"]
missing = non_ai[non_ai["ai_label_missing"]]
rate = len(missing) / len(checked)          # missed-label rate among manually checked non-AI rows
# Scenario A: count the missed labels that were found (Envato, United Internet) as AI
share_a = (strict_people + missing["people_cut"].sum()) / P * 100
# Scenario B: apply the same rate to the unchecked rows, using their median size
share_b = (strict_people + missing["people_cut"].sum() + rate * len(unchecked) * unchecked["people_cut"].median()) / P * 100
# Scenario C (pessimistic): same rate, using their MEAN size
share_c = (strict_people + missing["people_cut"].sum() + rate * unchecked["people_cut"].sum()) / P * 100
record("5a_missed_label_rate_among_checked_%", rate * 100, None, None, None,
       f"{len(missing)} / {len(checked)} manually checked non-AI rows")
record("5b_ai_share_strict_scenario_A_found_labels_%", share_a, None, None, None, "Envato + United Internet")
record("5c_ai_share_strict_scenario_B_rate_x_median_%", share_b, None, None, None,
       f"~{rate * len(unchecked):.0f} rows x median {unchecked['people_cut'].median():.0f} people")
record("5d_ai_share_strict_scenario_C_rate_x_mean_%", share_c, None, None, None, "Pessimistic upper estimate")

out = pd.DataFrame(results)
for col in ["value", "ci95_low", "ci95_high"]:
    out[col] = out[col].astype(float).round(2)
out["p_value"] = out["p_value"].astype(float).round(4)
out.to_csv(DATA / "statistical_tests.csv", index=False)
pd.set_option("display.width", 250)
pd.set_option("display.max_colwidth", 130)
print(out.to_string(index=False))
