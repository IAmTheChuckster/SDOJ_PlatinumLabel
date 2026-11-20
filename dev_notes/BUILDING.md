# Building SDOJ Platinum Label

Current build: see `tools/BUILD` (build 265 when this was written, 2026-11-20).

## What you need
- Python 3 and Pillow (`pip install pillow`).
- SH binutils: `binutils-sh4-linux-gnu` (Debian/Ubuntu, works under WSL) or an `sh-elf-*` toolchain. `tools/build.py` finds `as`, `ld`, `objcopy` and `nm` itself.
- Your own dumps (never commit them; `roms/` holds them locally):
  - `ddpsdoj.zip`: the original DoDonPachi SaiDaiOuJou set. The u4 CRC must be `e2a4411c`.
  - The Xbox 360 Games-on-Demand zip (`435A07E7.zip`): the health bar graphics come from it (`sdoj_god.py`).
  - The DoDonPachi DaiFukkatsu Black Label zip (`dfkbl.zip`): the 烈怒 gauge, the bottom bar graphics and the sounds come from it (`sdoj_dfk.py`).
- For testing: MAME 0.289 (CV1000 driver). I run it under WSL.

## Steps
1. Edit `src/patch.s`. This is the SH-3 big-endian source for all patch code and variables.
2. Raise `tools/BUILD` by 1 for every build you hand out.
3. `python3 tools/build.py`
   - Assembles `src/patch.s` for RAM 0x0CE00000 (with `--defsym BUILDNO=<tools/BUILD>`).
   - Generates the boot loader and writes `sdoj_patch_data.py`, which contains only the changed u4 bytes.
   - Fails with "patch too large" if the code and variables go over 0xF000 bytes.
   - The "overflow in branch ... converted into longer instruction sequence" warnings are harmless. "pcrel too far" is an error: move the constant into a nearer pool.
4. `python3 tools/make_web.py roms/ddpsdoj.zip roms/435A07E7.zip path/to/dfkbl.zip`
   - Regenerates `index.html` (the browser patcher).
   - Updates the CRCs and the build number in the title of `mister/DoDonPachi SaiDaiOuJou Platinum Label.mra`. The date in the .mra title is set by hand.
5. Optional, for a local test set:
   `python3 sdoj_patch.py roms/ddpsdoj.zip --god roms/435A07E7.zip --dfk path/to/dfkbl.zip --zip`
   This writes `ddpsdojplat.zip` (files `plat_*`). For MAME, rename the files without the `plat_` prefix into a `ddpsdoj.zip` in a separate rom path.
6. Update `README.md` (player-facing notes) and this folder after each build.
7. Keep a fall-back before risky changes: zip `src/`, `tools/` and the generated files into `.ignore/fallback_bNNN_src.zip`. The current fall-back is build 264 (u4 CRC 545a55d7).

Do not commit or push from the working folder; the user handles git.

## How the patch is put in place
- A small boot loader in free u4 space (ROM 0x3E0000) copies the blob (ROM 0x3E1000, at most 0xF000 bytes) to work RAM 0x0CE00000. It then jumps to the game's main entry 0x0C1E40D0 (boot literal 0x1D8).
- Hooks are **literal redirections**. `HOOKS` in `tools/build.py` lists, for each hook symbol, the literal-pool addresses in the unpacked program that get our address. `ORIG` holds the original targets, so a hook can jump on to the game's own code.
- Graphics are stored in u4: the health bar atlas at `BAR_GFX_OFFSET` (sdoj_god.py) and the DFK graphics and sounds at `DFK_GFX_OFFSET` (sdoj_dfk.py).
- RAM caches outside the blob: the DFK fill blocks are at 0x0CE10000 (16 KB) and the 烈怒 label frames are at 0x0CE14000.

## SH-3 rules that bit us
- `mov #imm` is a **signed 8-bit** value. Load anything above 127 (screen x, 0x8000, ...) with `mov.w`/`mov.l` from a pool. `mov.w` sign-extends, so follow it with `extu.w` for values of 0x8000 and up.
- PC-relative loads only reach **forward**: `mov.w` about 510 bytes and `mov.l` about 1020 bytes. Put each pool after the code that uses it.
- Delay slots: the instruction after `bsr`/`jsr`/`bra`/`rts` runs before the jump. Never put a two-instruction set-up there.
- SH-2A-only opcodes and misaligned `mov.l` assemble fine and even run in MAME, but **freeze the real board**. Test on MiSTer.
- Sprites drawn from HUD hooks are flushed after hud_hook, so upload graphics every frame.

## Game addresses used (RAM)
| What | Address |
|---|---|
| Player 1 struct | 0x0C5F9970. +6 bombs (byte); +0xB0/+0xB4 x/y (16.16); +0x1FC HIT; +0x2E0 hyper running; +0x2E4 hyper stock; +0x350 MAXIMUM shown; +0x360 MAXIMUM count |
| Frame counter | 0x0C5F7D60 |
| In play (bar shown) | 0x0C5F7E8C |
| Stage | 0x0C31DFDC |
| Bullet manager | *0x0C4C8978 + 0x30DFC; +20 first bullet. Per bullet: +0 state (2 = live), +4 next, +0x2C/+0x30 x/y, +0x20 sprite id |
| Enemies | 0x0C661BC0 + k*0x21FC (slots 4-67; 0-3 boss); work pointer at +0x21CC, work +4/+8 x/y |
| Bullet spawn | 0x0C1FE4B0 (r4 type, r5/r6 x/y 16.16, r7 speed, stack angle 0-0x1FF) |
| Draw sprite | 0x0C1E4990 (r4 id, r5 x<<16, r6 y<<16, r7 priority; 0xFF = over the HUD) |
| Sprite table | 0x0C33DF00 + id*10 (texture handle, x, y, w, h); textures at 0x0C1D2E20 + handle*4 |
| Draw text | ORIG_DS (r4 x, r5 y, r6 0xF0, r7 string); colour via 0x0C1DD4B4 (no alpha) |
| VRAM upload header | 0x0C1D17C0; draw list pointer 0x0C1D1460 |
| Free VRAM | x 7552-7647, y 128-487 (health bars 7568, 烈怒 frame 7600, fill slices 7616/7632, label 7632,330) |

## Modes
`v_mode` +4: 0 Original Arcade, 1 = 1.5+, 2 = Power Mode, 3 = Omake. Every feature checks the mode first. 1.5+ is the original game plus only the additions the user listed.

## Main routines in src/patch.s
- `gauge_draw` / `ga_slice` / `ga_fill`: the 烈怒 gauge (static fill plus a quarter-opacity copy scrolling right). It follows INSERT COIN's height and hides 30 frames after the last message (score tally). The look is approved; don't change it unasked.
- `stream_frame`: the aimed bullet streams every ST_RATE (10) frames. Power: from 50% on the gauge (sf_60). Omake: only while a hyper is running.
- `shot_common` / `sc_gone`: a shot removed while on screen adds 1 to HIT (Power and Omake).
- `p2_bombs` / `bicon_hook`: the Power bottom bar (NORMAL/BOOST, bomb icons 0x113B0+).
- `gpm_hook`: the bomb multiplier on kill score. `gp_hook`: the GP bonus.
- `wdx_hook` and the spawn hooks (`wsd`, `wobj`, `pk*`): every dress reads as Expert in Power. Don't reintroduce per-mode dress reads at spawn, because they caused a first-spawn side-ship bug on the board.

## Testing in MAME
- Use a separate rom path holding the patched `ddpsdoj.zip`, and a Lua harness that feeds inputs from a schedule, pokes or holds memory, and takes a snapshot at a given frame.
- To force a state, poke from a frame on. Examples: the gauge `dk_gauge` (look up its address with `nm` on the built ELF), or hyper running at 0x0C5F9C50.
- Check a change on MiSTer before calling it done; MAME misses board-only freezes and first-spawn bugs.
