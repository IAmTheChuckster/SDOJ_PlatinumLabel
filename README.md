# DoDonPachi SaiDaiOuJou Platinum Label
A patch for `DoDonPachi SaiDaiOuJou (Japan, 2012/ 4/20)`<br>
This repository holds only source, tools and notes. No ROM data is included; you patch your own legally owned dump

## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br> 
While Claude was used I put effort in making sure there are balanced gameplay.<br> 
I did all the testing and planning.

## Patch Notes

### Title screen
The title screen shows the mode lines **Original Arcade** (the default), **1.5+**, **Power Mode** and **Omake**. Press Up or Down to move the arrow, then insert a coin and press **START**. Original Arcade plays the unpatched game. **1.5+** is the original game with only the additions listed under *1.5+* below. **Power Mode** and **Omake** play with all the changes listed under *Power Mode and Omake*.

### Boot and warning screens
The boot screen shows **SDOJ PLATINUM LABEL** with the build number and **2026.11.20**, and the warning screen shows a short unofficial-project notice, **HAVE FUN!!!** and **2026/11/20 PLATINUM LABEL**.

### 1.5+
The original arcade game (buttons, weapons, bombs, bees, stage 1 boss pods, meter during hyper: all original) plus:
- **Enemy health bars**: big enemies (500 HP and up, 224 HP and up on stage 3), the stage 3 ship's turrets and pods and the stage 4 mid boss's parts show a health bar with their percentage while they are being hit, drawn under the HUD.
- **GP bonus during hyper** as in Omake: by the hyper level at the start of the hyper, Lv1 x2.0, Lv2 x2.2, Lv3 x2.4, Lv4 x2.6, Lv5 x2.8, Lv6-10 x3.0.
- **Hyper meter** fills **2 times as fast** outside hyper (during hyper as the original).
- **Big stars**: in a hyper started at **HYPER Lv 6 or more**, every cancelled bullet turns into a big star (Power Mode and Omake: in every hyper).
- **Hidden bees** (Ver 1.5 chart): each bee fills the meter by your combo, 0% up to 200 hits, then +1% per 200 hits, 100% from 20,000 hits (original: +1% per 50 hits, at most 30%). Collecting all 8 bees of a stage still gives a full meter.
- **Bomb maximum bonus** (also in Power Mode and Omake): picking up a bomb with full stock pays, every tick of the bonus, **2,222 x (Rank / 5 + 1) x Bomb Maximum Level** (Ver 1.5 formula; original: 2,222 x level). Power Mode and Omake use their own rank.
- **No miss bonus** (also in Power Mode and Omake): 50 / 100 / 150 / 200 / 250 million for levels 1-5 (Ver 1.5; original 20 - 100 million).

### Power Mode
- **Weapons**: Button 4 switches between **NORMAL** and **BOOST** instead of bombing (every game starts on NORMAL). Both use the full Expert shot and laser with side ships.
- **Bottom bar**: SDOJ's bar shows **NORMAL / BOOST** (the selected one bright) and your bombs as animated bomb icons, drawn on top of the HUD and moving with it.
- **烈怒 gauge**: a DoDonPachi DaiFukkatsu Black Label style gauge (frame, half-transparent background, animated fill with a faint (quarter-opacity) copy scrolling right on top) sits where INSERT COIN would be; INSERT COIN, PRESS 2P START and the other messages are hidden. From 50% the animated **烈怒** label appears. The gauge hides during the score tally.
- **烈怒 bullet streams**: from 50% on the gauge, every on-screen enemy with hit points fires a bullet aimed at you every **10 frames**.
- **GP bonus** follows the gauge: x2.0, +0.2 per 10%, up to x3.0 from 50%.
- **Bomb multiplier**: picking up a bomb sets kill score x2, each further pickup +1 (up to x99); using a bomb resets it.
- **Shots add to HIT**: every shot that hits something on screen adds 1 to HIT.
- **HYPER** text flashes gold and white while a hyper is ready.
- Otherwise as Omake below.

### Omake
- **Shots add to HIT**: every shot that hits something on screen adds 1 to HIT.
- **Bullet streams in hyper**: while a hyper is running, every on-screen enemy with hit points fires a bullet aimed at you every **10 frames**.

### Power Mode and Omake
- **Buttons**: buttons 1 and 3 work as in the original game. **Button 2 = hyper only**: it starts a hyper when one is ready and does nothing otherwise (it never bombs). **Button 4 = bomb only**, so with a hyper ready you can bomb with button 4 and press button 2 during the bomb to go into hyper.
- **Ending a hyper**: press button 2 during a hyper to end it. All bullets on screen cancel into small stars and HYPER Lv goes back to 0 (no bomb is used).
- **Expert weapon**: every dress uses the Expert shot and laser. You still pick your ship and dress, but the dress only changes the look.
- **Bombs**: **6 bomb slots** for every dress type; you start with **3 bombs** and each death gives **+1 bomb** (up to 6).
- **Bomb items** cancel all bullets on screen into big stars.
- **1UP items** (e.g. the hidden one from the stage 4 mid boss) also cancel all bullets on screen into big stars when picked up.
- **Hyper meter** fills **2 times as fast** as the original game outside hyper (death bonus unchanged). During a hyper nothing fills it (kills, laser hits and stars add nothing); only hidden bees raise **HYPER Lv**.
- **GP bonus during hyper** by the hyper level at the start of the hyper (hypers spent): Lv1 x2.0, Lv2 x2.2, Lv3 x2.4, Lv4 x2.6, Lv5 x2.8, Lv6-10 x3.0 (original: x1.1-x1.5, then x2.2-x3.0). It stays the same until the hyper ends, even if HYPER Lv goes up.
- **Hyper ready voice**: the "HYPER SYSTEM READY" voice also plays whenever HYPER Lv goes up during a hyper.
- **Hidden bees**: every hidden bee shows **+100%** and gives exactly **one hyper** (max 10; no combo-based meter gain). During a hyper it raises **HYPER Lv** by 1 instead (the GP bonus stays as it was). Every bee also cancels all bullets into big stars.
- **Bullets cancel near enemies**: a bullet that flies within 24 px of an enemy (any bullet emitter) turns into a small star (a **big star** during hyper), and bullets within 16 px of one cancelled the frame before cancel too, so it ripples outwards. Bullets younger than 7 frames and a bullet's own birthplace don't count.
- **Stage 1 boss pods**: the two side pods are separate targets. Each has its own health (25% of the boss's), takes only the hits that land on it, and explodes and disappears when destroyed (+100,000 points each), one at a time. Hits on a pod don't lower the boss's health.
- **Pod health bars**: while a pod is being hit, a health bar with its percentage is drawn on it and follows it (the Xbox 360 Arrange mode bar, taken from your own 360 copy when patching).

## Patching the game
You need:
- your own **ddpsdoj.zip** (MAME set, DoDonPachi SaiDaiOuJou 2012/4/20) containing the original u4, u2, u23 and u24 files (u4 CRC `e2a4411c`), and
- the **DFK Black Label bar graphics** for Power Mode: `dfk_bar_bg.png`, `dfk_bar_frame.png`, `dfk_maximum.png` (240 x 16) and `dfk_font_tall.png` (208 x 15), cut from your own DoDonPachi DaiFukkatsu Black Label, loose or in one zip. They are required; nothing from them is stored in this repository.
- your own **Xbox 360 DoDonPachi SaiDaiOuJou Games-on-Demand package** as a zip (it must contain `B699E3A8BDFD9BB5BE92` and the `B699E3A8BDFD9BB5BE92.data` folder; any folder inside the zip). The boss pod health bars are cut from it while patching; nothing from it is stored in this repository.

The patcher creates:

- `plat_u4` - the patched program ROM (CRC `121b54ce`)
- `ddpsdojplat.zip` - your set with u4 replaced by `plat_u4`, and u23 / u24 by `plat_u23` / `plat_u24` (the sound ROMs with dfkbl's NORMAL / BOOST switch sound added, taken from your own dfkbl.zip)
- `DoDonPachi SaiDaiOuJou Platinum Label.mra` - the MiSTer MRA

### Web patcher
1. Open the [web patcher](https://iamthechuckster.github.io/SDOJ_PlatinumLabel/).
2. Load your `ddpsdoj.zip` (or a loose u4 file). Everything is processed in your browser and nothing is uploaded.
3. Load the DFK bar graphics (step 2 on the page).
4. Load your 360 GOD zip (step 3 on the page). It is read in pieces, so its size (about 3 GB) is fine.
5. Check that the files show as OK.
6. Download **ddpsdojplat.zip**, **DoDonPachi SaiDaiOuJou Platinum Label.mra** and **plat_u4.zip** or **plat_u4**.

### Python script
Needs Python 3 and no extra packages. Download `sdoj_patch.py`, `sdoj_patch_data.py` and `sdoj_god.py` into the same folder, then run:

```
python3 sdoj_patch.py ddpsdoj.zip --god 435A07E7.zip --dfk dfk_bar.zip --zip --mra
```

`--god` (required) is your 360 GOD zip, `--zip` writes `ddpsdojplat.zip`, `--mra` writes `DoDonPachi SaiDaiOuJou Platinum Label.mra` (it needs the .mra from this repository's `mister/` folder, either in `mister/` beside the script or next to the script), and `-o FILE` sets the output path for `plat_u4`. A loose u4 can be given instead of the zip (without `--zip`).

### Using the patched files
- **MAME 0.289**: copy your `ddpsdoj.zip`, rename `plat_u4` to `u4` inside the copy, and run `mame ddpsdoj`. MAME will warn about the changed u4 checksum - that is expected.
- **MiSTer CV1k**: copy `ddpsdojplat.zip` to `games/mame` and `DoDonPachi SaiDaiOuJou Platinum Label.mra` to `_Arcade`.

Developers: full build notes are in [dev_notes/BUILDING.md](dev_notes/BUILDING.md). `src/patch.s` is the SH-3 source; `python3 tools/build.py` (needs SH binutils such as `binutils-sh4-linux-gnu`) regenerates `sdoj_patch_data.py`; then `python3 tools/make_web.py ddpsdoj.zip GOD.zip` regenerates `index.html`, the .mra CRC and this README's CRC (the build number comes from `tools/BUILD`). `sdoj_god.py` reads the GOD package (hash blocks, XDVDFS image, Cave `CA022010.bin` archive, Cave LZSS, ARGB1555 TGA) and builds the health bar atlas written to u4 at 0x3C0000. The patch adds a small boot loader in unused u4 space that copies the new code to free work RAM (0x0CE00000) and redirects a few code pointers in the unpacked program.

## Testing
This patch was tested with MAME 0.289 and [CV1k core for the MiSTer FPGA by Raki](https://www.patreon.com/c/ikamusume/posts)<br>
It may even work on a PCB but do so on your own risk.

## Credits

- [IAmTheChuckster](https://github.com/IAmTheChuckster)  project, testing
- [Claude](https://claude.ai) (Anthropic)  reverse engineering and patcher code
- Tested on the CV1k core for the MiSTer FPGA by [Raki](https://www.patreon.com/c/ikamusume/posts)

## Disclaimer

This repository contains a fan-made patch for research and technical analysis. The repository does not intentionally distribute the original game ROM, executable, or game assets. Users must obtain their own copy of the original game. This project is unofficial and is not affiliated with, endorsed by, or authorized by CAVE. All rights to the original game and its associated intellectual property remain with their respective rights holders. No license to third-party copyrighted material is granted by this repository.
