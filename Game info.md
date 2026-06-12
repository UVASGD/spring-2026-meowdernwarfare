**Backstory:**  
The Economy crashed under the tyranny of \[insert main villain\]. Now, our happy little characters must survive in a battleground where they must defend their farms and grow crops to survive. 

**Basic Gameplay Loop:**  
4 players, each player spawns in their farm with their pre-set crops. Crops will spawn in the center zone occasionally, and players must fight for them. Players respawn on death unless they’re out of crops, in which case they die permanently. Last player standing wins. 

**Mechanics:**

* Crops   
  * spawn in and give players special perks if they take them to their farms. Can be stolen by other players. Better crops spawn as the game goes on.  
* Pickaxe/shovel

**Character Mechanics:**

* Shoot  
* Pickaxe/Hoe/Shovel  
  * Universal action that allows players to steal crops in melee range  
* Dodge roll  
  * Short movement in one direction  
  * Invincible while rolling  
  * If contacting bullets while in dodge roll, gain ult charge based off of bullet damage  
* Ability 1  
* Ability 2  
* Ultimate

**Lategame Management:**  
Random events?  
Crops become sentient and fight?  
Storm system?  
Crazy powerful game-winning crop spawns? 

**Characters:**

* ~~Dealer~~  
  * ~~gun, invisible, drug ult~~  
* ~~Burple~~  
  * ~~Shoot: default bullets~~  
  * ~~Ability 1 \- Grenade \- projectile that can be thrown over (aka through) walls, going wherever the player clicks as the landing point (make a new cursor mode with icon.svg for now, to indicate possible landing points until clicked). Limited range, similar to planting mechanic’s range. Explodes on contact with a player or when it reaches landing point.~~   
  * ~~Ultimate \- Missile Strike \- same mechanic as grenade, but leaves a lasting AOE that is much larger than the grenade.~~  
* ~~Garebare~~  
  * ~~Shoot: soundwave bullet, grows bigger but weaker over time, shotgun-esque~~  
  * ~~Skill 1: sonic burst \- large and slow projectile~~   
    * ~~stuns characters on hit for 2s~~  
    * ~~stun: unable to move, shoot, dash, or use abilities 1 or 2 (can ult)~~  
  * ~~Skill 2: Frequency Interference emitter:~~  
    * ~~place up to 2 frequency interference emitters (FIEs) at a time where Skills/Ults cannot be used (unless you are the Garebare who placed it). They last until destroyed by an enemy, in which case Garebare must wait 10s to place a new one (counted independently). Implement with area2D~~  
  * ~~Ult: Amplitude~~  
    * ~~sonic burst that does big damage in a circular area2D around caster~~  
      * ~~any existing FIEs will also emit damage in their areas by self destructing (queue free after, and refresh user’s cooldowns)~~  
* ~~Loan Shark~~  
  * ~~black panther type, melee attacks~~   
  * ~~Ability 1 \- “Reapossession”~~   
    * ~~DASH into players to deal damage\! Players marked with “Payment Plan” will refresh “Reapossession” on hit\!~~  
  * ~~Ability 2 \- “Payment Plan”~~  
    * ~~Throw a contractual projectile that deals damage over time. Players hit with “Payment Plan” will be *marked for collection*\!~~  
  * ~~Ultimate \- “Feeding Frenzy”~~  
    * ~~Activate Bull Market to spawn a radius around you. This radius will hit players with a strengthened version of “Payment Plan”. This allows for players to set themselves up for infinite dashes for a set amount of time *(as long as they hit their dash*\!).~~  
* Magical Anime Girl (B.A. Angel)  
  * Evolves over time into a biblically accurate angel   
    * 0-3 crops: normal  
    * 4-6 crops: Add extra eyes, and wings, paler colors  
    * 7+ crops: Seraph  
    * Does not devolve if lost crops  
  * abilities unlock over time  
    * Ability 1 \- always unlocked: pink energy blast (close range mid-damage)  
    * Ability 2 \- unlocks on 4 crops, AOE DOT light blasts (circular area)  
    * Ult \- unlocks on 7 crops. Divine Judgement: Huge AOE, long duration, mid damage, fast ticks. Doesnt rely on ult points, instead has a long CD (30s)  
* ~~Gooblin the Goblin~~  
  * ~~Shoot: Sparkling anime tears, alternating from left and right eyes (similar to dbd the trickster)~~  
  * ~~Skill 1: boogie bomb→ Throws disco bomb that causes flashing rager lights to blind ppl (Similar to the squid in mario kart)~~   
  * ~~Skill 2: Retreat → temporary speed boost, meant to be used after skill 1 to retreat to safety out of sight~~  
  * ~~Ult: summon Drooglin the Dragon, close off everyone’s farm entrance with (harmful) fire for 30s~~  
    * ~~the Gooblin who casted it is unaffected by the fire. If two or more gooblins, they are affected by the other’s fire~~  
* Xyler and Fergus  
  * stance change character  
  * Ability 1: swap stance  
    * Xyler: Slow movement, high damage \+ high speed melee  
    * Fergus: fast movement, low damage \+ high speed ranged  
  * Ult:  
    * Xyler: Faster movement and damage boost  
    * Fergus: Boost bullet speed. Every enemy has a “mark” amount that increases when hit by the bullets. Every 10 bullets, Xyler spawns next to them and slashes them, resetting their marks.   
* ~~Elohel~~  
  * ~~A melee \+ range character that’s a weapon swapper~~   
  * ~~Skill: Swaps between weapons (like shulk / CS Buy Menu)~~   
  * ~~Ult: Perfect parry \+ dash(reflects abilities, projectiles, effects) if within 1-2 frames~~  
* ~~Spoods~~  
  * ~~A movement / momentum centered character~~   
  * ~~Passive Skill: Damage scales with speed (but can’t kill unless with ultimate)~~  
  * ~~Skill: Can short hop to characters to build up a speed gauge (ramps up from small to large)~~   
  * ~~Ult: Spends \[...\]% of speed to execute an enemy.~~   
* ~~Peresey~~  
  * ~~A parasitic support~~  
  * ~~A host is chosen and can either spend the game working with the parasite or spend time trying to get rid of it~~   
  * ~~Skill:~~   
    * ~~When hostless, designate someone as a host and can only permanently die when their host permanently dies (the character’s farmland is emptied and can’t be used and is full of blight). Peresey takes the form of its host, but has different abilities.~~   
    * ~~With a host, increase their speed and damage, and slow themselves.~~   
  * ~~Ult:~~   
    * ~~When other players alive: Swap Position with host (drops carried crops)~~   
    * ~~When host is the only player alive: Gain 20% of host’s stats, and enter a sudden death state (first to kill the other wins the game).~~   
  * ~~Counterplay:~~   
    * ~~Other players can get rid of Peresey by planting 4 crops in Peresey’s farm slot, removing him from his host,putting his skill on a cooldown, and killing him before he finds another host.~~   
    * ~~Peresey does 30% of his host’s damage and has low durability.~~   
* ~~Vegan~~  
  * ~~Can launch crops to hurt people. Uses their shovel to hurt people.~~   
  * ~~Ability: Slowly form a ring around vegan that stuns enemies directly standing on the ring when complete (we can call it onion ring)~~   
  * ~~Ult: Can eat enemy crops after a \[...\] second channel (resets on stun, on kill, and after the cooldown)~~  
* ~~Profen~~  
  * ~~He be profen, designed like a holy paladin~~   
  * ~~Ability: Heal for 10% HP (resets on kill, after hitting 2 attacks, and after a short cooldown)~~   
  * ~~Ult: Rushdown, jumps and bounces on an enemy with his sword like a pogo stick~~   
* Elongated Muskrat  
  * Shoot: flamethrower, re-skinned gun \- high fire rate but slow bullets (simulates a flamethrower)  
  * Ability: Crop Magnet – steal a crop from any player within range, if they’re holding one. Or, allow the user to steal a crop using the same range as planting a crop in their own farm would allow. Window of ability: 5s. Cooldown: 40s  
  * Ult: Cybertruck \- player gets in a cybertruck. create a large circular area, wherever the user clicks in this area, the cybertruck teleports to instantly (0.5sec cooldown in between teleports), creating a line between that point and the current position – anyone touching that line gets damaged. The lines fade in 0.5 sec, ult lasts 5s and the ult ends in a big explosion that damages anything still in the area. 

**Skill bank (ideas w/ no character in mind yet):**

* Projectile reflection  
* Melee+ranged character  
* Fake crops that explode n shi   
* Berserker character (only strong if you keep damaging people)  
* Crop magnetism  
* Blight (kills crops if some requirement is satisfied) 

**Crops:**

* Turret crop (passive defense of farm)  
* Crop that boosts other crops’ growth  
* Crops that boost base stats   
* Crops that charge ult faster  
* Single use consumables 

**CHARACTER ART:**  
Characters are at a top-down angle which can be kinda annoying   
Any art style is allowed   
Image resolution does not matter too much   
Each character needs still images for:

* Character select (bust)  
* Ult (bust) (Can be the same as character select)  
* mini icon 

Each character needs an animation for:

* idle  
* walking  
* running? could just be walking sped up   
* Shooting/attacking while idle  
* shooting/attacking while running   
* Reload while idle  
* Reload while running  
* Skill 1 while idle   
* Skill 1 while running   
* skill 2 while idle (if character has second skill)  
* skill 2 while running (if character   
* Ult while idle   
* Ult while running   
* Death  
* Character-specific animations 

**MAP ART:**   
There is a template (I’ll find later) that has all the possible map tile configurations. You can trace over this with your own designs to make a sheet that’s easy to use when I add to the game 

We would like to add animated tiles, but we will explore that idea later 

**CROP ART:**  
Probably the easiest, no animation required (but you can if you want), no real limitations here. Just draw what you want and make sure the BG is transparent and that’s kinda it 

**UI/UX ART:**  
Player UI mockup  
![][image1]

Needs art:  
Dealer  
Burple  
Loanshark (WIP)  
Xyler and Fergus  
Elongated Muskrat 

UI:  
main gameplay 

* Hero-based icons  
* General info 

Tutorial Screen

* Layout concept  
* background art   
* button art

Pause menu 

* button art

Settings Menu

* button art

Leaderboard (tab)

* Concept art  
  * contains Player scores \+ your crop info  
* bg art

Lobby screens

* Join/host game concept art  
* button art  
* bg art

Character Select Screen:

* Concept art  
* Background 

Font

Crops:

Have people come up with crop ideas:

MSE checklist:

- [x] ~~Fix loanshark anim bugs~~  
- [x] ~~add blast berry and iron root art~~   
- [x] ~~add crop spawner sprite and anim~~  
- [x] ~~plug in moon music~~  
- [x] ~~Make other menus not stop main menu music~~  
- [x] ~~Merge UI~~   
- [ ] Implement Burple   
- [ ] Record some skill videos and add in   
- [x] ~~fix crop tooltips~~  
- [ ] new lobby UI   
- [ ] 

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAASQAAAEiCAYAAABQoK/xAABoT0lEQVR4Xu3dZ7dlRbk+/Pn6jL8vdJyg42A+R8AjooJIFlBUMoKSmtTkjORMEwWUIKCCIEkQQUUBBSVKkowKIhnxG5yPUM/+TZ/iVN8rzbX22r337q4e4xq9V8255pqh6qrrDnXP5h//+Eeaa7zzzjvpmWeeSb/+9a/TmWeemc4777y0ww47tNhyyy3T/vvvn/bYY4+06667plNPPTWdeOKJ6Vvf+la77/e///102WWXpVtuuaX93g9+8IO0bNmydNVVV7XbL7zwwnbfiy++OJ199tnpuuuuS6eccko66KCD0nHHHZeOOeaYdNhhh6Xjjz++bT/kkEPSSSed1GLfffdtcdRRR6Xvfve7ae+9904HH3xw+9199tknnXzyyekb3/hGWrp0aXuOe+21V9u2yy67tOe72267tb+x++67pz333DMdccQR7ff9feSRR7a/7TedWz73yy+/PP385z9vr+f2229Pd955Z/rTn/6Unn322fZe/eUvf0lvvvlmzz2sqJgExt4f//jHtn899NBD7fgwTq655pp00003tf1XnzaGjI2zzjqr7ef6vz7v/6OPPjptv/32accdd2z/t9/Xv/71tM0227R9fb/99kvbbbdd+p//+Z/0qU99qt3nl7/8Zc+5dEETG6aFV155Jd19993tQDQwXRzycSEHHHBAexEG67HHHpsOPfTQlgwQQSYDA9uF++wG+d8+bo5juYFu7IEHHtj+jcQQC1I4/PDD0wknnNDeaCRgu78vuuiidMEFF6TTTjstnXPOOS2ZeQDnn39++vGPf5xuuOGGdMUVV7T///CHP0w/+tGP0i9+8YuWNG688caWSO677770u9/9Lj3wwAPprrvuarc9/PDD6fnnn08vvvhii0ooFYsRf//739Pbb7/d/o3I9OW//vWv6aWXXmoFxZNPPpnuvffednwYL9dee20rFowxAsG4zmPd+H7uued6fmMUmtgwDjCvmf6JJ55Ib731VqtcsOY666zTsuXHP/7xtMYaa7Rt2267bUseWWkgFqSALBACfO9730t/+MMf0lNPPZVee+219PLLL6c33nijvVFuUIR25+HveG4VFRUrFgQB0UB9ERnUWNxnFJrYMA5+85vftKYJmbbeeuultdZaK2299dbpC1/4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dlpLBq+99lrPvhF///vf03e/+9108MEHpy9/+ctp1113Tb/97W979ot48MEH+x7/ySefTEcffXTaZ5990rnnnpt+8pOfpNdff71nv4w99tijJafYvrKjiQ0V04OZmQTXCc2GJ510Utpkk03Sl770pb6dtmI6eOedd9rBzAx66KGHltu2bNmydN111/V8p8QDDzyQbr755vTXv/61/XzyySenAw88ML344os9+yKu3/3ud62JdeSRR6avf/3r7d9xv9NPP73tA7F9EA444IB06aWX9rSv7GhiQ8XswO43S/IL6MQ6KSLSwZ977rnWT2C2tU/8bsV0cOutt7ZK9C9/+UvPNkrV84jtJe666650/PHHt8R1zz33tGRyySWX9OwHtplwfvSjH6Xnn38+3X///e2zj/tdfPHFfYkqQ78xSTENTWSHHHJIS3Rxv5UdTWyomAw6Ih/A7rvvnrbeeuu2Q5lZn3rqqXbGzvsdc8wxad99902PPfZYzzEqZo8LL7wwbbDBBu19jtuAcuITiu0l7rjjjlZdUUomEJMK/1PcD8kgqtL5jQSZZtEh7vv77bffcm1Md23bbrtt2m677Vozbe+9905LlixpzfvqQ6oYG4joO9/5Ttptt91auc4R+r3vfe9duR/Bh8GfQS3FbRWzw0033dQqIwP75z//ec92CoRfaJQ6RRScz3fffXdLDBAjXgiHb+qPf/xjTztSeeWVV5Zr5y8ySXGW5zYm4BZbbJFuu+22VhUx/+K5rGpoYkNFN/z5z39uJThyMcshJVK/VEP9QDXtueeefc2JislhMB922GHpN7/5TXrzzTfbAY6gBBTyPldddVU66qijer4bceedd7bPVgSM6cYPGPcBv9cvakedxcCF8xCxY9aV7fqPCBs1NE4kb2XtP01sqBgN/iAzMV+Qzqrjxn0GwWy7dOnSsb5T0Q0I4umnn27NMtE1z6f0F7n3P/jBD3q+F4G4qB8OcT6iQb4fJls/888ERV2VbdQZ5SbaVrYjTubazjvv3KYC8EcxGeMxM0yE55xzTnstzMorrriiZ5/FjCY2VPTHW2+91c5mZDdJzregc5uN477DYMZFSP0iNhWzAyISoqdQhOiF/Q8//PBWtSICgx4pGPT8eEL6yCce55ZbbmnJRu4SNduPdEAaQT/TUDTt+9///nJtFBzfEJJDThQOVcS004eY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>