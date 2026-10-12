# Changelog

All notable changes to BLACK MARKET are listed here. Versions follow [Semantic Versioning](https://semver.org/), and the format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-10-12

### Added
- Act 1 story. Lexie teaches you the street, 午夜兔子 (Midnight Rabbit) joins once you own a corner, and the act ends in a war with Vex for Old Market.
- Old Market corners: Noodle Alley, Temple Steps, Ice House Wharf and Red Lantern Hall. Buy Mama Lin's corner, then take the rest from Vex. Sellers keep working the corner whoever holds it and pay you rent and protection every morning.
- The war. Pick which of Vex's corners to hit and who goes in. Every fight plays out as an animated battle, and both sides count their dead and wounded. Take every corner and Vex kneels.
- Crew picker: attacks and ambush defences show one slider per tier, Lunatics, Guards and Black Hand, capped at how many men one fight can take.
- Your headquarters: a gym where Rabbit trains your men four mornings a week, a hospital for the wounded, and an armory stocked from Rook's garage.
- The Black Hand, Rabbit's old unit, offered after your first lost fight.
- Vex's ambushes. Her crew strikes back at corners you took, with a siren and a 15-second countdown. Leave it to Rabbit or mobilise the crew yourself. A lost defence hands the corner back.
- Officer Brandt, Detective Moreau's junior, runs street stops and raids and follows you when you run hot.
- Ramos works for whoever holds the Shark's book. Buy the Shark out and he tips you off before raids.
- Rabbit's night in the cells, the Shark's trust, and a failure branch where the Shark sells your debt to Vex.
- Each character brings a small edge from their background.
- Do not disturb: silence job offers from Settings or the Jobs page. Offers still wait in Jobs and the tab shows a badge.

### Changed
- Heat comes only from loud moves: running from a stop, fights, hijacks, heists, muscle and war attacks. Buying, selling and travelling with goods add no heat. Heat has four levels, Calm, Noticed, Watched and Wanted.
- Police stops: run or stay put. A caught run or staying put leads to the talk, where you bribe, try a line or let him search. A clean search lets you go, goods found get you booked.
- Jail runs on real time and keeps the game open. Trading, travel and jobs wait until you walk out, and Rabbit can post bail with your cash.
- War numbers are ten times larger. Vex holds Old Market with about 4,000 blades.
- Turf strength and turf levels are gone. District access depends on street cred alone, and held districts pay $5,000 in rent and protection every morning.
- Voronin's crates pay 2.5 times the district job rate. Heists pay $80,000, $200,000 and $600,000, more as your rank grows.
- The driver now means fewer police stops, and the Wheelman skill improves escapes.
- The market keeps pink for the buy and sell button only.
- The Shark's sheet shows Repay and Borrow tabs only when borrowing is open, and he offers one money option instead of two.

### Fixed
- Corner sellers no longer vanish from their corners.
- A triad board could post two identical tributes on the same day.
- The war plan offered several buttons that all sent the same men.
- The raid scene and the ambush alert could render at zero size.

## [0.18.0] - 2026-10-08

### Added
- Money tiers. Goods, districts and dealers are street, middle class or wealthy. Dealers trade their own tier and the one below, and wealthy dealers turn down cheap goods.
- Four new districts: West End and Riverside open at rank 4, The Heights and Golden Mile at rank 7 with power. Each has its own dealers, customers and venues.
- Over 50 new middle class and wealthy goods, from ECU chips to old master paintings.
- Military goods worth $650k to $3.5M, from fighter jets to a nuclear warhead. Only Hugo Lindqvist sells them, and only to a Boss or higher.
- Phone jobs. Bar orders, family deliveries and Voronin's crates ring your phone, sometimes with a twist: rush, hot, fragile or a big client.
- Buy out the Shark for $300,000 once your debt is clear. He walks with you as free muscle, and his desk becomes yours for lending to dealers.
- New city map covering all ten districts. Roads out of your district are drawn on the map, and trips follow the real roads.
- Police roadblocks. Carrying a crate into one, you can risk the search, lie low until it lifts or take a detour. Recon tells you when it lifts.
- Meet on the way: customers and bar clients can come out to a stop between you for 80% of the price. A few use the meeting to short-pay.

### Changed
- Job pay follows the district's tier and your rank: street jobs pay $2k to $10k, middle class $10k to $40k, wealthy $50k to $250k. Street jobs stop calling once you outgrow them.
- Dealers and job givers talk like their tier: rough on the street, polished and impatient uptown.
- Road danger shifts a little every phase.
- Ambush tolls and lost cargo together never take more than 35% of a crate's pay.

### Fixed
- Bar boards no longer come up empty when most clients live in districts you can't reach yet.
- Trade and district sheets could grow past the top of the screen on some phones and black it out.

## [0.17.0] - 2026-10-08

### Added
- Profile page under Menu: your portrait, rank, cash, debt, net worth, heat and progress to the next street cred rank, with links to the bag, journal and settings.
- Journal: the Jobs page has Active, Completed and Failed tabs, so you can see every job you finished or lost.
- Bag tabs for All, Goods and Gear, with a capacity bar.
- Walking: when you can't afford the fare you can walk to a district for free. It uses most of the phase.
- Sell from the bag: tap a good to sell it to the best paying dealer in your district.
- Dealers talk before trading. Ask what they pay best for today, then trade or walk on.

### Changed
- Lighter buttons: smaller text, rounder corners and an outlined style for secondary actions.
- Conversations put their choices in a compact column beside the portrait.
- Settings is split into Audio and Gameplay and has a Done button.

## [0.16.0] - 2026-10-08

### Added
- Customers: 24 street customers across the six districts text orders to your phone. Sell from your bag, or broker the deal: the quote list shows where to buy, the fares and your profit. Some customers lowball, some haggle, some flake, and a few are undercover police with a visible tell.
- Shark errands: collections and package runs posted to your phone. Part of the pay comes off your debt.
- Phone offers: job banners slide in from the top. Tap to answer, or find them later under Offers on the Jobs tab. Accepting a job in another district offers the trip with its fare.
- Talk options at police stops and ambushes: play dumb, show a fake ID, name drop a family, mention Voronin or back away.
- A short tutorial from the Shark on a new game.
- A victory summary when Vex leaves the city.

### Changed
- Act 1: you start owing the Shark $100,000. No interest and no day limit. Pay a weekly minimum, $5,000 in the first week. Three missed weeks in a row ends the run. Borrowing opens after the debt is cleared.
- New fonts: Cinzel for titles and Inter for text. The BLACK MARKET logo keeps Rubik Dirt.
- Faster startup: portraits and backgrounds use compressed GPU textures, cutting load time and memory use.
- Economy pass: narrower daily price swings and wider gaps between districts, so the trip to a cheaper market is a real trade-off. Plain trading earns less early, and customer orders pay $1,000 to $3,000 profit on a good deal.

## [0.15.0]

### Added
- Hot runs with routes, invoices for jobs delivered on credit, and fairer odds shown as words.
