# Investly — Product Recommendations

> Investly is a **fictional** investment app and all data is **synthetic** (see `data/DATA_GENERATION.md`).
> Findings describe behavioural patterns in this dataset. They are **associations, not proof of cause**.
> Impact estimates below are illustrative assumptions, not measured results.

---

## Headline numbers

| Metric | Value | Source |
|---|---|---|
| Users (signups, Jan–Jun 2026) | 10,000 | 08 |
| 7-day activation (KYC + bank + MF discovery within 7 days) | 35.3% | 02 |
| Signup → first MF investment | 9.0% (901 users) | 08 |
| Largest funnel drop: fund view → investment started | 35.5% conversion | 03 |
| Investment started → completed | 69.0% | 03 |
| Active ~1 month after signup (days 29–35) | ~20–22% | 05 |
| Manual repeat investors | 41.1% | 08 |
| Total invested (incl. SIP auto-debits) | ₹1.54 crore | 08 |

---

## Findings → Recommendations

Each recommendation follows: **Finding → Why it matters → Hypothesis → Recommendation → Success metric → Guardrail.**

### 1. Recover users who start an investment but don't finish
- **Finding:** 405 of 1,306 users (31%) started an MF investment but never completed it. (03)
- **Why it matters:** These users already decided to invest. This is the highest-intent drop-off in the app.
- **Hypothesis:** Losses are driven by checkout friction (payment failure, UPI/mandate setup, unclear errors), not by lack of interest.
- **Recommendation:** First instrument *why* checkouts fail (failure reason codes). Then test: payment retry with alternate method, clearer error messages, and a same-day "complete your investment" reminder.
- **Success metric:** Investment started → completed rate.
- **Guardrails:** Failed transaction rate, payment-related support tickets, notification opt-outs.

### 2. Bring decision support onto the fund page (A/B test below)
- **Finding:** Only 35.5% of fund viewers start an investment, the weakest step in the whole journey. (03) Among fund viewers, SIP-calculator users invested at 41.5% vs 18.3% for non-users (2.3×), but only ~27% of viewers use it. (06)
- **Why it matters:** 2,378 users looked at a fund and walked away.
- **Hypothesis:** Users can't easily picture what an investment means for them. Showing a personalised SIP projection directly on the fund page will help them decide.
- **Caveat:** Calculator users may simply be more motivated already (self-selection). The 2.3× gap is an association, so this must be tested, not assumed.
- **Recommendation:** Run the controlled experiment designed below.
- **Success metric:** Fund view → investment started.
- **Guardrails:** Investment cancellations/redemptions within 30 days, fund page load time.

### 3. Reduce KYC friction for Tier 3 and 45+ users
- **Finding:** Tier 3 users complete KYC at 58.7% vs 67.4% in Tier 1; users aged 45+ at 55.8% vs ~66% for other ages. Both groups also invest less, and their gap starts at KYC. (04) Across all users, KYC start → bank linked is the biggest onboarding friction zone (only 57% of KYC starters link a bank). (02)
- **Why it matters:** These users are lost before they ever see a product.
- **Hypothesis:** KYC is harder for less digitally-native users (documents, language, video verification).
- **Recommendation:** Research first (5–8 user interviews, KYC step-level drop-off data), then test vernacular KYC instructions and assisted/video-call KYC for these segments.
- **Success metric:** KYC start → complete rate for Tier 3 and 45+ users.
- **Guardrails:** KYC rejection rate, fraud flags, KYC support cost per user.

### 4. Nudge slow activators in week 1
- **Finding:** 38.7% of users eventually reach MF discovery, but only 35.3% activate within 7 days, so ~340 users are slow activators. (02) The biggest retention drop is week 1 (~76%) → week 2 (~48%). (05)
- **Hypothesis:** Users who stall mid-onboarding lose momentum after the first few days.
- **Recommendation:** Test a step-specific reminder sequence on days 2, 4 and 6 ("You're one step away: link your bank").
- **Success metric:** 7-day activation rate.
- **Guardrails:** Notification opt-out rate, app uninstalls.

### 5. Investigate the Index fund conversion gap
- **Finding:** Index funds are the 2nd most viewed category (2,254 viewers) but convert worst (9.7% vs Equity 14.8%). (07)
- **Why it matters:** At Equity's rate, ~115 more users would have invested.
- **Hypothesis (unproven):** Information clarity, perceived low returns, or choice overload between near-identical index funds.
- **Recommendation:** Qualitative research before building anything: session recordings on index fund pages and short user interviews. Possible later test: a simple "how index funds differ" comparison view.
- **Success metric:** Index fund view → invest rate.

### 6. Re-balance acquisition spend toward investor quality
- **Finding:** Referral costs ₹849 per investor vs YouTube ₹3,031 (3.6×). Instagram has the worst conversion (7.2%) but is still the 2nd cheapest per investor (₹1,643) because its signups are cheap. (04)
- **Why it matters:** Optimising for signups would reward the wrong channels.
- **Recommendation:** Track cost per investor, not cost per signup. Test increased referral incentives, and review YouTube spend.
- **Success metric:** Blended cost per investor.
- **Guardrails:** Total investor volume, 30-day retention of acquired users.
- **Caveats:** Referral may not scale linearly; this analysis counts investors, not investment value.

### 7. Measure SIP health with persistence, not repeat rate
- **Finding:** SIP starters show a 91.3% "repeat rate", but only 39.2% invest again manually. Almost all SIP repeat activity is automatic debits. (07)
- **Recommendation:** Report SIP persistence (share of SIPs still active after 3 and 6 months) as the SIP KPI. Track manual repeat investing separately.
- **Related:** Median gap between manual investments is 11 days (07). A second-investment nudge within ~2 weeks is a candidate test.

---

## Prioritisation (RICE)

Reach = users affected per month (estimated from ~600 fund viewers/month in this dataset). Impact: 3 = high, 2 = medium, 1 = low. Confidence reflects evidence strength. Effort in person-weeks. **All scores are rough judgement calls, not measured values.**

| # | Recommendation | Reach | Impact | Confidence | Effort | RICE |
|---|---|---|---|---|---|---|
| 4 | Week-1 activation nudges | 1,500 | 1 | 50% | 2 | **375** |
| 2 | SIP projection on fund page | 400 | 2 | 50% | 3 | **133** |
| 5 | Index fund research | 350 | 1 | 30% | 1 | **105** |
| 3 | Assisted / vernacular KYC | 600 | 2 | 50% | 6 | **100** |
| 1 | Checkout recovery | 70 | 3 | 80% | 2 | **84** |

RICE = Reach × Impact × Confidence ÷ Effort. Checkout recovery scores lowest on RICE because few users reach that step, but it is still a first-wave priority: it has the highest confidence, and the first step (logging failure reasons) is almost free.

**What I'd do first and why:**
1. **Week-1 nudges:** widest reach, cheapest to build, easy to measure.
2. **Checkout recovery:** smallest reach but highest intent and highest confidence; start by instrumenting failure reasons.
3. **SIP projection A/B test:** biggest potential on the weakest funnel step, but it needs a controlled test because the evidence is correlational.

---

## Experiment design: SIP projection on the fund page

**Hypothesis:** Showing a personalised SIP projection ("₹2,000/month could grow to about ₹X in 5 years") directly on the fund detail page will increase the share of fund viewers who start an investment.

| | |
|---|---|
| **Population** | Users who open a mutual fund detail page during the test |
| **Randomisation unit** | User (not session), so each user always sees the same version |
| **Split** | 50% control / 50% treatment |
| **Control** | Current fund page; calculator available via a separate button |
| **Treatment** | Inline SIP projection module on the fund page with a pre-filled "Start SIP" button |
| **Primary metric** | Fund view → investment started, within 7 days of first exposure |
| **Secondary metrics** | Investment completed, SIP share of new investments, first investment amount, 30-day retention |
| **Guardrails** | Investment cancellations/redemptions within 30 days, fund page load time, support tickets |

**Sample size (α = 0.05, power = 80%, baseline 35.5%):**

| Minimum detectable effect | Users per arm | Total |
|---|---|---|
| +3.0 percentage points (35.5% → 38.5%) | ~4,060 | ~8,120 |
| +5.0 percentage points (35.5% → 40.5%) | ~1,480 | ~2,950 |

**Duration:** At this synthetic app's scale (~600 fund viewers/month), detecting +5 points would take about 5 months, and +3 points over a year. That is too slow, so a small app would either accept a larger detectable effect or test on a higher-traffic step. At a large platform's traffic, the same test would finish in days. Always run for at least 1–2 full weeks to cover weekday/weekend behaviour.

**Decision rule:**
- Primary metric improves significantly **and** no guardrail worsens → roll out.
- Primary improves but cancellations rise → the module may be pushing users into investments they regret. Don't ship; investigate.
- No significant change → the calculator gap was likely self-selection. Drop the idea and move to the next priority.

**How we'd know the hypothesis was wrong:** No significant lift in fund view → investment started after the planned sample size is reached.

> No experiment was run in this project. The design above is a plan, and no results are claimed.

---

## Limitations
- Synthetic dataset: patterns reflect the generator's rules (documented in `data/DATA_GENERATION.md`). The project demonstrates the analysis method, not real-market discoveries.
- All behavioural comparisons are correlational.
- Channel costs are simulated; investor value (amount, lifetime) is not included in channel analysis.
- Week-1 retention includes onboarding events, which inflates it relative to later weeks.
