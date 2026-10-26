# Black Market: Syndicate Combat & Territory Engine

Production-grade specification for territory warfare, march dispatches, troop tiers, commander hierarchies, and combat casualty attrition.

---

## 1. The Core Philosophy

War is an event window, not an instant button to grind. You cannot take a city in a day. 

Three forces pull against each other continuously:
1. **Attacking**: Claiming territory and expanding syndicate revenue.
2. **Defending**: Protecting what you already hold from rival invasions.
3. **Casualty Cost**: The economic strain of hospital bills, dead soldiers, and lost commanders.

Every war decision costs you at least one of these three.

---

## 2. War Event Windows & Continuous Assaults

* **Timed War Events**: Warfare opens during designated event windows. While active, contested corners and rival districts become open to attack. When the window closes, district borders lock down.
* **Continuous Assault**: Players and AI can launch as many attacks and reinforcements as their dispatch lines allow while the window remains open.
* **Travel Delay & Distance**: Marches take physical transit time based on district distance. Launching an assault against a distant district burns valuable event time. Calling reinforcements or staging follow-up waves across town costs time that can outlast the war window.
* **Rival Counter-Events**: AI syndicates launch their own war events against player-held territory based on the same rules and timers.

---

## 3. March Lines & Dispatch Progression

* **March Lines**: Fixed at **5 simultaneous dispatch lines**.
* **Base Capacity Progression**:
  * Base march capacity scales with Street Cred and Player Rank up to **80,000**.
  * Reaches **200,000 total dispatch at Kingpin rank**.
* **Skill Grind Progression**:
  * Player skill tree progression grants up to **+50,000 additional capacity**, capping maximum base dispatch at **250,000**.
  * Additional capacity expanders and contraband gear can be acquired through high-tier black market contacts.
* **Enforcer Capacity Addition**:
  * Attaching an Enforcer to a march adds a flat **+5,000 crew capacity** to that specific column (e.g. a 120,000 march led by Vex deploys 125,000 troops).
* **March Staggering**: Dispatching multiple marches to the same corner from different origins arrives at staggered intervals, allowing staged arrival strategies.

---

## 4. The Exposed District & Unmanned Corner Risk

* **Men on a March Leave Home**: Soldiers deployed on an offensive march are physically absent from home garrisons.
* **Scouted Vulnerability**: AI rivals actively scout player territory. Leaving a held corner unmanned or lightly guarded invites immediate counter-invasions from rival syndicates.
* **Headquarters Vulnerability**: Stripping the syndicate Headquarters to fuel offensive campaigns exposes the boss compound. An undefended HQ invites rival raids that burn businesses, destroy equipment, and loot cash reserves directly from the vault.

---

## 5. Decision at the Gate & Reinforcement Clock

* **The Reinforcement Clock**: Defenders fighting on their home turf call in reinforcements over time. The longer an attacking march takes to travel across the city, the larger the defending garrison will be upon arrival.
* **Scouting Estimates**: Pre-attack scouting returns an estimated strength range, not a perfect headcount.
* **The Gate Decision**: When the march reaches the target perimeter, the player receives an updated scout report on the defending garrison and chooses:
  1. **Commit**: Breach the perimeter and fight now with deployed forces, accepting all casualty risks.
  2. **Pull Back**: Abort the assault and return home. The corner remains with the defender, and the player suffers a modest cash and morale penalty.
  3. **Stagger Second Wave**: Hold position outside the perimeter if a second march is en route on a free line and the initial squad has sufficient morale to wait.

---

## 6. Unit Tiers & 3-Factor Stat System

Every combat unit is defined by three core attributes: **Strength (Attack)**, **HP (Health Pool)**, and **Defense (Damage Mitigation)**.

| Tier | Unit | Strength | HP | Defense | Role | Clinic Cost |
| :--- | :--- | :---: | :---: | :---: | :--- | :---: |
| **T1** | Lunatics | Low | Low | Low | Cheap frontline meat-shield; absorbs initial hits | Low |
| **T2** | Guards | Moderate | Moderate | Moderate | Reliable mid-tier line infantry | Medium |
| **T3** | Black Hand | High | High | High | Elite shock troops; thick armor, heavy punch | Expensive |

### Damage Mitigation Formula:
1. `Damage Reduction = Defense / (Defense + ArmorConstant)`
2. `Net Damage Taken = Incoming Enemy Strength * (1 - Damage Reduction)`
3. `Total Casualties = Net Damage Taken / Average Unit HP`

---

## 7. Commander Canon & Command Authorizations

Commanders are unique syndicate assets. Their presence alters march capacity, combat modifiers, and squad deployment limits.

### A. Character Canon & Command Clearances

* **Rabbit (Male)**:
  * The player's fiercely loyal right-hand man.
  * **Canon Rules**: Rabbit's loyalty is unbreakable. He is never tested, can never be sacrificed as a fall guy, and **never charges the player for favors**.
  * **Command Authority**: The only commander cleared to lead all three tiers: **T1 Lunatics, T2 Guards, and T3 Black Hand**.
  * **Syndicate Vulnerability**: If Rabbit is captured or hospitalized, the syndicate loses the operational clearance to deploy T3 Black Hand squads on offensive marches.
* **Vex (Male)**:
  * Tactical combat coordinator.
  * **Command Authority**: Cleared to lead **T1 Lunatics and T2 Guards only**. Cannot lead T3 Black Hand.
* **Shark (Male)**:
  * Street enforcer and brute-force specialist.
  * **Command Authority**: Cleared to lead **T1 Lunatics only**.
* **Old Gao (Male)**:
  * Veteran defense coordinator and quartermaster.
  * **Command Authority**: Cleared to lead **T1 Lunatics only**. Best utilized anchoring compound garrison defense.
* **Dmitri Voronin (Male)**:
  * Russian shipping syndicate boss controlling Pier 9 harbor operations.

---

## 8. Symmetric AI Rivals

* **Identical Rule Engine**: AI syndicates operate on the exact same math, unit tiers, ranks, and dispatch limits as the player.
* **No Artificial Weakness**: AI rivals are not hardcoded 4,000-soldier dummies. High-tier rivals hold corners with massive garrisons (100k, 250k, 500k) composed of balanced T2 Guards and T3 Black Hand squads.
* **Strategic Retaliation**: AI syndicates monitor player borders, exploit unmanned corners, and launch coordinated counter-strikes when the player overextends.

---

## 9. Casualties: Attacker vs Defender Attrition

Casualty resolution follows the classic wargame standard. Attacking carried high mortal risk, while defending offers home medical safety.

### A. Attacking Marches (Offensive Risk)
* Casualties taken by an attacking force split into **Wounded** and **Dead** (Baseline: 60% Wounded, 40% Dead).
* **The Dead**: 40% of casualties die on the battlefield immediately and are permanently lost.
* **The Wounded**: 60% of casualties enter the hospital beds.
* **Hospital Overflow**: If the hospital is full, incoming wounded cannot be admitted and **die permanently on the field**.

### B. Defending Garrisons (Home Medical Advantage)
* **Defenders do not suffer outright battlefield death.**
* **100% of defender casualties become Wounded** and go directly to hospital beds.
* **Defenders only die if**:
  1. Hospital capacity is 100% full.
  2. The player or AI fails to heal wounded troops, leaving the hospital clogged so subsequent casualties overflow into permanent deaths.

---

## 10. Decisive Combat Resolution (No Ties)

* **No Artificial 3-Round Limit**: Combat runs to a full, definitive tactical conclusion.
* **Decisive Outcomes Only**: There are never draws or ties in combat.
* **The Tie-Breaker**: In razor-thin or equal power clashes, a `±1` tie-breaker resolves the fight on the spot. Defenders hold ground on dead heats, while attacking superiority requires a decisive margin.
* **Result**:
  * One side claims or retains the corner.
  * The defeated force is broken, suffers casualty splits, and routes home.

---

## 11. Overwhelming Force, Zeroing & Commander Capture

Attacking heavily fortified rival positions (e.g. 500k garrisons) with inadequate forces carries severe wipeout danger.

### A. The Zeroed Squad
* If an attacking squad takes 100% casualties, the march is **Zeroed**.
* Attacker troops suffer standard casualty splits (40% dead, 60% to hospital beds until full, overflow dead).
* The attached commander is **Captured** by the rival syndicate.

### B. Captor Decisions & Ransom Escalation
* **Captor Probability**: When a commander is captured, the rival syndicate rolls a probability check:
  1. **Demand Ransom**: Set a cash ransom demand with an active countdown clock.
  2. **Refuse Negotiations**: Refuse ransom and let the execution countdown clock run directly to zero.
* **Ransom Escalation**: Captors holding high-value commanders (especially Rabbit) may hike the ransom demand mid-clock, forcing the player to pay inflated sums or risk execution.

### C. Underworld Bounty Jailbreaks
* The player can post a cash bounty to mercenary crews to attempt an armed jailbreak.
* **Mercenary Unreliability**: Posting a bounty is never a guaranteed rescue:
  * Mercenaries may accept the job and successfully extract the commander.
  * Mercenaries may ignore the contract if the rival compound is too heavily defended.
  * Mercenaries may demand a bounty increase before committing to the breach.
* **Execution Clock**: If unrescued and unransomed when the countdown hits zero, the commander is executed, requiring dark-market clinic revival fees.

---

## 12. Garrison Engine & True Troop Allocation

### A. Strict Physical Troop Accounting (No Phantom / Infinite Multi-Posting)
* **Single Physical Source of Truth**: Soldiers stationed in a corner garrison are physically committed to that corner and deducted from the player's active reserve (`Army.reserve = Army.active - Corners.total_garrisoned`).
* **No Ghost Multi-Posting**: A player cannot use 50k troops to defend 5 separate corners while simultaneously attacking with those same 50k troops. Stationed troops cannot be assigned to offensive marches or posted elsewhere without being explicitly recalled.
* **Recall & Travel Delay**: Recalling a garrison dispatches them back into reserve. Troops in transit cannot defend or attack until their march back completes.

### B. Scaled Garrison Capacity & Overage Warning
* **Uniform Corner Capacity**: Corners hold up to a defined ceiling (default: **50,000 men** per corner, scalable via district upgrades and stronghold traits).
* **Explicit Overage Warnings**: The UI will not silently swallow or truncate troop dispatches. If a player attempts to post or dispatch more troops than the corner capacity or current reserve:
  1. The interface blocks the dispatch with an explicit warning banner (`"Cannot exceed corner capacity of %s"` or `"Insufficient free reserve troops"`).
  2. The input slider dynamically clamps to `mini(available_reserve, corner_capacity - current_garrison)`.
* **Zero Phantom Lookouts**: Unmanned corners have 0 defense power. The legacy +50 phantom lookouts are completely eliminated—territory requires real blood and stationed soldiers to hold.
