# Black Market: The Case System

Design specification for Detective Moreau's investigation, fugitive lockdown, crew interrogations, and the courtroom bench trial.

---

### 1. The Witness & The Paper Trail

**Status: Incomplete (Deferred)**

The original implementation used placeholder numbers ($5,000 bribes) and printed win-percentage buttons. In an empire turning over millions, offering a witness pocket change while a UI label shows a flat 65% success rate feels like a toy, not a crime syndicate game.

This section is put on hold. It will be rebuilt when syndicate economics scale properly and when witness handling involves genuine risk, blackmail leverage, physical intimidation, and unpredictable consequences rather than a deterministic button press.

---

### 2. Living Under an Active Warrant (Fugitive Mode)

When Detective Moreau completes an indictment, an active warrant hits the street. The game world flips from an open sandbox into a high-pressure survival state.

* **District Travel**: Moving between sectors is no longer safe. Every transit carries an interception risk. Police cruisers and checkpoints monitor main thoroughfares. Players must use back-alley routes, bribe transit cops, or risk high-speed pursuits that damage vehicles and draw heat.
* **Financial Freeze**: Legitimate front businesses are padlocked by court injunction. Bank accounts are frozen. Only physical street cash remains usable. Carrying massive stacks of cash on foot increases vulnerability to rival stick-up crews and police confiscation.
* **Three-Way Firefights**: Initiating a corner attack or turf expansion while wanted triggers police intervention. Tactical units breach the scene mid-battle, turning turf skirmishes into chaotic three-way firefights where the player must fight both rival muscle and armed law enforcement.

---

### 3. The Lieutenant Under the Lamp (Loyalty Russian Roulette)

When operations go bad, key lieutenants like Vex or Old Gao get pulled off the street and thrown into an interrogation room with Detective Moreau.

* **The Interrogation Lamp**: Lieutenants are held in custody while Moreau uses wiretaps, seizure evidence, and threats of federal time to squeeze them.
* **The Loyalty Gamble**: Whether a lieutenant holds the line or breaks is not a flat percentage. It is a gamble influenced by their loyalty rating, their stress level, their cut of syndicate profits, and how well the player has protected them in past operations.
* **Consequences of Folding**: If a lieutenant breaks under the lamp, they sign affidavits that expose stash locations, reveal distribution routes, and padlock safehouses. Moreau adds hard exhibits to the case file, accelerating trial proceedings.
* **Intervention Choices**:
  * **Retain Defense Counsel**: Spend serious money to put a top-tier criminal lawyer in the room before the interrogation finishes.
  * **Call in Political Favors**: Lean on corrupt magistrates or city hall connections to challenge the arrest and issue an immediate release order.
  * **Let Them Sweat**: Refuse to spend resources and gamble that the lieutenant's loyalty holds up under pressure.
  * **Silencing Order**: Contract outside fixers to eliminate the risk before testimony hits open court, carrying extreme moral and crew morale penalties.

---

### 4. The Stagnation Clock & The 5 Ways Out

An active warrant cannot be ignored indefinitely. The Stagnation Clock starts ticking as soon as the player goes underground.

* **The Bleed**: Rackets lose efficiency, daily payroll drains cash reserves, legitimate revenue remains cut off, and rival syndicates start probing weakened territory borders.
* **The Danger**: Stay hidden too long without resolving the warrant, and the empire bleeds to death from financial starvation and territory loss.

#### The 5 Exit Paths:

1. **High Cash Bail**: Pay six-figure cash collateral to secure temporary freedom pending trial. Restores the ability to move between districts, but the player remains under court-ordered curfews. Getting caught with contraband or weapons results in immediate bail forfeiture and remanded custody.
2. **Rabbit Takes the Wheel**: Midnight Rabbit takes command of daily operations from the shadows while the boss remains locked up or in hiding. She charges a steep management fee and cannot launch aggressive expansion wars, but she keeps core rackets running, pays crew retainers, and defends held turf against hostile takeovers.
3. **Pier 9 Cargo Run**: The emergency exit. Forfeit all real estate, pack whatever liquid cash and weapons fit into travel bags, and slip onto Boris Voronin's container ship at Pier 9 under cover of darkness. This abandons the city, ending the run with exile penalties while unlocking legacy assets for future playthroughs.
4. **Serve the Time**: Accept a plea deal or short sentence at Iron Gate Penitentiary. Gameplay shifts to prison survival: managing inmate respect, avoiding shankings, and using contraband networks to send instructions outside. The player eventually walks free, but returns to a drastically altered street map with lost turf.
5. **Take It to Trial**: Reject deals, fight the indictment in open court, and force the prosecution to prove their case before a presiding judge.

---

### 5. The Courtroom Bench Trial (All-or-Nothing Dice)

When the player refuses to run or take a plea, the case moves to a bench trial. No sympathetic jury box, just an all-or-nothing showdown before a single judge.

* **Judge Archetypes**:
  * **The Hangman**: A hardline magistrate who despises street crime, ignores procedural technicalities, and hands down maximum sentences. Beating the Hangman requires dismantling Moreau's evidence so thoroughly that no legal basis for conviction remains.
  * **The Corrupt Fixer**: A compromised judge with quiet ties to city hall and backroom bookmakers. Unreceptive to standard legal arguments, but open to massive indirect bribes, campaign donations, and blackmail leverage delivered through defense counsel.
  * **The Procedural Reformer**: A strict constitutionalist obsessed with law enforcement protocol. This judge will dismiss wiretap transcripts, throw out seized evidence, and penalize Moreau for procedural overreach if the defense can prove improper warrants.

* **Defense Arsenal**:
  * **Defense Lawyers**: Hire legal representation ranging from overworked public defenders to ruthless private retainers demanding high daily fees.
  * **Procedural Motions**: File emergency motions to suppress illegally obtained wiretaps, challenge chain of custody on seized contraband, and disqualify compromised police witnesses.
  * **The Fall Guy**: Sacrifice a loyal low-level soldier to take full legal responsibility for the charges, sparing the boss at the cost of crew morale and severe financial payout to the soldier's family.

#### The Final Courtroom Roll:

The trial culminates in a high-stakes resolution roll. Moreau's compiled evidence exhibits, wiretaps, and seized ledger records are weighed against the player's suppressed evidence, defense counsel caliber, and judge disposition.

* **Clean Acquittal**: The prosecution's case collapses. Charges are dismissed with prejudice, the case meter resets to zero, frozen bank accounts are restored, padlocks are removed from front businesses, and Detective Moreau is sidelined for several weeks under administrative review.
* **Guilty Verdict**: The gavel falls. Immediate remand to Iron Gate Penitentiary. Massive asset forfeiture strips clean capital, held corners fall into gang disputes, and the player faces maximum incarceration.
