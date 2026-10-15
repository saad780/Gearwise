# Gearwise

A quiet gear comparison addon for **WoW: Forever**, interface 16001.

- Small **green up arrows** and **red down arrows** on bag items and quest reward icons.
- A compact tooltip with the active build, the equipped item being replaced, and up to six stat gains/losses.
- Automatic class and talent-tree detection for all nine classes; **29 build profiles**, including explicit Bear and Shaman Tank choices.
- Leveling priorities below level 60 give health and recovery extra value. A manual build override supports gearing for another role.
- Blizzard bags, combined bags, and the locally installed Bagnon/BagBrother button layout.
- Per-character settings; no startup announcements, sounds, automatic equipping, or quest reward selection.

## Use

Restart WoW after installing the new addon. Open **Esc → Options → AddOns → Gearwise**, or type **`/gw`**.

| Command | Action |
|---|---|
| `/gw` or `/gearwise` | Open the small settings panel |
| `/gw status` | Show the detected build and leveling mode |
| `/gw spec auto` | Follow your talents |
| `/gw spec` | List your class's available builds |
| `/gw spec bear` | Example manual build override for a Druid |
| `/gw arrows on` / `/gw arrows off` | Toggle bag and quest arrows |
| `/gw tooltip on` / `/gw tooltip off` | Toggle the tooltip comparison |

Set the build to **Automatic (talents)** for normal use. Before talents are spent, Gearwise uses a class-appropriate leveling default. Feral talent detection defaults to Cat; select Bear explicitly when gearing to tank. Shaman Tank is also an explicit override. Standard mode applies automatically at level 60, and both modes can be selected manually.

An equal stat score gets no arrow. Items above your level, unusable armor/weapon types, and unmet red class/profession requirements get a tooltip explanation. Uncached items wait for data before displaying arrows.

## How comparisons work

Gearwise uses independent, inspectable stat weights in `Gearwise/Profiles.lua`. These are leveling-oriented heuristics, not simulated damage or healing. A percentage is the change in the **compared item/weapon-set stat score**, not a percentage increase to your character's damage.

Rings and trinkets use the best valid replacement slot. Unique-equipped restrictions are checked against the remaining equipment. Two-handed weapons account for both occupied hands; off-hand weapon DPS receives its off-hand multiplier. Hunters value ranged weapon DPS, and Feral builds value weapon attributes and feral attack power rather than white weapon DPS. Young Druids and leveling casters' wands are handled separately.

The item reader combines the client's stat API with item tooltip text, preserves complete random-suffix/enchant links, and avoids counting duplicate unified hit/crit aliases. Healing items receive Forever's one-third damage conversion. Blizzard documents Forever's unified hit/crit and healing changes in the [official deep-dive recap](https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap).

Special effects, set bonuses, rotations, racial bonuses, hit caps, and unusual talent-dependent stat conversions are outside this small scorer. Items with proc/use/set effects receive a short **stat estimate** note. English tooltip-only bonus parsing supplements the locale-independent stat API. This is a practical leveling helper; keep situational and special-effect items when they suit how you play.

The source and artwork are original to this addon. Existing addons' files and saved variables are not required or modified. Turn off another gear-judging addon's tooltip/arrows if you want a single comparison block.

## Development

Install Python packages `lupa` and `pillow`, then run:

```powershell
python tools/build_icons.py
python tests/run_tests.py
```

The Lua 5.1 tests load the complete TOC and drive class/spec detection, all build profiles, comparisons, item loading, restriction handling, and bag/quest/tooltip integrations. In-game validation is still needed on the running Forever client.
