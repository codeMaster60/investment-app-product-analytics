"""
Investly synthetic data generator
---------------------------------
Generates users, events, investments and campaigns for a FICTIONAL Indian
investment app. All behavioural rules are documented in data/DATA_GENERATION.md.

Run:  python generate_data.py
Needs: pip install numpy pandas
"""
import numpy as np
import pandas as pd

rng = np.random.default_rng(42)          # fixed seed -> same data every run

N_USERS = 10_000
SIGNUP_START = pd.Timestamp("2026-01-01")
SIGNUP_END = pd.Timestamp("2026-06-30")
OBS_END = pd.Timestamp("2026-08-31 23:59:59")   # last date data exists

def pick(options, weights, n=None):
    w = np.array(weights, dtype=float)
    return rng.choice(options, size=n, p=w / w.sum())

def chance(p):
    return rng.random() < max(0.0, min(1.0, p))

# ---------------------------------------------------------------- USERS
days = (SIGNUP_END - SIGNUP_START).days + 1
day_w = np.linspace(1.0, 1.6, days)                  # app is growing month on month
signup_day = rng.choice(days, size=N_USERS, p=day_w / day_w.sum())
signup_ts = (SIGNUP_START + pd.to_timedelta(signup_day, "D")
             + pd.to_timedelta(rng.integers(7 * 60, 23 * 60, N_USERS), "m"))
order = np.argsort(signup_ts.values)
signup_ts = signup_ts[order]

age = pick(["18-24", "25-34", "35-44", "45+"], [25, 40, 20, 15], N_USERS)
tier = pick(["Tier 1", "Tier 2", "Tier 3"], [45, 35, 20], N_USERS)
channel = pick(["Organic", "Google", "Instagram", "Referral", "YouTube", "Paid Ads"],
               [25, 20, 20, 12, 10, 13], N_USERS)
platform = pick(["Android", "iOS"], [78, 22], N_USERS)
risk_by_age = {"18-24": [20, 40, 40], "25-34": [25, 47, 28],
               "35-44": [35, 47, 18], "45+": [50, 40, 10]}
risk = np.array([pick(["Conservative", "Moderate", "Aggressive"], risk_by_age[a]) for a in age])

users = pd.DataFrame({
    "user_id": [f"U{i:05d}" for i in range(1, N_USERS + 1)],
    "signup_date": signup_ts.date,
    "age_group": age, "city_tier": tier, "acquisition_channel": channel,
    "platform": platform, "risk_profile": risk,
})

# ---------------------------------------------------------------- EVENTS
SCREEN = {
    "app_open": "home", "signup_completed": "signup", "kyc_started": "kyc",
    "kyc_completed": "kyc", "bank_link_started": "bank_link",
    "bank_link_completed": "bank_link", "mf_discovery": "mf_explore",
    "mf_search": "mf_search", "mf_detail_view": "fund_detail",
    "mf_calculator_used": "sip_calculator", "watchlist_added": "fund_detail",
    "investment_started": "checkout", "investment_completed": "order_status",
    "sip_started": "order_status", "portfolio_viewed": "portfolio",
}
CATS = ["Equity", "Index", "Debt", "Hybrid", "ELSS"]
CAT_VIEW_W = [32, 24, 14, 15, 15]
CAT_CONV = {"Equity": 1.0, "Index": 0.62, "Debt": 1.1, "Hybrid": 1.1, "ELSS": 0.95}

events, investments = [], []
sess_counter = 0

def new_session():
    global sess_counter
    sess_counter += 1
    return f"S{sess_counter:07d}"

def log(uid, ts, name, sid, product=None, cat=None):
    if ts <= OBS_END:
        events.append((uid, ts, name, sid, product, SCREEN[name], cat))
        return True
    return False

def mins(m):  return pd.Timedelta(minutes=float(m))
def days_(d): return pd.Timedelta(days=float(d))

def add_investment(uid, ts, product, inv_type, cat, amount, source):
    investments.append([uid, ts.date(), product, inv_type, amount, cat, source])

def amount_for(inv_type, a):
    mult = {"18-24": 0.6, "25-34": 1.0, "35-44": 1.4, "45+": 1.8}[a]
    if inv_type == "SIP":
        v = rng.lognormal(np.log(2000 * mult), 0.6); v = np.clip(v, 500, 25000)
    else:
        v = rng.lognormal(np.log(7000 * mult), 0.9); v = np.clip(v, 1000, 200000)
    return int(round(v / 100) * 100)

for u in users.itertuples(index=False):
    uid, a, t, ch, pf, rk = (u.user_id, u.age_group, u.city_tier,
                             u.acquisition_channel, u.platform, u.risk_profile)
    ts = signup_ts[int(uid[1:]) - 1]
    sid = new_session()
    log(uid, ts - mins(rng.integers(2, 15)), "app_open", sid)
    log(uid, ts, "signup_completed", sid)
    status = "signed_up"

    # --- onboarding funnel
    p = 0.86 - (0.06 if a == "45+" else 0)
    if chance(p):
        ts = ts + (mins(rng.integers(1, 10)) if chance(0.7) else days_(rng.exponential(2)))
        log(uid, ts, "kyc_started", sid)
        p = 0.80 - {"Tier 1": 0, "Tier 2": 0.04, "Tier 3": 0.10}[t] \
            - (0.05 if a == "45+" else 0) + (0.03 if pf == "iOS" else 0)
        if chance(p):
            ts = ts + days_(rng.exponential(1.5)); sid = new_session()
            if not log(uid, ts, "kyc_completed", sid): continue
            status = "kyc_done"
            if chance(0.92):
                ts = ts + mins(rng.integers(1, 20)) if chance(0.6) else ts + days_(rng.exponential(1))
                log(uid, ts, "bank_link_started", sid)
                if chance(0.84 - (0.06 if t == "Tier 3" else 0)):
                    ts = ts + mins(rng.integers(1, 8))
                    if not log(uid, ts, "bank_link_completed", sid): continue
                    status = "bank_linked"
    # --- MF journey (only bank-linked users)
    watch = False
    if status == "bank_linked":
        p = 0.78 + {"Referral": 0.08, "Organic": 0.04, "Instagram": -0.06}.get(ch, 0)
        if chance(p):
            ts = ts + (mins(rng.integers(1, 30)) if chance(0.5) else days_(rng.exponential(1.5)))
            sid = new_session()
            if log(uid, ts, "mf_discovery", sid, "Mutual Fund"):
                status = "discovered"
                searched = chance(0.50 + (0.10 if rk == "Aggressive" else 0))
                if searched:
                    ts += mins(rng.integers(1, 5)); log(uid, ts, "mf_search", sid, "Mutual Fund")
                if chance(0.82 if searched else 0.62):
                    cats_viewed = list(pick(CATS, CAT_VIEW_W, rng.integers(1, 4)))
                    for c in cats_viewed:
                        ts += mins(rng.integers(1, 4)); log(uid, ts, "mf_detail_view", sid, "Mutual Fund", c)
                    chosen = cats_viewed[-1]
                    calc = chance(0.33 + (0.05 if rk == "Conservative" else 0))
                    if calc:
                        ts += mins(rng.integers(1, 4)); log(uid, ts, "mf_calculator_used", sid, "Mutual Fund", chosen)
                    if chance(0.25):
                        watch = True; ts += mins(1); log(uid, ts, "watchlist_added", sid, "Mutual Fund", chosen)
                    p = (0.45 + (0.17 if calc else 0)
                         + {"Referral": 0.10, "Organic": 0.05, "Instagram": -0.10, "YouTube": -0.03}.get(ch, 0)
                         + {"18-24": -0.05, "35-44": 0.04}.get(a, 0)) * CAT_CONV[chosen]
                    if chance(p):
                        ts += mins(rng.integers(1, 10)); log(uid, ts, "investment_started", sid, "Mutual Fund", chosen)
                        if chance(0.74 - (0.06 if t == "Tier 3" else 0) - (0.03 if pf == "Android" else 0)):
                            ts += mins(rng.integers(1, 5))
                            if log(uid, ts, "investment_completed", sid, "Mutual Fund", chosen):
                                status = "investor"
                                sip = chance(0.45 + (0.08 if a == "25-34" else 0))
                                itype = "SIP" if sip else "Lumpsum"
                                amt = amount_for(itype, a)
                                add_investment(uid, ts, "Mutual Fund", itype, chosen, amt, "app")
                                if sip:
                                    log(uid, ts, "sip_started", sid, "Mutual Fund", chosen)
                                    # monthly auto-debits (no app event)
                                    d = ts
                                    while True:
                                        d = d + pd.DateOffset(months=1)
                                        if d > OBS_END or not chance(0.88): break
                                        add_investment(uid, d, "Mutual Fund", "SIP", chosen, amt, "sip_auto_debit")
    # --- return sessions (retention)
    lam = {"signed_up": 1.0, "kyc_done": 2.5, "bank_linked": 3.5, "discovered": 5, "investor": 9}[status]
    if watch: lam += 4
    repeat_p = 0.08 + {"Referral": 0.04}.get(ch, 0) + (0.04 if rk == "Aggressive" else 0)
    n_sess = rng.poisson(lam)
    base = signup_ts[int(uid[1:]) - 1]
    offs = np.sort(rng.exponential(18, n_sess)) + rng.random(n_sess)
    pv_count = 0
    for o in offs:
        st = base + days_(o)
        if st > OBS_END: break
        sid = new_session()
        log(uid, st, "app_open", sid)
        st += mins(1)
        if status == "investor" and chance(0.65):
            log(uid, st, "portfolio_viewed", sid); pv_count += 1
        if status in ("discovered", "investor") and chance(0.35):
            c = pick(CATS, CAT_VIEW_W)
            st += mins(1); log(uid, st, "mf_discovery", sid, "Mutual Fund")
            st += mins(1); log(uid, st, "mf_detail_view", sid, "Mutual Fund", c)
            if chance(0.08):
                st += mins(1); log(uid, st, "watchlist_added", sid, "Mutual Fund", c)
            # manual repeat investment (investors), more likely with portfolio engagement
            if status == "investor" and chance(repeat_p + 0.03 * min(pv_count, 5)):
                prod = pick(["Mutual Fund", "Stock", "ETF"], [65, 25, 10])
                cat = c if prod == "Mutual Fund" else None
                st += mins(2); log(uid, st, "investment_started", sid, prod, cat)
                if chance(0.85):
                    st += mins(2)
                    if log(uid, st, "investment_completed", sid, prod, cat):
                        add_investment(uid, st, prod, "Lumpsum", cat, amount_for("Lumpsum", u.age_group), "app")

ev = pd.DataFrame(events, columns=["user_id", "event_timestamp", "event_name", "session_id",
                                   "product_type", "screen_name", "fund_category"])
ev = ev.sort_values("event_timestamp").reset_index(drop=True)
ev.insert(0, "event_id", [f"E{i:07d}" for i in range(1, len(ev) + 1)])

inv = pd.DataFrame(investments, columns=["user_id", "investment_date", "product_type",
                                         "investment_type", "amount", "fund_category", "source"])
inv = inv.sort_values("investment_date").reset_index(drop=True)
inv.insert(0, "investment_id", [f"T{i:06d}" for i in range(1, len(inv) + 1)])

# ---------------------------------------------------------------- CAMPAIGNS
cost_per_signup = {"Google": 180, "Instagram": 120, "YouTube": 220, "Paid Ads": 150, "Referral": 100}
users["month"] = pd.to_datetime(users["signup_date"]).dt.to_period("M")
camps = []
for (ch, m), g in users.groupby(["acquisition_channel", "month"]):
    if ch == "Organic": continue
    spend = int(len(g) * cost_per_signup[ch] * rng.uniform(0.85, 1.15))
    name = f"{ch.replace(' ', '')}_{m.strftime('%b%y')}_{'ReferralBonus' if ch == 'Referral' else 'Acquisition'}"
    camps.append([name, ch, m.start_time.date(), m.end_time.date(), spend])
camp = pd.DataFrame(camps, columns=["campaign_name", "channel", "start_date", "end_date", "spend"])
camp.insert(0, "campaign_id", [f"C{i:03d}" for i in range(1, len(camp) + 1)])
users = users.drop(columns="month")

# ---------------------------------------------------------------- DIRTY DATA (for 01_data_quality.sql)
dup = ev.sample(600, random_state=1)                       # duplicate event rows
ev = pd.concat([ev, dup])
orphan = ev.sample(25, random_state=2).copy()              # events for users that don't exist
orphan["user_id"] = [f"U{i}" for i in range(99001, 99026)]
orphan["event_id"] = [f"E9{i:06d}" for i in range(25)]
ev = pd.concat([ev, orphan])
early = ev[ev.event_name == "app_open"].sample(30, random_state=3).index   # events before signup
ev.loc[early, "event_timestamp"] = ev.loc[early, "event_timestamp"] - pd.Timedelta(days=200)
ev = ev.sort_values("event_timestamp").reset_index(drop=True)

bad = inv.sample(6, random_state=4).index                  # zero / negative amounts
inv.loc[bad, "amount"] = [0, -500, 0, -2000, 0, -100]
inv = pd.concat([inv, inv.sample(4, random_state=5)]).sort_values("investment_date")  # duplicate txn ids
nulls = users.sample(8, random_state=6).index              # missing attributes
users.loc[nulls, "age_group"] = None

# ---------------------------------------------------------------- SAVE
users.to_csv("data/users.csv", index=False)
ev.to_csv("data/events.csv", index=False)
inv.to_csv("data/investments.csv", index=False)
camp.to_csv("data/campaigns.csv", index=False)
print(f"users: {len(users):,} | events: {len(ev):,} | investments: {len(inv):,} | campaigns: {len(camp)}")
