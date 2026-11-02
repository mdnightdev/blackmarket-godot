# BLACK MARKET — DAILY CONTRACTS & PLAYER GROWTH SPECIFICATION

Status: Approved Architecture / In Implementation
Tracking: Act 1 & 2 Underworld Loop

---

## 1. Pending System Commitments
Before and alongside this overhaul, the following tasks are tracked:
1. **Market Consumable Visibility (In Working Tree)**:
   - Dealers stock both `TRADE_GOOD` and `CONSUMABLE` items via `Content.tradable_items()`.
   - Fixed in `market_screen.gd`, `tiers.gd`, `game_state.gd`, `hacker.gd`, `rumors.gd`, `street_events.gd`.
   - 859 GUT tests passing, 0 parse errors.
2. **Armory Image Deprecation (From Step 277)**:
   - Deprecate standalone weapon images; resolve all armory weapons and consumables from `items_atlas.png` using `ItemsAtlas`.
3. **Daily Tasks Overhaul (This Spec)**:
   - Transform repetitive daily chores into an active driver of player empire growth.
   - Redesign UI from flat spreadsheet rows with 84px SVGs into tactical contract cards.

---

## 2. Core Pillars of Player Growth
Daily tasks must not feel like a classroom exam. Every contract directly fuels the player's advancement:

1. **Rank & Cred Acceleration**:
   - Tasks grant substantial Street Cred (+25 to +100 Cred), noticeably advancing the player toward the next Rank (Street Runner -> Corner Kid -> Bagman -> Boss).
2. **Rank-Scaled Financial Payouts**:
   - Payout = `base_bounty * rank_multiplier + day_bonus`.
   - Low ranks: $1,500 - $3,000 (meaningful early capital).
   - Mid ranks: $15,000 - $35,000 (covers army pay, hospital beds, safehouse rent).
   - High ranks: $75,000 - $200,000+ (scales with syndicate empire scale).
3. **Direct Operational Asset Drops**:
   - Instead of pure cash, contracts directly award bag supplies:
     - 9mm Ammo (for armory defense and war)
     - Burner SIMs (evades wiretaps and automated police pings)
     - Combat Stims & Meds (heals wounded troops and boosts combat edge)
     - Fake IDs (passes roadblock inspections)
4. **Faction Standing (Family Trust)**:
   - Completing district-specific operations raises trust with the ruling family (Triads, Bratva, Cartel).
   - Higher trust lowers protection extortion on businesses and grants wholesale discounts.
5. **Daily Underworld Milestone Drop (3/3 Completion)**:
   - Completing all 3 dealt contracts for the day unlocks the **Daily Smuggler Cache**:
     - Bonus clean cash deposit
     - Rare consumable / arms crate
     - Major Street Cred burst

---

## 3. The 18 Contextual Contract Pool

### A. Street Contraband & Trade (Commercial Engine)
1. `wholesale_dump`: Sell $X worth of contraband in a specific target district.
2. `commodity_push`: Sell a targeted category of goods (e.g. 5x Pharmaceuticals or 3x Electronics).
3. `arbitrage_run`: Buy an item in district A and sell in district B for a net profit.

### B. Logistics & Black Market Supply
4. `dead_drop`: Complete an active bar or dealer merchandise order.
5. `contraband_run`: Deliver a high-risk Voronin smuggling crate without seizure.
6. `driver_dispatch`: Delegate a delivery errand to your hired crew driver.

### C. Turf & Enforcement
7. `capture_corner`: Attack and take control of a rival gang corner.
8. `scout_stronghold`: Perform an enforcer recon reading on enemy garrison numbers.
9. `station_garrison`: Reinforce a player-controlled corner with reserve troops.
10. `drill_crew`: Upgrade troop effectiveness at the Gym or purchase equipment from Rook.

### D. Underworld Heat & Evasion
11. `cold_night`: End the day with Heat strictly below 25.
12. `clean_slate`: Complete a full game day without triggering a police stop or raid.
13. `bribe_checkpoint`: Successfully bribe Ramos or use a Fake ID at a police roadblock.

### E. Syndicate Standing & Intel
14. `triad_favour`: Execute a favour for the Jade Dragon Triad.
15. `bratva_contract`: Complete a logistics favour for the Red Star Bratva.
16. `wiretap_intel`: Purchase high-grade market intel or hacker price overrides.

### F. Empire Economy & Black Ops
17. `launder_capital`: Clean dirty money through a front business or financial instrument.
18. `shark_principal`: Make an on-time or early principal reduction payment to Old Gao.
19. `field_burn`: Burn an operational consumable item during a street confrontation.
20. `high_roller`: Win a game of Dice or Slots at the Casino.

---

## 4. UI Architecture: Tactical Contract Cards
Replace `JobRow` in `jobs_sheet.gd`:

1. **Header Banner**:
   - `DAILY UNDERWORLD CONTRACTS`
   - Progress bar: `[====>        ] 2 / 3 COMPLETED`
   - Daily Cache status indicator (Locked / Claimable).
2. **Contract Card Layout**:
   - Background: `PANEL_LIFT` with sharp 0-radius borders (`LINE` border).
   - Left Tag: Mini 20×20 category icon (Crosshair for Combat, Briefcase for Trade, Skull for Crime).
   - Center Body: Bold title (e.g., `CONTRABAND RUN: OLD MARKET`) + clear objective caption.
   - Progress Gauge: Horizontal progress bar + text (`1 / 2 Completed`).
   - Right Bounties: Stacked rewards with mini item icons:
     - `+$12,500`
     - `+40 CRED`
     - `2x [Burner SIM]`
3. **Status Feedback**:
   - Active: Clean dark card with bright progress fill.
   - Completed: Dimmed card with green `CLAIMED` badge and strikethrough styling.
