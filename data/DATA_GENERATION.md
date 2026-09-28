# How the Investly data was generated

The data is **synthetic**. `generate_data.py` (seed 42) creates it. It is not real user data.

The rules below were built into the generator. Any analysis "finding" that matches
a rule is the method working correctly, not a real-world discovery.
This file exists so the project is honest about that.

## Scope
- 10,000 users who **completed signup** between 1 Jan and 30 Jun 2026. Installs without signup are not in the data, so funnels start at signup.
- Events up to 31 Aug 2026, so every cohort has at least 60 days of history.
- Signups grow slightly month on month.

## Distributions
- Age: 18-24 25%, 25-34 40%, 35-44 20%, 45+ 15%
- City: Tier 1 45%, Tier 2 35%, Tier 3 20%
- Channel: Organic 25%, Google 20%, Instagram 20%, Paid Ads 13%, Referral 12%, YouTube 10%
- Platform: Android 78%, iOS 22%
- Risk profile depends on age (younger users are more aggressive)

## Behaviour rules
- **Onboarding:** 45+ users start and finish KYC less often. Tier 2/3 users finish KYC less often, and Tier 3 users link bank accounts less often. KYC completion can take several days, so some users activate after day 7.
- **Discovery:** Referral and Organic users reach MF discovery more often after bank linking. Instagram users reach it less often.
- **Conversion:** Using the SIP calculator raises investment-start probability. Referral and Organic users convert more; Instagram and YouTube users convert less. The Index category gets many views but converts at about 62% of the Equity rate. Tier 3 and Android users fail more often at checkout.
- **SIP:** About 45% of first investments are SIPs (more for 25-34). SIPs create monthly auto-debit rows (`source = 'sip_auto_debit'`) with no app event, and each month has a 12% chance of stopping.
- **Retention:** The number of return sessions rises with how far the user got (signup → investor). Watchlist users return more.
- **Repeat:** Manual repeat investment is more likely for Referral, Aggressive, and frequent portfolio viewers.
- **Campaigns:** One row per paid channel per month. Spend ≈ signups × cost per signup (Google ₹180, Instagram ₹120, YouTube ₹220, Paid Ads ₹150, Referral bonus ₹100) ± 15%. Organic has no spend.

## Dirty data injected on purpose (for 01_data_quality.sql)
- 600 fully duplicated event rows
- 25 events from user IDs that don't exist in `users`
- 30 `app_open` events moved 200 days before signup
- 6 investments with zero or negative amounts
- 4 duplicated investment rows (same `investment_id`)
- 8 users with NULL `age_group`
- `product_type` / `fund_category` are NULL on events where they don't apply (for example `kyc_started`). This is expected and is not an error.
