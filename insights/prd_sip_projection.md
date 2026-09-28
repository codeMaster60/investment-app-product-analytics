# PRD: SIP Projection on the Fund Page

| | |
|---|---|
| **Product** | Investly (fictional investment app) |
| **Author** | Allumolu Sai Jayanth |
| **Status** | Draft, ready for A/B test |
| **Related analysis** | `sql/03_investment_funnel.sql`, `sql/06_product_usage.sql`, `insights/product_recommendations.md` |

> Based on analysis of a synthetic dataset. Numbers show behavioural patterns, not proven causes.

---

## 1. Problem

Viewing a fund to starting an investment is the weakest step in the entire Investly journey: only **35.5%** of fund viewers start an investment. 2,378 users looked at a fund and left.

Among fund viewers, users who opened the SIP calculator invested at **41.5%** vs **18.3%** for those who didn't. But the calculator sits behind a separate button, and only **~27%** of fund viewers ever use it.

This gap is an association. Calculator users may already be more motivated. **This feature is designed to be tested, not assumed to work.**

## 2. Goal

Help users understand what investing in a fund could mean for them, at the moment they are deciding.

**Primary metric:** Fund view → investment started (within 7 days of first exposure). Baseline: 35.5%.

**Secondary metrics:** Investment completed; SIP share of new investments; first investment amount; 30-day retention.

**Guardrails:** Investments cancelled or redeemed within 30 days; fund page load time; support tickets about projections or returns.

## 3. Non-goals
- Changing the checkout or payment flow (separate initiative).
- Personalised fund recommendations or advice.
- Changing the standalone SIP calculator.
- Lumpsum projections (possible later phase).

## 4. Target users
Users who have completed onboarding (KYC + bank linked) and open a mutual fund detail page. First-time investors are the priority, since they are the most unsure about what to expect.

## 5. User stories
1. As a **first-time investor**, I want to see what a monthly SIP in this fund could grow to, so I can judge whether it fits my goals.
2. As a **user comparing funds**, I want to adjust the monthly amount and duration, so I can see a number that matches my budget.
3. As a **cautious user**, I want to understand that the projection is not guaranteed, so I don't feel misled.
4. As a **user who has decided**, I want to start a SIP with my chosen amount already filled in, so I don't have to re-enter it.

## 6. Requirements and acceptance criteria

| # | Requirement | Acceptance criteria |
|---|---|---|
| R1 | Show a SIP projection module on every MF detail page, above the fold on mobile | Module is visible without scrolling on a 6" screen; appears for 100% of treatment users |
| R2 | Default to ₹1,000/month for 5 years | Values load pre-filled; projection displays within 300 ms |
| R3 | Let users change amount (₹100–₹1,00,000) and duration (1–30 years) | Slider and input both work; invalid values show an inline error; projection updates instantly |
| R4 | Show total invested, estimated value, and estimated gain | All three values shown; figures rounded to the nearest ₹100 |
| R5 | Use a clearly stated, conservative assumed return rate | Rate and basis shown next to the result (e.g. "Assumes X% yearly return"); never labelled "expected" or "guaranteed" |
| R6 | Show the required risk disclaimer | "Mutual fund investments are subject to market risks. Projections are illustrative and not guaranteed. Past performance is not indicative of future returns." is visible without tapping |
| R7 | "Start SIP" button carries the chosen amount into checkout | Checkout opens with the same amount pre-filled; user can still edit it |
| R8 | Log analytics events (section 8) | All events fire in QA with correct properties |

## 7. Edge cases
- **Fund with under 1 year of history:** show the projection using the category's assumed rate and label it clearly.
- **Fund below the minimum SIP amount:** show the fund's minimum as the default and block lower values with a clear message.
- **Fund closed to new SIPs:** hide the module; show "SIP not available for this fund".
- **Slow network:** show a loading state; if the projection fails to load, the rest of the fund page must still work.
- **User changes amount in checkout:** the checkout amount wins; no conflict with the projection.

## 8. Analytics tracking

| Event | When | Properties |
|---|---|---|
| `sip_projection_viewed` | Module becomes visible | fund_id, fund_category, experiment_group |
| `sip_projection_changed` | User edits amount or duration | fund_id, amount, years |
| `sip_projection_cta_clicked` | User taps "Start SIP" | fund_id, amount, years |

Existing events (`mf_detail_view`, `investment_started`, `investment_completed`) must also carry `experiment_group` so the funnel can be split by variant.

## 9. Compliance notes
Mutual fund marketing in India is regulated. Before launch, compliance must review: the assumed return rate and how it is chosen, disclaimer wording and placement, and that no language implies guaranteed returns. **Compliance sign-off is a launch blocker.**

## 10. Rollout plan
1. **QA + compliance review.**
2. **A/B test:** 50/50 split at user level; design and sample size in `insights/product_recommendations.md`.
3. **Decision:**
   - Primary metric up significantly and no guardrail worse → roll out to 100%.
   - Primary up but cancellations or complaints rise → do not ship; investigate.
   - No significant change → remove the module; the calculator gap was likely self-selection.

## 11. Risks
| Risk | Mitigation |
|---|---|
| Users treat projections as promises | Conservative rate, clear disclaimer, compliance review |
| Pushes users into investments they later regret | 30-day cancellation/redemption guardrail |
| Slower fund page | Load module after page content; track load time as a guardrail |
| Effect is only self-selection | That is exactly what the A/B test checks |

## 12. Open questions
- Which return rate should each fund category use, and who owns keeping it updated?
- Should the default amount be personalised (e.g. based on risk profile) in a later phase?
- Should the module also appear on the fund comparison screen?
