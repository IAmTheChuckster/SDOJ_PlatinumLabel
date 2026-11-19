# SDOJ Platinum Label: notes for Claude

A patch for DoDonPachi SaiDaiOuJou (Cave CV1000, SH-3) with the modes Original Arcade, 1.5+, Power Mode and Omake. Build steps, game addresses, routines and SH-3 pitfalls are in **dev_notes/BUILDING.md**; read it before changing code. Player-facing notes are in README.md.

## Standing rules from the user
- **Just do requested changes**; don't ask for confirmation first. Never delete code unless asked.
- **Every build you hand out:** raise `tools/BUILD` by 1, run `tools/build.py` and `tools/make_web.py`, and update **README.md** and **dev_notes/BUILDING.md** so they match the build.
- **Dates:** when the .mra date (`mister/*.mra` title, `YYYY/MM/DD Bnnn`) changes, change the boot screen (`t_date` "YYYY.MM.DD") and the warning screen line ("   YYYY/MM/DD PLATINUM LABEL  ") in src/patch.s to match.
- **Git:** never commit or push unless the user asks. When asked, commit to main and push, without `.claude/`, `.ignore/`, ROMs or anything taken from the game files.
- **No build folders:** the user patches with `index.html`. Fall-back sources go in `.ignore/fallback_bNNN_src.zip`. The current fall-back is build 264.
- **1.5+ mode** = the original arcade game plus only the additions the user listed. Anything not mentioned stays original.
- **The 烈怒 gauge look is approved:** don't change its fill or label unless asked. Its position follows INSERT COIN.
- **Power Mode weapons:** NORMAL and BOOST are both full Expert with side ships. Every dress read reports Expert. Don't bring back per-mode dress reads at spawn: they broke the side ships on the board's first spawn.
- **Test on real hardware (MiSTer) in mind:** SH-2A-only opcodes and misaligned `mov.l` run in MAME but freeze the board. HUD sprites are flushed after hud_hook, so upload graphics every frame. Verify in MAME 0.289 (WSL) and send the user a screenshot.
- Write short, plain answers. The user tests on MiSTer and reports back.
