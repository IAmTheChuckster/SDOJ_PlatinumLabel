! SDOJ Resurrected - SH-3 patch code for DoDonPachi SaiDaiOuJou (ddpsdoj, CV1000-D)
! Linked at 0x0CE00000 (free work RAM). Copied there at boot by loader.s.
! Big-endian SH-3. All hooks are reached by redirecting literal pointers in the game.

        .section .text
        .global _start
_start:

! ---------------------------------------------------------------- variables
        .org 0x000
v_mode:     .long 0     ! 0 = Arcade, 1 = 1.5+, 2 = SDOJ Resurrection (placeholder)
v_sel:      .long 0     ! title mode: 1 = Arrange, 0 = Original Arcade (default)
v_menu:     .long 0     ! 1 while the mode menu is shown on the title
v_nohyp:    .long 0     ! 1 = this bomb press must not start a hyper (button 4)
v_prevheld: .long 0     ! P1 held bits last title frame (edge detect)
v_grace:    .long 0     ! title frames without credit before the mode falls back to Arcade
v_sx:       .long 0     ! current shot x (16.16)
v_sy:       .long 0     ! current shot y (16.16)
v_inbee:    .long 0     ! 1 while the bee pickup routine runs (1.5+)
v_beeobj:   .long 0     ! bee pickup object (its +0xD8 is the % shown)
v_popup:    .long 0     ! 1 if the bee % popup was shown
v_hcnt:     .long 0     ! laser-hit counter during hyper (every 3rd hit counts)
v_lastdeaths: .long 0   ! player deaths seen last frame (1.5+ bombs)
v_lastbombs: .long 0    ! player bombs seen last frame
v_gpfix:    .long 0     ! GP bonus fixed at hyper start (0 = not set)
v_hudrank:  .long 0     ! real (uncapped) rank, shown on the HUD
v_lastlv:   .long 0     ! HYPER Lv seen last frame (voice)
v_tlast:    .long 0     ! frame counter at the last title frame
v_tstart:   .long 0     ! frame counter when the title started
v_tx:       .long -1    ! x of RESURRECTED on the title (-1 = hidden)
v_ncinit:   .long 0     ! proximity cancel: tables cleared
v_ncframe:  .long 0     ! proximity cancel: frame counter
v_ncprev:   .long 0     ! proximity cancel: bullets cancelled last frame (cascade seeds)
v_nobomb:   .long 0     ! 1 = button 2 pressed: it must never bomb (offset 92)
v_applied:  .long 1     ! mode written into the game (1 = Arrange) (offset 96)
v_tab:      .long 0     ! loader table for mode_apply, set by the loader (offset 100)
v_bwork:    .long 0     ! stage 1 boss work area, set when a pod is hit (offset 104)
v_ptmr0:    .long 0     ! pod 0 health bar: frames left to show (offset 108)
v_ptmr1:    .long 0     ! pod 1 health bar (offset 112)
v_relist:   .long 0     ! 1 = the draw list was already closed: re-close it after the bars (offset 116)
v_eany:     .long 0     ! big enemy bars with a running timer this frame (offset 120)
v_hud:      .long 0     ! draw list: where the HUD starts (offset 124)
v_bstart:   .long 0     ! draw list: where the bars start (offset 128)
v_tany:     .long 0     ! stage 3 ship turret bars with a running timer (offset 132)

        .org 0x100
! ---------------------------------------------------------------- game addresses
        .equ ORIG_TITLE,   0x0C221070
        .equ ORIG_DS,      0x0C1DD4DC   ! draw string (x r4, y r5, colour r6, str r7)
        .equ ORIG_DN,      0x0C1DD990   ! draw number
        .equ ORIG_TRYBOMB, 0x0C212600   ! (obj r4, held r5, pressed r6)
        .equ ORIG_ACTHYP,  0x0C1FA0D0   ! ActivateHyper(p)
        .equ ORIG_GP,      0x0C1F8D40   ! GetGPBonus(p) -> percent
        .equ ORIG_KILL,    0x0C1FA320   ! GaugeEvent(p, amount, type)
        .equ ORIG_BEE,     0x0C22A8F0   ! hidden bee collected (item r4 ...)
        .equ CANCEL,       0x0C1FD040   ! bullet cancel (type, p, big)
        .equ CREDITS,      0x0C1E112C
        .equ P1IN,         0x0C1DCD6C   ! +0 held

! ================================================================ title hook
! r4 = title object. Mode lines on the title: Original Mode (stock game) /
! Arrange Mode (this patch). Up/Down toggles. The choice rewrites the game's literal
! pointers and code patches (the loader table in u4) so Original is fully unpatched.
        .global title_hook
title_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov     r4,r9
        mov.l   l_fc,r2             ! title just entered (the frame counter moved on more than a few
        mov.l   @r2,r2              ! frames since the last title frame): the menu opens on ORIGINAL ARCADE
        mov.l   l_tlast,r3
        mov.l   @r3,r0
        mov.l   r2,@r3
        sub     r0,r2
        mov     #8,r0
        cmp/hi  r0,r2
        bf      1f
        mov.l   l_vars0,r1
        mov     #0,r0
        mov.l   r0,@(4,r1)
1:
        mov.l   l_vars0,r1
        mov     #1,r0
        mov.l   r0,@(0,r1)          ! mode = 1 (hooks run only when patched in)
        mov.l   l_dkb,r2            ! Power Mode bar: NORMAL at the start of every game
        mov     #0,r0
        mov.l   r0,@r2
        mov.l   r0,@(4,r2)          ! and upload the DFK atlas again on the next frame
        mov     #0,r0
        mov.l   r0,@(8,r1)          ! no menu
        mov.l   l_p1in,r2
        mov.l   @r2,r3              ! held
        mov.l   @(16,r1),r5         ! previous held
        mov.l   r3,@(16,r1)
        not     r5,r5
        and     r5,r3               ! newly pressed
        mov.l   l_credits,r2        ! menu only once a coin is in
        mov.l   @r2,r0
        tst     r0,r0
        bf      th_cr
        bra     th_cr2
        mov     #0,r3               ! no credit: ignore Up / Down
th_cr:  mov     #1,r0
        mov.l   r0,@(8,r1)          ! menu shown (hides the rank line)
th_cr2:
        mov     r3,r0
        mov     #3,r6
        tst     #1,r0               ! up: previous line (wraps)
        bt      th_nup
        mov.l   @(4,r1),r2
        add     #-1,r2
        and     r6,r2
        mov.l   r2,@(4,r1)
th_nup: tst     #2,r0               ! down: next line (wraps)
        bt      th_noin
        mov.l   @(4,r1),r2
        add     #1,r2
        and     r6,r2
        mov.l   r2,@(4,r1)          ! sel: 0 Original, 1 Arrange, 2 Power, 3 Omake
th_noin:
        tst     #3,r0               ! Up / Down onto POWER MODE: dfkbl's coin chime (phrase 249)
        bt      th_nse
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      th_nse
        mov     #5,r4
        mov     #124,r5
        add     #125,r5
        mov     #104,r6
        mov     #-4,r7
        mov.l   l_thse,r0
        jsr     @r0
        extu.b  r7,r7
        mov.l   l_vars0,r1
th_nse:
        mov.l   @(4,r1),r11         ! selected line
        mov     r11,r0
        mov     #0,r8               ! 0 = Original Arcade: nothing patched
        tst     r0,r0
        bt      1f
        mov     #1,r8               ! 1 = Power / Omake: every hook
        cmp/eq  #1,r0
        bf      1f
        mov     #2,r8               ! 2 = 1.5+: original game + its own hooks only (m15_wl)
1:
        add     #96,r1
        mov.l   @r1,r2              ! applied mode
        cmp/eq  r8,r2
        bt      th_ok
        mov.l   r8,@r1
        mov.l   l_apply,r0
        jsr     @r0
        mov     r8,r4
th_ok:
        mov.l   l_hudarc,r0         ! HUD rank back to 2 digits (Omake sets 3 in game)
        jsr     @r0
        nop
        mov.l   l_hitstd,r4         ! HIT limit / Hit Bonus for the selected mode
        mov     r11,r0
        cmp/eq  #3,r0
        bf      th_hit
        mov.l   l_hitom,r4
th_hit: mov.l   l_hudset,r0
        jsr     @r0
        nop
        mov     r9,r4
        mov.l   l_orig_title,r0
        jsr     @r0
        nop
        mov.l   l_drawmode,r0
        jsr     @r0
        mov     #1,r4
        mov.l   l_vars0,r1
        mov.l   @(8,r1),r0
        tst     r0,r0
        bt      th_end              ! no credit: plain title (INSERT COIN, rank line)
        mov     #0,r10              ! line index
th_lp:  mov.l   l_setcol,r0         ! white, gold when selected
        mov.l   l_white,r4
        cmp/eq  r10,r11
        bf      th_c
        mov.l   l_gold,r4
th_c:   jsr     @r0
        nop
        mov     r10,r0              ! string: mstab[line*2 + selected]
        shll2   r0
        shll    r0
        cmp/eq  r10,r11
        bf      th_s
        add     #4,r0
th_s:   mov.l   l_mstab,r1
        mov.l   @(r0,r1),r7
        mov     r10,r5              ! y = first + 12 * line
        shll2   r5
        mov     r5,r1
        add     r1,r5
        add     r1,r5
        mov.w   w_my1,r1
        add     r1,r5
        bsr     th_line
        mov     #60,r4
        add     #1,r10
        mov     r10,r0
        cmp/eq  #4,r0
        bf      th_lp
        mov.l   l_setcol,r0
        mov.l   l_white,r4
        jsr     @r0
        nop
th_end:
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
th_line:                            ! draw string r7 at (r4, r5)
        mov     #0x78,r6
        add     r6,r6               ! r6 = 0xF0
        mov.l   l_orig_ds,r0
        jmp     @r0
        nop

! r4 = 1 write the patched values, 0 write the original values (loader table)
        .global mode_apply
mode_apply:
        mov.l   l_vars0,r1
        add     #100,r1
        mov.l   @r1,r1              ! table (skips the title hooks)
ma_l:   mov.l   @r1+,r2             ! address (0 = end)
        tst     r2,r2
        bt      ma_e
        mov.l   @r1+,r3             ! original
        mov.l   @r1+,r5             ! patched
        mov     r4,r0               ! r0 = 1: write the patched value
        cmp/eq  #2,r0
        bf      ma_w
        mov.l   l_m15wl,r7          ! 1.5+: only the addresses in m15_wl
        mov     #0,r0
1:      mov.l   @r7+,r6
        tst     r6,r6
        bt      ma_w
        cmp/eq  r6,r2
        bf      1b
        mov     #1,r0
ma_w:   mov.l   @r2,r6              ! current
        tst     r0,r0
        bt      ma_o
        cmp/eq  r3,r6
        bf      ma_l
        bra     ma_l
        mov.l   r5,@r2
ma_o:   cmp/eq  r5,r6
        bf      ma_l
        bra     ma_l
        mov.l   r3,@r2
ma_e:   rts
        nop
        .align 2
l_m15wl: .long m15_wl
! 1.5+ = the original game plus: enemy health bars (draw pass hook), Omake's hyper GP table
! (GP hook) and the hyper meter x2 outside hyper (gauge event hook; not the bee pickup's call)
m15_wl: .long 0x0C1DCCEC                                    ! hud_hook (bars)
        .long 0x0C1F6E70, 0x0C27AFFC, 0x0C27C730, 0x0C27D1B8  ! gp_hook
        .long 0x0C1F6C04, 0x0C20B3E4, 0x0C20B434, 0x0C21AC0C  ! kill_hook (gauge events)
        .long 0x0C28FEE0, 0x0C291264                        ! no miss bonus 50 million x level
        .long 0

! ================================================================ HUD MAX
! The number drawer 0x0C27E880 packs digits 2 px tighter above its threshold
! (100,000,000). For the HUD MAX use 99,999, so 6-7 digits stay evenly spaced
! in the old 5-digit space. The threshold is restored after the call.
        .global maxnum_hook
maxnum_hook:
        sts.l   pr,@-r15
        mov.l   @(16,r15),r0        ! copy the 4 stack arguments
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   l_mthr,r1
        mov.l   l_m5,r0
        mov.l   r0,@r1
        mov.l   l_maxorig,r0
        jsr     @r0
        nop
        mov.l   l_mthr,r1
        mov.l   l_m8,r2
        mov.l   r2,@r1
        add     #16,r15
        lds.l   @r15+,pr
        rts
        nop
        .align 2
l_mthr:    .long 0x0C27E990
l_m5:      .long 99999
l_m8:      .long 100000000
l_maxorig: .long 0x0C27E880

! Stage-clear Hit Bonus: the tally pays 'hits x HITBONUS_MULT'. Without a cap that
! passes 4,294,967,295 (the most the 32-bit counters and the unsigned digit
! drawer can hold) around 429,496 hits. Wrap the hit getter used by the tally
! and clamp the count so the bonus stays at or under that limit.
        .global tally_hook
tally_hook:
        sts.l   pr,@-r15
        mov.l   l_tgo,r1
        jsr     @r1
        nop
        mov.l   l_tcap,r1
        cmp/hi  r1,r0
        bf      1f
        mov     r1,r0
1:      lds.l   @r15+,pr
        rts
        nop
        .align 2
l_tgo:      .long 0x0C1F8C60
l_tcap:     .long 429496

! ================================================================ big HIT counter
! Digit positions (x, y) for the big HIT number: the game's 5 slots, 21 px apart,
! extended to 8 so 6-7 digit counts keep the same even spacing.
        .align 2
        .global hit_slots
hit_slots:
        .long -92,108, -71,108, -50,108, -29,108, -8,108, 13,108, 34,108, 55,108

! ================================================================ draw string hook
! Replace the rank line and the two extend lines with the mode menu.
        .global ds_hook
ds_hook:                            ! hides the "1ST / 2ND" score-extend lines on the title
        mov.l   l_vars0,r0              ! while the menu is shown (they overlap the mode lines);
        mov.l   @(8,r0),r0              ! with no credit they show as in the original game
        tst     r0,r0
        bt      ds_rk
        mov.l   l_ext_lo,r0
        cmp/hs  r0,r7
        bf      ds_rk
        mov.l   l_ext_hi,r0
        cmp/hs  r0,r7
        bt      ds_rk
        rts
        nop
ds_rk:  mov.l   l_vars0,r0              ! rank line (y 0xB6..0xBA): hidden while the menu is shown
        mov.l   @(8,r0),r0
        tst     r0,r0
        bt      ds_go
        mov.w   w_yb6,r0
        cmp/ge  r0,r5
        bf      ds_go
        mov.w   w_yba,r0
        cmp/gt  r0,r5
        bt      ds_go
        rts
        nop
ds_go:
        mov.l   l_orig_ds,r0
        jmp     @r0
        nop

! ================================================================ draw number hook
! Hide the rank digit while the menu is shown (rank line is drawn at y 0xB7..0xB9).
        .global dn_hook
dn_hook:                            ! rank digit: hidden with the rank line
        mov.l   l_vars0,r0
        mov.l   @(8,r0),r0
        tst     r0,r0
        bt      dn_go
        mov.w   w_yb6,r0
        cmp/ge  r0,r5
        bf      dn_go
        mov.w   w_yba,r0
        cmp/gt  r0,r5
        bt      dn_go
        rts
        nop
dn_go:
        mov.l   l_orig_dn,r0
        jmp     @r0
        nop

        .align 1
w_my1:  .word 177         ! first mode line (4 lines, 12 px apart, last at 213)
w_yb6:  .word 0xB6
w_yba:  .word 0xBA
        .align 2
l_vars0:      .long v_mode
l_credits:    .long CREDITS
l_p1in:       .long P1IN
l_orig_title: .long ORIG_TITLE
l_setcol:     .long 0x0C1DD4B4
l_white:      .long 0x00808080
l_gold:       .long 0x00806020
l_drawmode:   .long 0x0C1EBCC0
l_apply:      .long mode_apply
l_dkb:        .long dk_boost
l_mstab:      .long mstab
l_thse:       .long 0x0C284A20   ! game: play a sound
l_fc:         .long 0x0C5F7D60   ! game: frame counter
l_tlast:      .long v_tlast
l_hitstd:     .long hit_tab_std
l_hitom:      .long hit_tab_om
l_hudset:     .long hud_set
l_hudarc:     .long hud_arcade
l_ext_lo:     .long 0x0C315F00
l_ext_hi:     .long 0x0C315FC0
l_orig_ds:    .long ORIG_DS
l_orig_dn:    .long ORIG_DN

! ================================================================ TryBomb hook
! obj r4, held r5, pressed r6. Also the per-frame place for 1.5+ bomb max.
        .global trybomb_hook
trybomb_hook:
        mov.l   l2_vars0,r1
        mov     #0,r0
        mov.l   r0,@(12,r1)         ! nohyp = 0
        mov     r1,r2
        add     #64,r2
        add     #28,r2
        mov.l   r0,@r2             ! nobomb = 0
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      tb_go
        ! --- 1.5+: max bombs 6 for every dress type
        mov.l   r5,@-r15            ! keep the held-input argument
        mov     r4,r2
        add     #0x70,r2
        mov.l   @r2,r2              ! player
        tst     r2,r2
        bt      tb_btn
        ! --- 1.5+: "HYPER SYSTEM READY" voice when HYPER Lv goes up
        mov.l   r2,@-r15
        mov.l   r4,@-r15
        mov.l   r6,@-r15
        sts.l   pr,@-r15
        mov.l   l2_hyplvframe,r0
        jsr     @r0
        mov     r2,r4
        lds.l   @r15+,pr
        mov.l   @r15+,r6
        mov.l   @r15+,r4
        mov.l   @r15+,r2
        mov.l   l2_vars0,r1
        ! --- 1.5+: always play as Expert (+0x10 = 2); the dress look (+0x14 ...) is kept. Power Mode, NORMAL:
        ! the Shot dress (0, its thin laser) while the laser button is held, else the Laser dress (1, its weak shot)
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        mov     #2,r0
        bra     tb_dr               ! Power too: the player's dress stays Expert (see wdr_hook)
        nop
        mov.l   tb_boost,r3
        mov.l   @r3,r3
        tst     r3,r3
        bf      tb_dr
        mov.l   tb_in,r3
        mov.l   @r3,r3
        mov     #0x10,r0
        tst     r0,r3
        mov     #0,r0
        bf      tb_dr
        mov     #1,r0
tb_dr:  mov.l   r0,@(16,r2)
        ! --- 1.5+ bombs: always 6 slots, start with 3, each death gives +1 bomb
        mov.w   w_3bb,r0
        mov.b   @(r0,r2),r3         ! deaths
        extu.b  r3,r3
        mov.l   @(48,r1),r0         ! deaths last frame
        cmp/hi  r0,r3
        bf      tb_nodeath
        mov.l   @(52,r1),r0         ! bombs before the death
        add     #1,r0
        bra     tb_setb
        nop
tb_nodeath:
        mov.b   @(7,r2),r0          ! max bombs
        cmp/eq  #6,r0
        bt      tb_keep
        mov     #3,r0               ! new game / continue: 3 bombs
tb_setb:
        mov     #6,r5
        cmp/gt  r5,r0
        bf      tb_set2
        mov     #6,r0
tb_set2:
        mov.b   r0,@(6,r2)
        mov     #6,r0
        mov.b   r0,@(7,r2)
tb_keep:
        mov.l   r3,@(48,r1)
        mov.b   @(6,r2),r0
        extu.b  r0,r0
        mov.l   r0,@(52,r1)
tb_btn:
        mov.l   @r15+,r5
        mov.l   @(4,r1),r0          ! Power Mode: button 4 switches NORMAL / BOOST (dfk_draw), no bomb
        cmp/eq  #2,r0
        bf      1f
        mov     r6,r0
        tst     #0x80,r0
        bt      1f
        xor     #0x80,r0
        mov     r0,r6
1:      ! --- 1.5+: button 4 (0x80) = bomb only
        mov     r6,r0
        tst     #0x80,r0
        bt      tb_b2
        or      #0x20,r0
        mov     r0,r6
        mov     #1,r0
        mov.l   r0,@(12,r1)         ! nohyp = 1
tb_go:
        mov.l   l2_orig_trybomb,r0
        jmp     @r0
        nop
        ! --- 1.5+: button 2 (0x20) = hyper only
tb_b2:
        tst     #0x20,r0
        bt      tb_go
        mov     r4,r2
        add     #0x70,r2
        mov.l   @r2,r2              ! player
        tst     r2,r2
        bt      tb_go
        mov.w   w_tb2e0,r0
        mov.l   @(r0,r2),r3         ! in hyper?
        tst     r3,r3
        bt      tb_nohy
        mov.l   l2_vars0,r3         ! Omake: button 2 in hyper does nothing (hyper keeps going)
        mov.l   @(4,r3),r0
        cmp/eq  #3,r0
        bt      tb_drop
        ! in hyper: end it, cancel the bullets into small stars, no bomb
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        sts.l   pr,@-r15
        mov.l   r2,@-r15
        mov.l   l_tb_end,r0
        jsr     @r0                 ! EndHyper(player): HYPER Lv back to 0
        mov     r2,r4
        mov.l   @r15,r5             ! player
        mov     #32,r4
        mov     #0,r6               ! flag 0 = small stars
        mov.l   l_tb_cancel,r0
        jsr     @r0
        nop
        mov.l   @r15+,r2
        lds.l   @r15+,pr
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        bra     tb_drop
        nop
tb_nohy:
        mov.w   w_tb2e4,r0
        mov.l   @(r0,r2),r3         ! hyper stocks
        tst     r3,r3
        bt      tb_drop             ! no hyper ready: the press does nothing
        mov.l   l2_vars0,r1         ! hyper ready: start it, but never bomb
        add     #64,r1
        add     #28,r1
        mov     #1,r0
        mov.l   r0,@r1             ! nobomb = 1
        bra     tb_go
        nop
tb_drop:
        mov     r6,r0
        and     #0xDF,r0            ! ignore button 2 this frame
        mov     r0,r6
        bra     tb_go
        nop
        .align 2
w_tb2e0:    .word 0x2E0
w_tb2e4:    .word 0x2E4
l_tb_end:    .long 0x0C1FA250
l_tb_cancel: .long CANCEL

! TryBomb's bomb check (0x0C1F7ED0): refused while button 2 is the trigger
        .global bombgate_hook
bombgate_hook:
        mov.l   l_bg_vars,r1
        add     #64,r1
        add     #28,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      bg_orig
        rts
        mov     #0,r0
bg_orig:
        mov.l   l_bg_orig,r0
        jmp     @r0
        nop
        .align 2
l_bg_vars: .long v_mode
l_bg_orig: .long 0x0C1F7ED0

! ================================================================ ActivateHyper hook
        .global acthyp_hook
acthyp_hook:
        mov.l   l2_vars0,r1
        mov.l   @(12,r1),r0
        tst     r0,r0
        bt      ah_go
        rts
        mov     #0,r0
ah_go:
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bt      ah_15
        mov.l   l2_orig_acthyp,r0
        jmp     @r0
        nop
ah_15:                              ! rank limit 50 as the original (999 in Omake)
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r4,r8
        mov.w   w_2e4b,r0
        mov.l   @(r0,r8),r9         ! stocks before
        mov.w   w_2f0,r0
        mov.l   @(r0,r8),r10        ! rank before
        mov.l   l2_orig_acthyp,r0
        jsr     @r0
        nop
        tst     r0,r0
        bt      ah_ret
        mov     r0,r1
        mov     #11,r2
        cmp/hi  r2,r9
        bf      ah_idx
        mov     #11,r9
ah_idx: shll2   r9
        mov.l   l2_rankadd,r2
        add     r9,r2
        mov.l   @r2,r2
        add     r2,r10
        mov.l   l2_vars0,r2         ! rank limit: 999 in Omake, 50 otherwise
        mov.l   @(4,r2),r2
        mov     #3,r3
        cmp/eq  r3,r2
        mov.w   w_50,r2
        bf      ah_cap
        mov.w   w_999,r2
ah_cap: cmp/gt  r2,r10
        bf      ah_set
        mov     r2,r10
ah_set: mov.w   w_2f0,r0
        mov.l   r10,@(r0,r8)
        mov     r1,r0
ah_ret: mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! ================================================================ GP bonus hook
! 1.5+: hyper GP bonus by hyper level: L1 2.0, L2 2.2, L3 2.4, L4 2.6, L5 2.8, L6-10 3.0,
! set when the hyper starts and kept until it ends.
        .global gp_hook
gp_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov     r4,r8
        mov.l   l2_orig_gp,r0
        jsr     @r0
        nop
        mov.l   l2_vars0,r1
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      gp_ret
        mov     #100,r3
        cmp/eq  r3,r0
        bf      gp_boost
        mov     #0,r2
        bra     gp_ret              ! not boosted -> 1.0, clear the fixed value
        mov.l   r2,@(56,r1)
gp_boost:
        mov.l   @(4,r1),r2          ! Power Mode: by the 烈怒 gauge, live - +0.2 per 10% (0-10% 2.0, 10-20% 2.2 ...),
        mov     #2,r3               ! at most 3.0 (from 50%)
        cmp/eq  r3,r2
        bf      gp_fix
        mov.l   l2_gauge,r2
        mov.l   @r2,r2              ! 0-32768
        mov.w   w_3277,r3           ! 10%
        mov     #0,r0
1:      cmp/hs  r3,r2
        bf      2f
        sub     r3,r2
        bra     1b
        add     #1,r0
2:      mov     #5,r3
        cmp/gt  r3,r0
        bf      3f
        mov     r3,r0
3:      mov     #20,r3
        mulu.w  r3,r0
        sts     macl,r0
        mov.w   w_200,r3
        bra     gp_ret
        add     r3,r0
gp_fix:
        mov.l   @(56,r1),r2         ! already fixed for this hyper?
        tst     r2,r2
        bt      gp_calc
        bra     gp_ret
        mov     r2,r0
gp_calc:
        mov.w   w_2ec,r1
        add     r8,r1
        mov.l   @r1,r2              ! stocks spent at hyper start
        add     #-4,r1
        mov.l   @r1,r3              ! +0x2E8: HYPER Lv gained during the hyper (HUD)
        add     r3,r2               ! hyper level = start level + level-ups
        tst     r2,r2
        bt      gp_store
        mov     #5,r3
        cmp/gt  r3,r2
        bt      gp_max
        mov     #20,r3
        mulu.w  r3,r2
        sts     macl,r0
        mov.w   w_180,r3
        bra     gp_store
        add     r3,r0
gp_max:
        mov.w   w_300,r0
gp_store:
        mov.l   l2_vars0,r1
        mov.l   r0,@(56,r1)         ! GP stays at this value until the hyper ends
gp_ret:
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

        .align 1
w_2ec:  .word 0x2EC
w_2e4b: .word 0x2E4
w_2f0:  .word 0x2F0
w_999:  .word 999     ! rank limit in Omake
w_50:   .word 50      ! rank limit (the original game's)
w_3bb:  .word 0x3BB
w_180:  .word 180
w_300:  .word 300
w_200:  .word 200
w_3277: .word 3277    ! 10% of the 烈怒 gauge (32768)
        .align 2
l2_vars0:        .long v_mode
l2_gauge:        .long dk_gauge
tb_boost:        .long dk_boost
tb_in:           .long 0x0C1DCD6C   ! P1 held buttons
l2_orig_trybomb: .long ORIG_TRYBOMB
l2_orig_acthyp:  .long ORIG_ACTHYP
l2_orig_gp:      .long ORIG_GP
l2_rankadd:      .long 0x0C3387F0   ! rank added per hyper level
l2_hyplvframe:   .long hyplv_frame

! ================================================================ gauge event hook
! p r4, amount r5, type r6.  Gauge fills at twice the original rate outside hyper; during hyper nothing
! fills it (only bees raise HYPER Lv).
! During a bee pickup in 1.5+ the bee's own combo-based gauge gain is skipped.
        .global kill_hook
kill_hook:
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      kh_orig
        mov.l   @(4,r1),r0          ! 1.5+: in hyper as the original, outside hyper x2
        cmp/eq  #1,r0
        bf      kh_arr
        mov.w   w3_2e0,r0
        mov.l   @(r0,r4),r0
        tst     r0,r0
        bf      kh_orig
        bra     kh_x2
        nop
kh_arr:
        mov.l   @(32,r1),r0         ! inside bee pickup?
        tst     r0,r0
        bt      kh_nobee
        rts
        mov     #0,r0
kh_nobee:
        mov.w   w3_2e0,r0
        mov.l   @(r0,r4),r0         ! hyper active?
        tst     r0,r0
        bf      kh_inhyper          ! in hyper
        bra     kh_x2               ! patched modes, not in hyper: twice the original gain
        nop
kh_orig:                            ! Original Arcade: the game's own routine, untouched
        mov.l   l3_orig_kill,r0
        jmp     @r0
        nop
kh_inhyper:                         ! 1.5+ in hyper: kills and laser hits add nothing
        rts                         ! (only bees raise HYPER Lv)
        mov     #0,r0
kh_x2:                              ! the game's gauge event twice: every gain (and every "each
        sts.l   pr,@-r15            ! Nth laser hit" countdown) counts double
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov     r4,r8
        mov     r5,r9
        mov     r6,r10
        mov.l   l3_orig_kill,r0
        jsr     @r0
        nop
        mov     r0,r11
        mov     r8,r4
        mov     r9,r5
        mov.l   l3_orig_kill,r0
        jsr     @r0
        mov     r10,r6
        mov     r11,r0
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
kh_hyper:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov     r4,r8
        mov     r5,r9
        mov     r6,r10
        mov.l   l3_orig_kill,r0
        jsr     @r0                 ! the game's own in-hyper handling
        nop
        mov     r0,r11
        ! amount Arcade would give outside hyper (x1)
        mov     r10,r0
        cmp/eq  #3,r0
        bf      kh_t0
        mov.l   l3_vars0,r1         ! laser hits: +amount every 3rd hit
        mov.l   @(44,r1),r0
        add     #1,r0
        mov     #3,r2
        cmp/ge  r2,r0
        bt      kh_t3
        bra     kh_done
        mov.l   r0,@(44,r1)
kh_t3:  mov     #0,r0
        mov.l   r0,@(44,r1)
        bra     kh_add
        mov     r9,r2
kh_t0:  tst     r0,r0
        bf      kh_other
        mov.w   w3_3bc,r0           ! kills: A[deaths] + B[stock]
        mov.l   @(r0,r8),r0
        mov     #4,r3
        cmp/hi  r3,r0
        bf      kh_a
        mov     #4,r0
kh_a:   shll2   r0
        mov.l   l3_tblA,r3
        mov.l   @(r0,r3),r2
        mov.w   w3_2e4,r0
        mov.l   @(r0,r8),r0
        mov     #10,r3
        cmp/hi  r3,r0
        bf      kh_b
        mov     #10,r0
kh_b:   shll2   r0
        mov.l   l3_tblB,r3
        mov.l   @(r0,r3),r3
        bra     kh_add
        add     r3,r2
kh_other:
        mov     r9,r2
kh_add:
        mov     r8,r4               ! 0x0C1FA490: in-hyper meter, full bar -> HYPER Lv +1
        mov.l   l3_hyplv,r0
        jsr     @r0
        mov     r2,r5
kh_done:
        mov     r11,r0
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! ================================================================ hidden bee hook
! 1.5+: every bee shows 100%, gives exactly one hyper stock - or HYPER Lv +1 during a
! hyper - (no combo-based gauge)
! and cancels bullets into big stars.
        .global bee_hook
bee_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   @(8,r4),r8          ! player
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      bee_arc
        mov     #1,r0
        mov.l   r0,@(32,r1)         ! inbee = 1
        mov.l   r6,@(36,r1)         ! bee object
        mov     #0,r0
        mov.l   r0,@(40,r1)         ! popup = 0
bee_arc:
        mov.l   l3_orig_bee,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      bee_ret
        mov     #0,r0
        mov.l   r0,@(32,r1)         ! inbee = 0
        tst     r8,r8
        bt      bee_ret
        ! show "100%" if the game skipped the popup (combo too low)
        mov.l   @(40,r1),r0
        tst     r0,r0
        bf      bee_stock
        mov.l   @(36,r1),r2
        mov.w   w3_d8,r0
        mov     #100,r3
        mov.l   r3,@(r0,r2)
        mov     r8,r4
        mov.l   l3_popup,r0
        jsr     @r0
        mov     #1,r5
bee_stock:
        mov.w   w3_2e0,r0
        mov.l   @(r0,r8),r0         ! in hyper?
        tst     r0,r0
        bt      bee_addstock
        ! in hyper: HYPER Lv +1 (HUD digit, +0x2E8), max 10
        mov     r8,r1
        mov.w   w3_2e4,r0
        add     r0,r1
        mov.l   @(4,r1),r2          ! +0x2E8
        mov     #10,r3
        cmp/ge  r3,r2
        bt      bee_cancel
        add     #1,r2
        bra     bee_cancel
        mov.l   r2,@(4,r1)
bee_addstock:
        mov.w   w3_2e4,r0
        mov.l   @(r0,r8),r2         ! hyper stock
        mov     #10,r3
        cmp/ge  r3,r2
        bt      bee_cancel
        add     #1,r2
        mov.l   r2,@(r0,r8)
bee_cancel:
        mov     #32,r4
        mov     r8,r5
        mov.l   l3_cancel,r0
        jsr     @r0
        mov     #1,r6
bee_ret:
        mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! bee "%" popup (0x0C2778E0), reached only from the bee pickup routine:
! in 1.5+ the shown value is always 100.
        .global popup_hook
popup_hook:
        mov.l   l3_vars0,r1
        mov.l   @(32,r1),r0
        tst     r0,r0
        bt      pp_go
        mov     #1,r0
        mov.l   r0,@(40,r1)         ! popup shown
        mov.l   @(36,r1),r2
        mov.w   w3_d8,r0
        mov     #100,r3
        mov.l   r3,@(r0,r2)
pp_go:
        mov.l   l3_popup,r0
        jmp     @r0
        nop

        .align 1
w3_2e0: .word 0x2E0
w3_d8:  .word 0xD8
w3_3bc: .word 0x3BC
w3_2e4: .word 0x2E4
        .align 2
l3_vars0:     .long v_mode
l3_orig_kill: .long ORIG_KILL
l3_orig_bee:  .long ORIG_BEE
l3_hyplv:     .long 0x0C1FA490   ! in-hyper meter / hyper level up
l3_cancel:    .long CANCEL
l3_popup:     .long 0x0C2778E0   ! bee % popup
l3_tblA:      .long 0x0C338848   ! kill gauge by deaths
l3_tblB:      .long 0x0C33881C   ! kill gauge by hyper stock


! ================================================================ shot vs bullet (Omake hyper)
! Each player-shot update routine (4 per ship) is redirected to a stub that runs the
! original update, then - in Omake during hyper - cancels enemy bullets touching the shot.
! The laser uses other routines, so it does not cancel bullets.
        .global shot_stub0
        .align 2
shot_stub0:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2173D0
        .global shot_stub1
        .align 2
shot_stub1:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217680
        .global shot_stub2
        .align 2
shot_stub2:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217A80
        .global shot_stub3
        .align 2
shot_stub3:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217DD0
        .global shot_stub4
        .align 2
shot_stub4:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218160
        .global shot_stub5
        .align 2
shot_stub5:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2183C0
        .global shot_stub6
        .align 2
shot_stub6:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218770
        .global shot_stub7
        .align 2
shot_stub7:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2189F0
        .global shot_stub8
        .align 2
shot_stub8:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218D80
        .global shot_stub9
        .align 2
shot_stub9:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218FE0
        .global shot_stub10
        .align 2
shot_stub10:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2193E0
        .global shot_stub11
        .align 2
shot_stub11:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2196B0

        .align 2
shot_common:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov     r4,r8
        jsr     @r1                 ! original shot update
        nop
        mov     r0,r13
        tst     r0,r0
        bt      sc_gone             ! shot removed this frame
        mov.l   s_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #3,r0
        bt      sc_om               ! Omake
        cmp/eq  #2,r0
        bf      sc_done             ! Power Mode: only in BOOST
        mov.l   s_boost,r2
        mov.l   @r2,r0
        tst     r0,r0
        bt      sc_done
sc_om:
        mov.l   s_player,r2
        mov.w   s_2e0,r0
        mov.l   @(r0,r2),r0
        tst     r0,r0
        bt      sc_done             ! not in hyper
        mov     r8,r2
        add     #0x48,r2
        mov.l   @r2+,r3             ! shot x
        mov.l   r3,@(24,r1)
        mov.l   @r2,r3              ! shot y
        mov.l   r3,@(28,r1)
        mov.l   s_bmgr,r9
        mov.l   @r9,r9
        tst     r9,r9
        bt      sc_done
        mov.l   s_mgroff,r0
        add     r0,r9               ! bullet manager
        mov.l   @(28,r9),r0
        tst     r0,r0
        bt      sc_done
        mov.l   @(20,r9),r10        ! first bullet
sc_loop:
        tst     r10,r10
        bt      sc_done
        mov.l   @r10,r0
        cmp/eq  #2,r0
        bf      sc_next
        mov.l   s_vars,r1
        mov     r10,r2
        add     #0x2C,r2
        mov.l   @r2+,r3             ! bullet x
        mov.l   @(24,r1),r0
        sub     r0,r3
        cmp/pz  r3
        bt      sc_ax
        neg     r3,r3
sc_ax:  mov.l   s_rad,r0
        cmp/gt  r0,r3
        bt      sc_next
        mov.l   @r2,r3              ! bullet y
        mov.l   @(28,r1),r0
        sub     r0,r3
        cmp/pz  r3
        bt      sc_ay
        neg     r3,r3
sc_ay:  mov.l   s_rad,r0
        cmp/gt  r0,r3
        bt      sc_next
        ! cancel just this bullet: make it the only list entry for the game's cancel routine
        mov.l   @(4,r10),r11        ! next
        mov.l   @(20,r9),r12        ! list head
        mov.l   r10,@(20,r9)
        mov     #0,r0
        mov.l   r0,@(4,r10)
        mov.l   s_vars,r1           ! big stars (Omake), small (Power Mode)
        mov.l   @(4,r1),r0
        mov     #0,r4
        cmp/eq  #3,r0
        movt    r4
        mov.l   s_player,r5
        mov.l   s_cancel1,r0
        jsr     @r0
        nop
        mov.l   r11,@(4,r10)
        mov.l   r12,@(20,r9)
        bra     sc_loop
        mov     r11,r10
sc_next:
        bra     sc_loop
        mov.l   @(4,r10),r10
sc_done:
        mov     r13,r0
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
sc_gone:                            ! Power Mode / Omake: a shot removed while still on screen hit something: HIT + 1
        mov.l   s_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #3,r0
        bt      1f
        cmp/eq  #2,r0
        bf      sc_done
1:
        mov     r8,r2
        add     #0x48,r2
        mov.l   @r2+,r3             ! x
        mov.l   s_scrw,r0
        cmp/hs  r0,r3               ! (unsigned: below 0 counts as off screen too)
        bt      sc_done
        mov.l   @r2,r3              ! y
        mov.l   s_scrh,r0
        cmp/hs  r0,r3
        bt      sc_done
        mov.l   s_player,r1
        mov.w   s_1fc,r0
        mov.l   @(r0,r1),r2
        add     #1,r2
        bra     sc_done
        mov.l   r2,@(r0,r1)
        .align 1
s_1fc:  .word 0x1FC
s_2e0:  .word 0x2E0
        .align 2
s_vars:    .long v_mode
s_player:  .long 0x0C5F9970
s_boost:   .long dk_boost
s_bmgr:    .long 0x0C4C8978
s_mgroff:  .long 0x00030DFC
s_rad:     .long 0x000A0000     ! 10 px
s_scrw:    .long 240 << 16
s_scrh:    .long 320 << 16
s_cancel1: .long 0x0C1FE220     ! cancel bullets in the manager list (flag, player)

! ================================================================ bomb item (1.5+)
! 0x0C1F7D50 is called by the bomb item pickup (literal 0x0C22A508): cancel bullets into big stars.
        .global bombitem_hook
bombitem_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov     r4,r8
        mov.l   bi_orig,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   bi_vars,r1
        mov.l   @(4,r1),r0          ! Power Mode: bomb multiplier (first pickup x2, then +1 each, max 99)
        cmp/eq  #2,r0
        bf      1f
        mov.l   bi_earn,r1          ! bombs earned from pickups (max 6)
        mov.l   @r1,r0
        add     #1,r0
        mov     #6,r2
        cmp/gt  r2,r0
        bf      4f
        mov     r2,r0
4:      mov.l   r0,@r1
        mov.l   bi_mult,r1
        mov.l   @r1,r0
        add     #1,r0
        mov     #2,r2
        cmp/ge  r2,r0
        bt      2f
        mov     #2,r0
2:      mov     #99,r2
        cmp/gt  r2,r0
        bf      3f
        mov     r2,r0
3:      mov.l   r0,@r1
1:      mov.l   bi_vars,r1
        mov.l   @r1,r0
        cmp/eq  #1,r0
        bf      bi_ret
        mov     #32,r4
        mov     r8,r5
        mov.l   bi_cancel,r0
        jsr     @r0
        mov     #1,r6
bi_ret: mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
bi_vars:   .long v_mode
bi_orig:   .long 0x0C1F7D50
bi_cancel: .long CANCEL
bi_mult:   .long dk_mult
bi_earn:   .long dk_earn

! Power Mode: the score of every kill (0x0C1F6Dxx, GP through literal 0x0C1F6E70) is also multiplied by the
! bomb multiplier (x2, x3 ... from picked-up bombs; gone when a bomb goes off). The HUD's GP stays the true GP.
        .global gpm_hook
gpm_hook:
        sts.l   pr,@-r15
        mov.l   gm_gp,r0
        jsr     @r0
        nop
        lds.l   @r15+,pr
        mov.l   gm_vars,r1
        mov.l   @(4,r1),r2
        mov     #2,r3
        cmp/eq  r3,r2
        bf      1f
        mov.l   gm_mult,r1
        mov.l   @r1,r2
        cmp/ge  r3,r2
        bf      1f
        mulu.w  r2,r0
        sts     macl,r0
1:      rts
        nop
        .align 2
gm_gp:    .long gp_hook
gm_vars:  .long v_mode
gm_mult:  .long dk_mult

! ================================================================ always Expert (2.0)
! Player init sets +0x10 (dress type: 0 shot, 1 laser, 2 expert) through 0x0C1F7810.
! Forcing it here makes the whole game (stage setup, difficulty tables) see Expert from the start.
        .global dresstype_hook
dresstype_hook:
        mov     #2,r5
        mov.l   dt_orig,r0
        jmp     @r0
        nop
        .align 2
dt_orig: .long 0x0C1F7810

! Auto bomb (player +0x2C, set through 0x0C1F7850 at player init): forced on for every dress.
        .global autobomb_hook
autobomb_hook:
        mov     #1,r5
        mov.l   ab_orig,r0
        jmp     @r0
        nop
        .align 2
ab_orig: .long 0x0C1F7850

! ================================================================ dress select screen (2.0)
! The select screen draws its panels through five JSR literals (all 0x0C1E4990, sprite draw).
! Everything those five call sites draw is the description box (text per dress) and the
! dress-name / AUTO BOMB strip, except 0x13F59 (the character shadow): draw them far
! off screen instead (the weapon icon is drawn elsewhere and stays).
        .global dress_hook
dress_hook:
        sts     pr,r0
        mov.l   dh_p0,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p1,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p2,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p3,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p4,r1
        cmp/eq  r1,r0
        bf      dh_go
dh_hide:
        mov.l   dh_keep,r0
        cmp/eq  r0,r4
        bt      dh_go
        mov.l   dh_far,r5
dh_go:  mov.l   dh_orig,r0
        jmp     @r0
        nop
        .align 2
dh_p0:   .long 0x0C274656
dh_p1:   .long 0x0C274E02
dh_p2:   .long 0x0C274F54
dh_p3:   .long 0x0C2750A8
dh_p4:   .long 0x0C2751DE
dh_keep: .long 0x00013F59
dh_far:  .long 0xE0000000
dh_orig: .long 0x0C1E4990

! ================================================================ 1UP item (1.5+)
! 0x0C1F7470 (add a life) is called by the 1UP item pickup (literal 0x0C22A8CC): cancel bullets into big stars.
        .global life_hook
life_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov     r4,r8
        mov.l   lh_orig,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   lh_vars,r1
        mov.l   @r1,r0
        cmp/eq  #1,r0
        bf      lh_ret
        mov     #32,r4
        mov     r8,r5
        mov.l   lh_cancel,r0
        jsr     @r0
        mov     #1,r6
lh_ret: mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
lh_orig:   .long 0x0C1F7470
lh_vars:   .long v_mode
lh_cancel: .long CANCEL


! ================================================================ proximity cancel
! Every frame (r4 = player): bullets that fly within 24 px of an enemy (any bullet
! emitter) turn into stars: small stars, or big stars while the player is in hyper. Bullets within 16 px
! of a bullet cancelled the frame before cancel too, so it ripples outwards.
! Emitters are the places bullets spawn at; they are remembered for 30 frames. A
! bullet never counts its own birthplace as an enemy, and bullets younger than 7
! frames are left alone.
! Work tables at NC (cleared on the first call):
!   +0x0000  1024 x 16: per bullet {age, spawn x, spawn y, -}   index = (addr >> 4) & 0x3FF
!   +0x4000  32 x 16:   emitters {x, y, last frame, -}
!   +0x4200  64 x 8:    cancelled last frame {x, y}
!   +0x4400  64 x 8:    cancelled this frame {x, y}
        .equ NC,        0x0CE10000
        .equ NC_EMIT,   0x4000
        .equ NC_PREV,   0x4200
        .equ NC_NEW,    0x4400
        .equ NC_SIZE,   0x4600
        .equ R24,       0x00180000
        .equ R16,       0x00100000
        .equ R8,        0x00080000
        .global nc_frame
nc_frame:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   r14,@-r15
        mov     r4,r8                   ! player
        mov.l   nc_c_base,r14
        mov.l   nc_c_vars,r1
        add     #64,r1                  ! r1 = vars + 64 (displacements stay <= 60)
        mov.l   @(16,r1),r0             ! v_ncinit
        tst     r0,r0
        bf      nc_inited
        mov     #1,r0
        mov.l   r0,@(16,r1)
        mov     #100,r0
        mov.l   r0,@(20,r1)             ! frame counter starts at 100 (entry time 0 = empty)
        mov     #0,r0
        mov.l   r0,@(24,r1)
        mov     r14,r2                  ! clear the tables
        mov.w   nc_c_words,r3
nc_clr: mov.l   r0,@r2
        dt      r3
        bf/s    nc_clr
        add     #4,r2
nc_inited:
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   @(20,r1),r13
        add     #1,r13
        mov.l   r13,@(20,r1)            ! r13 = frame
        mov.w   nc_c_2e0,r0
        mov.l   @(r0,r8),r0             ! hyper active?
        tst     r0,r0
        movt    r11
        mov     #1,r1
        xor     r1,r11                  ! r11 = 1 in hyper = big stars, 0 = small stars
        mov     #0,r10                  ! bullets cancelled this frame
        mov.l   nc_c_mgr,r0
        mov.l   @r0,r1
        tst     r1,r1
        bt      nc_fin
        mov.l   nc_c_30dfc,r2
        add     r2,r1
        mov.l   @(28,r1),r0
        tst     r0,r0
        bt      nc_fin
        mov.l   @(20,r1),r9             ! first bullet
nc_loop:
        tst     r9,r9
        bt      nc_fin
        mov     r9,r0                   ! record = NC + ((node >> 4) & 0x3FF) * 16
        shlr2   r0
        shlr2   r0
        mov.w   nc_c_3ff,r1
        and     r1,r0
        shll2   r0
        shll2   r0
        mov     r14,r12
        add     r0,r12
        mov.l   @r9,r0                  ! state
        cmp/eq  #2,r0
        bt      nc_fly
        mov     #0,r0                   ! not flying: forget the bullet
        bra     nc_next
        mov.l   r0,@r12
nc_fly:
        mov.l   @(44,r9),r2             ! x
        mov.l   @(48,r9),r3             ! y
        mov.l   @r12,r0                 ! age
        tst     r0,r0
        bf      nc_old
        mov.l   r2,@(4,r12)             ! born: remember the birthplace
        mov.l   r3,@(8,r12)
        mov     #1,r0
        mov.l   r0,@r12
        bsr     nc_reg                  ! and note the emitter
        nop
        bra     nc_next
        nop
nc_old:
        add     #1,r0
        mov     #100,r1
        cmp/gt  r1,r0
        bf      nc_agok
        mov     r1,r0
nc_agok:
        mov.l   r0,@r12
        mov     #7,r1
        cmp/ge  r1,r0
        bf      nc_next                 ! too young
        mov.l   nc_c_r24,r6
        ! --- enemies (emitters seen in the last 30 frames)
        mov.w   nc_c_emit,r0
        mov     r14,r4
        add     r0,r4
        mov     #32,r7
nc_e1:  mov.l   @(8,r4),r0              ! last frame seen
        tst     r0,r0
        bt      nc_e9
        mov     r13,r1
        sub     r0,r1
        mov     #30,r0
        cmp/hi  r0,r1
        bt      nc_e9                   ! too old
        mov.l   @r4,r0                  ! ex
        mov     r2,r1
        sub     r0,r1
        cmp/pz  r1
        bt      1f
        neg     r1,r1
1:      cmp/ge  r6,r1
        bt      nc_e9
        mov.l   @(4,r4),r5              ! ey
        mov     r3,r1
        sub     r5,r1
        cmp/pz  r1
        bt      2f
        neg     r1,r1
2:      cmp/ge  r6,r1
        bt      nc_e9
        mov.l   @(4,r12),r1             ! was this bullet born at this enemy?
        sub     r0,r1
        cmp/pz  r1
        bt      3f
        neg     r1,r1
3:      cmp/ge  r6,r1
        bt      nc_hit                  ! born elsewhere in x: it is a visitor
        mov.l   @(8,r12),r1
        sub     r5,r1
        cmp/pz  r1
        bt      4f
        neg     r1,r1
4:      cmp/ge  r6,r1
        bt      nc_hit                  ! born elsewhere in y
nc_e9:  dt      r7
        bf/s    nc_e1
        add     #16,r4
        ! --- bullets cancelled last frame (cascade)
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   @(24,r1),r7
        tst     r7,r7
        bt      nc_next
        mov.w   nc_c_prev,r0
        mov     r14,r4
        add     r0,r4
        mov.l   nc_c_r16,r6
nc_p1:  mov.l   @r4,r0
        mov     r2,r1
        sub     r0,r1
        cmp/pz  r1
        bt      5f
        neg     r1,r1
5:      cmp/ge  r6,r1
        bt      nc_p9
        mov.l   @(4,r4),r0
        mov     r3,r1
        sub     r0,r1
        cmp/pz  r1
        bt      6f
        neg     r1,r1
6:      cmp/ge  r6,r1
        bf      nc_hit
nc_p9:  dt      r7
        bf/s    nc_p1
        add     #8,r4
        bra     nc_next
        nop
nc_hit:
        bsr     nc_cancel               ! r9 bullet, r8 player
        nop
        mov     #64,r0
        cmp/ge  r0,r10
        bt      nc_next
        mov.w   nc_c_new,r0             ! remember where it was
        mov     r14,r4
        add     r0,r4
        mov     r10,r0
        shll2   r0
        shll    r0
        add     r0,r4
        mov.l   @(44,r9),r0
        mov.l   r0,@r4
        mov.l   @(48,r9),r0
        mov.l   r0,@(4,r4)
        add     #1,r10
nc_next:
        bra     nc_loop
        mov.l   @(4,r9),r9
nc_fin:                                 ! this frame's cancels become the next frame's seeds
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   r10,@(24,r1)
        mov.w   nc_c_new,r0
        mov     r14,r4
        add     r0,r4
        mov.w   nc_c_prev,r0
        mov     r14,r5
        add     r0,r5
        mov     r10,r7
        tst     r7,r7
        bt      nc_ret
nc_cp:  mov.l   @r4+,r0
        mov.l   r0,@r5
        mov.l   @r4+,r0
        mov.l   r0,@(4,r5)
        dt      r7
        bf/s    nc_cp
        add     #8,r5
nc_ret: mov.l   @r15+,r14
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
nc_c_words: .word NC_SIZE / 4
nc_c_2e0:   .word 0x2E0
nc_c_3ff:   .word 0x3FF
nc_c_emit:  .word NC_EMIT
nc_c_prev:  .word NC_PREV
nc_c_new:   .word NC_NEW
        .align 2
nc_c_base:  .long NC
nc_c_vars:  .long v_mode
nc_c_mgr:   .long 0x0C4C8978
nc_c_30dfc: .long 0x30DFC
nc_c_r24:   .long R24
nc_c_r16:   .long R16

! cancel one flying bullet into small stars - the body of the game's cancel routine
! (0x0C1FE220). r9 = bullet, r8 = player.
nc_cancel:
        sts.l   pr,@-r15
        mov     r9,r7
        add     #124,r7
        mov.l   nc_k_rel,r0
        jsr     @r0
        mov.l   @(48,r7),r4
        mov     r9,r7
        add     #124,r7
        mov     r9,r3
        add     #64,r3
        mov.l   @(36,r9),r2
        mov     #1,r1
        mov     #3,r4
        mov     #0,r5
        mov.l   r5,@(48,r7)
        mov.l   r4,@r9
        mov.l   r2,@(32,r9)
        mov.l   r5,@(24,r9)
        mov.l   r11,@(16,r3)            ! 0 = small stars (not in hyper), 1 = big stars (hyper)
        mov.l   r1,@(8,r3)
        mov.l   r1,@(12,r3)
        mov.l   r8,@(44,r7)
        lds.l   @r15+,pr
        rts
        nop
        .align 2
nc_k_rel:   .long 0x0C1E6A40

! note an emitter at (r2, r3): refresh the one within 8 px, else replace the oldest
nc_reg:
        mov.w   nc_r_emit,r0
        mov     r14,r4
        add     r0,r4
        mov     r4,r5                   ! oldest slot
        mov     #-1,r6
        shlr    r6                      ! oldest time = 0x7FFFFFFF
        mov     #32,r7
        mov.l   nc_r_r8,r1
        mov.l   r1,@-r15
nr_lp:  mov.l   @(8,r4),r0
        cmp/hi  r0,r6
        bf      nr_nold
        mov     r0,r6
        mov     r4,r5
nr_nold:
        tst     r0,r0
        bt      nr_nx                   ! empty slot
        mov.l   @r15,r1
        mov.l   @r4,r0
        sub     r2,r0
        cmp/pz  r0
        bt      1f
        neg     r0,r0
1:      cmp/ge  r1,r0
        bt      nr_nx
        mov.l   @(4,r4),r0
        sub     r3,r0
        cmp/pz  r0
        bt      2f
        neg     r0,r0
2:      cmp/ge  r1,r0
        bt      nr_nx
        mov     r4,r5                   ! same place: refresh this one
        bra     nr_set
        nop
nr_nx:  dt      r7
        bf/s    nr_lp
        add     #16,r4
nr_set: add     #4,r15
        mov.l   r2,@r5
        mov.l   r3,@(4,r5)
        rts
        mov.l   r13,@(8,r5)
        .align 1
nc_r_emit:  .word NC_EMIT
        .align 2
nc_r_r8:    .long R8

! ================================================================ 1.5+ per-frame extras
! r4 = player. Plays the hyper-ready voice when HYPER Lv (+0x2E8) goes up and
! switches the HUD rank to 3 digits.
        .global hyplv_frame
hyplv_frame:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov     r4,r8
        mov.l   x_vars,r1           ! Power Mode: no proximity cancel
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bt      49f
        mov.l   x_ncframe,r0        ! bullets near enemies cancel into stars (not in hyper)
        jsr     @r0
        nop
49:     mov.l   x_vars,r1           ! HUD rank: 3 digits in Omake, else the original 2
        mov.l   @(4,r1),r0
        cmp/eq  #3,r0
        bf      hl_2d
        mov.l   x_hudt3,r4          ! 3 digits, no cap at 99, centred under RANK
        bsr     hud_set
        nop
        bra     hl_hd
        nop
hl_2d:  bsr     hud_arcade
        nop
hl_hd:
        mov.l   x_ptab,r1           ! stage 1 boss: each pod takes its own damage (part table, see pod_hit_0)
        mov.l   @r1,r0
        mov.l   x_ph0o,r2
        cmp/eq  r2,r0
        bf      hl_p1
        mov.l   x_ph0,r2
        mov.l   r2,@r1
hl_p1:  add     #20,r1
        mov.l   @r1,r0
        mov.l   x_ph1o,r2
        cmp/eq  r2,r0
        bf      hl_p2
        mov.l   x_ph1,r2
        mov.l   r2,@r1
hl_p2:
        mov.l   x_upf,r0            ! 1up picked up: cancel bullets into stars
        jsr     @r0
        mov     r8,r4
        mov.w   x_2e8,r0
        mov.l   @(r0,r8),r2         ! HYPER Lv now
        mov.l   x_vars,r1
        add     #64,r1
        mov.l   @r1,r3              ! last frame
        mov.l   r2,@r1
        cmp/gt  r3,r2
        bf      hx_ret
        mov.w   x_2e0,r0
        mov.l   @(r0,r8),r0         ! only during a hyper
        tst     r0,r0
        bt      hx_ret
        mov.l   x_vars,r1           ! Power Mode: only the game's own voice at Lv 1 (ready_hook)
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bt      hx_ret
        mov.l   x_se,r0             ! sound effect
        jsr     @r0
        nop
        mov     #9,r4               ! "HYPER SYSTEM READY" voice
        mov.l   x_voice,r0
        jsr     @r0
        mov     #70,r5
hx_ret: mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop


! Arcade: HUD rank back to the original 2 digits (called from the title hook).
        .global hud_arcade
hud_arcade:
        mov.l   x_hudt2,r4
! r4 = table of (address, value) pairs, 0 = end. Writes only words that differ, so the
! code is not rewritten every frame. MAME's SH recompiler only re-checks the first opcode
! of a compiled block, so each patch changes the opcode at a block start (0x0C27ECC4 /
! 0x0C27ECD6) and that word is written last.
hud_set:
        mov.l   @r4+,r1             ! address
        tst     r1,r1
        bt      hs_e
        mov.l   @r4+,r0             ! value
        mov.l   @r1,r2
        cmp/eq  r0,r2
        bt      hud_set
        bra     hud_set
        mov.l   r0,@r1
hs_e:   rts
        nop

! rank index for the difficulty table stays 0..50; the HUD shows the real rank.
        .global getrank_hook
getrank_hook:
        sts.l   pr,@-r15
        mov.l   x_getrank,r0
        jsr     @r0
        nop
        mov.l   x_vars,r1
        mov.l   r0,@(60,r1)         ! HUD rank
        mov     #50,r2
        cmp/gt  r2,r0
        bf      gr_ret
        mov     r2,r0
gr_ret: lds.l   @r15+,pr
        rts
        nop

! bullet speed (1.5+): rank 51-100 +0.2% per rank (+10% at 100), then +0.1% per rank (+99.9% at 999). Hooks the speed-part call in
! the bullet spawn; the caller's r9 holds base speed + rank bonus at this point.
        .global speed_hook
speed_hook:
        sts.l   pr,@-r15
        mov.l   x_speedfn,r0
        jsr     @r0
        nop
        mov.l   x_vars,r1
        mov.l   @r1,r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      sp_ret
        mov.l   @(60,r1),r2         ! rank
        mov     #50,r3
        cmp/gt  r3,r2
        bf      sp_ret
        mov     #100,r3             ! extra per mille: 2*(rank-50) up to 100, then rank
        cmp/gt  r3,r2
        bt      sp_mul
        add     #-50,r2
        add     r2,r2
sp_mul:
        mov     r9,r3
        add     r0,r3
        add     #48,r3              ! speed the game is about to use
        mul.l   r2,r3
        sts     macl,r3
        mov.w   x_1000,r2
        mov.l   r0,@-r15
        mov     r3,r0
        mov     r2,r1
        mov.l   x_div,r3            ! r0 / r1
        jsr     @r3
        nop
        mov     r0,r3
        mov.l   @r15+,r0
        add     r3,r0
sp_ret: lds.l   @r15+,pr
        rts
        nop

! unsigned r0 / r1 -> r0 (simple, small values)
udiv:   mov     #0,r2
ud_l:   cmp/hs  r1,r0
        bf      ud_e
        sub     r1,r0
        bra     ud_l
        add     #1,r2
ud_e:   rts
        mov     r2,r0

! boot text (runs from the loader before the game starts)
        .global boot_init
boot_init:
        mov.l   x_vars,r1
        mov     #1,r0
        mov.l   r0,@r1              ! always Resurrected (attract demos too)
        mova    bt_tab,r0
        mov     r0,r4
bt_l:   mov.l   @r4+,r1             ! dest (0 = end)
        tst     r1,r1
        bt      bt_e
        mov.l   @r4+,r2             ! src
        mov.l   @r4+,r3             ! len
bt_c:   mov.b   @r2+,r0
        mov.b   r0,@r1
        dt      r3
        bf/s    bt_c
        add     #1,r1
        bra     bt_l
        nop
bt_e:   rts
        nop

        .align 1
x_2e8:  .word 0x2E8
x_2e0:  .word 0x2E0
x_1000: .word 1000
        .align 2
x_vars:    .long v_mode
x_ncframe: .long nc_frame
x_ptab:    .long 0x0C5CD928     ! stage 1 boss part table: part 2 hit routine (part 3 at +20)
x_ph0o:    .long 0x0C2B6330     ! original pod hit routines (each damages both pods)
x_ph1o:    .long 0x0C2B6380
x_ph0:     .long pod_hit_0
x_ph1:     .long pod_hit_1
x_upf:     .long up_frame
x_hudt3:   .long hud_tab3
x_hudt2:   .long hud_tab2
        ! HUD rank patches (Omake: 3 digits, no 99 cap, centred / others: original)
hud_tab3:  .long 0x0C27ECC8, 0x55E10009     ! x offset: full digit instead of half
           .long 0x0C27ECD4, 0x0009E703     ! nop (no mov #99,r10) / mov #3,r7
           .long 0x0C27ECC4, 0xD346D64C     ! mov.l 0x011B0000,r3 (no 99 cap) / mov.l 0xA0000,r6 (swapped,
                                            ! so the block's first opcode changes and MAME recompiles it)
           .long 0
        ! HIT counter (data words only, set by the title hook)
hit_tab_om: .long 0x0C1F6CE0, 9999999          ! HIT cap 99999 -> 9,999,999
           .long 0x0C27DC24, 1000000           ! HIT HUD first divisor: 7 digits
           .long 0x0C27DC34, hit_slots         ! 8 evenly spaced digit slots
           .long 0x0C27ADB4, maxnum_hook       ! HUD MAX digits tighter above 99,999
           .long 0x0C290DEC, 0x03E82710        ! Hit Bonus = hits x 10,000
           .long 0
hit_tab_std: .long 0x0C1F6CE0, 99999
           .long 0x0C27DC24, 10000
           .long 0x0C27DC34, 0x0C5B59DC
           .long 0x0C27ADB4, 0x0C27E880
           .long 0x0C290DEC, 0x03E84E20        ! hits x 20,000 (original)
           .long 0
hud_tab2:  .long 0x0C27ECC8, 0x55E14621
           .long 0x0C27ECD4, 0xEA63E702
           .long 0x0C27ECC4, 0xD64CE363
           .long 0
x_se:      .long 0x0C282860
x_voice:   .long 0x0C276900
x_getrank: .long 0x0C1F9F80
x_speedfn: .long 0x0C1F37A0
x_div:     .long udiv
bt_tab:
        .long 0x0C30D230, t_title, 26
        .long 0x0C21EDD2, bt_tx, 2      ! boot title x: mov #-4,r4 -> mov #24,r4 (centred)
        .long 0x0C30D25A, t_date, 10
        .long 0x0C30D268, t_warn, 416
        .long 0x0C30D408, t_wdate, 23      ! (24-byte slot: 23 chars + its 0)
        ! HIT HUD and Hit Bonus code: changed once at boot (before any code runs, so MAME's
        ! recompiler sees them) to read data words that the title hook then sets per mode.
        ! With the standard values they behave exactly as the original game.
        .long 0x0C27DAF0, bt_hit1, 4    ! HIT digits: mov.w 10000 -> mov.l (literal 0x0C27DC24)
        .long 0x0C27DB60, bt_hit2, 4    !   same, second path
        .long 0x0C27DC24, bt_hit3, 4    !   literal: 10000 as a long
        .long 0x0C290D1C, bt_hb1, 4     ! Hit Bonus: mov.w reads the spare word 0x0C290DEE
        .long 0x0C290DEC, bt_hb2, 4     !   spare word: 20000 (original multiplier)
        ! hidden bee pickup: % = hits / 50, max 30. The hit count is read through bee_hits
        ! (original modes: at most 1500 hits, so exactly the original; 1.5+: the 200-hit chart)
        .long 0x0C22AAB8, bt_bh, 4      !   literal: hit getter -> bee_hits
        .long 0x0C22AA22, bt_bc0, 2     !   mov #30,r0 -> mov #100,r0
        .long 0x0C22AA28, bt_bc1, 2     !   mov #30,r8 -> mov #100,r8
        .long 0
        .align 2
bt_hit1: .long 0xDA4C4D11
bt_hit2: .long 0x5C1BDA30
bt_hit3: .long 10000
bt_hb1:  .long 0x9067797C
bt_hb2:  .long 0x03E84E20
bt_bh:   .long bee_hits
bt_tx:   .word 0xE418
bt_bc0:  .word 0xE064
bt_bc1:  .word 0xE864
        .align 2
        .ifndef BUILDNO
        .equ BUILDNO, 0
        .endif
t_title: .ascii "SDOJ PLATINUM LABEL B"      ! drawn from x = 24 (bt_tx): centred, 24 chars x 8 px
        .byte   '0' + BUILDNO / 100 % 10, '0' + BUILDNO / 10 % 10, '0' + BUILDNO % 10   ! build (tools/BUILD)
        .ascii  "  "
t_date:  .ascii "2026.11.20"
t_wdate: .ascii "                       "    ! warning date slot (23 chars): blank, the date line is in t_warn
t_warn:
        .ascii "   THIS PROJECT IS UNOFFICIAL "
        .byte 0,0
        .ascii "   AND IS NOT AFFILIATED WITH,"
        .byte 0,0
        .ascii "   ENDORSED BY, OR AUTHORIZED "
        .byte 0,0
        .ascii "   BY CAVE. ALL RIGHTS TO THE "
        .byte 0,0
        .ascii "   ORIGINAL GAME AND ITS      "
        .byte 0,0
        .ascii "   ASSOCIATED INTELLECTUAL    "
        .byte 0,0
        .ascii "   PROPERTY REMAIN WITH THEIR "
        .byte 0,0
        .ascii "   RESPECTIVE RIGHTS HOLDERS. "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "          HAVE FUN!!!         "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "   2026/11/20 PLATINUM LABEL  "
        .byte 0,0
        .align 2

! ================================================================ menu text
        .align 2
s_arc_on:  .asciz "> ARCADE"
s_arc_off: .asciz "  ARCADE"
s_15_on:   .asciz "> 1.5+"
s_15_off:  .asciz "  1.5+"
s_blank:   .asciz " "
s_or_on:   .asciz "> ORIGINAL ARCADE"
s_or_off:  .asciz "  ORIGINAL ARCADE"
s_ar_on:   .asciz "> 1.5+"
s_ar_off:  .asciz "  1.5+"
s_pw_on:   .asciz "> POWER MODE"
s_pw_off:  .asciz "  POWER MODE"
s_om_on:   .asciz "> OMAKE"
s_om_off:  .asciz "  OMAKE"
        .align 2
mstab:     .long s_or_off, s_or_on, s_ar_off, s_ar_on, s_pw_off, s_pw_on, s_om_off, s_om_on
        .align 2
! ================================================================ stage 1 boss pods
! The game's pod hit routines (0x0C2B6330 / 0x0C2B6380, called with r4 = hit entry, r6 = boss
! object) both call the pod damage routine 0x0C2B6880 for pod 0 AND pod 1, so a hit on either pod
! damages both. These replacements damage only their own pod; the game's routine still handles the
! flash, the explosion, the pod disappearing and the bonus. Pod HP (block +0, max +4; the game
! gives 114,688) is lowered to POD_HP (25% of the body's 149,760) on the pod's first hit.
        .equ POD_HP,    37440
        .global pod_hit_0
pod_hit_0:
        bra     pod_common
        mov     #0,r7
        .global pod_hit_1
pod_hit_1:
        mov     #1,r7
pod_common:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r4,r10              ! hit entry
        mov     r7,r9               ! pod index
        mov     r6,r4               ! boss object -> its work area
        mov.l   pc_cls,r5
        mov.l   pc_work,r0
        jsr     @r0
        nop
        mov     r0,r8               ! boss work area
        mov.l   pc_vars,r1          ! health bar: remember the boss and show this pod's bar for BAR_TIME frames
        add     #104,r1
        mov.l   r8,@r1              ! v_bwork
        mov     r9,r0
        shll2   r0
        add     #4,r1
        add     r0,r1
        mov     #BAR_TIME,r0
        mov.l   r0,@r1              ! v_ptmr0 / v_ptmr1
        mov.w   pc_290,r1           ! pod block = work + 0x784 + index * 0x290
        mul.l   r9,r1
        sts     macl,r1
        mov.w   pc_784,r2
        add     r2,r1
        add     r8,r1
        mov.l   pc_hp,r3
        mov.l   @(4,r1),r2          ! max HP
        cmp/eq  r3,r2
        bt      pc_go
        mov.l   r3,@(4,r1)          ! first hit: max = POD_HP, current lowered to it
        mov.l   @r1,r2
        cmp/hi  r3,r2
        bf      pc_go
        mov.l   r3,@r1
pc_go:  mov     r8,r4
        mov     r9,r5
        mov     r10,r6
        mov.l   pc_pod,r0
        jsr     @r0                 ! game's pod damage routine, this pod only
        nop
        mov     #1,r0
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
pc_290: .word 0x290
pc_784: .word 0x784
        .align 2
pc_cls:  .long 0x0C2B63D0           ! boss type (as passed by the game's routines)
pc_work: .long 0x0C202970           ! object -> work area
pc_pod:  .long 0x0C2B6880           ! pod damage (work, index, hit entry)
pc_hp:   .long POD_HP
pc_vars: .long v_mode

! ================================================================ pod health bars (360 graphics)
! The bar graphics are not part of this patch: the patcher cuts them from the user's own Xbox 360
! GOD package and writes them to u4 at BAR_GFX (header 'HPBR', atlas width/height, 13 pieces
! {x, y, w, h}: outline, fill, digits 0-9, '%'; pixels ARGB1555 from +0x80, in the game's native
! (rotated) orientation). Without them (no magic) nothing is drawn.
! While a pod's timer runs (set on each hit), the atlas is uploaded to free VRAM and the bar is
! drawn on the pod: outline, fill cut to HP, and the percentage below it. Native screen x is the
! game's "up" coordinate (pod +4), native y is the game's x (pod +0).
        .equ BAR_GFX,   0xA03C0000      ! u4 0x3C0000 (free space)
        .equ BAR_VX,    7568            ! free VRAM: x 7552-7647, y 128-487 is empty in every state sampled in stages 1-4
        .equ BAR_VY,    200             ! (x 5888 y 3584 was used by stage 3: the game drew our digits)
        .equ BAR_TIME,  90              ! frames a bar stays after the last hit

! Draw list close (frame draw driver 0x0C1DCC64, literal 0x0C1DCCEC -> 0x0C1D1744 with r4 = -1):
! every queued draw of the frame has run, the list is still open. Draws the bars last (on top of
! everything), then lets the game append its end marker and start the blitter.
        .global hud_hook
hud_hook:
        sts.l   pr,@-r15
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        mov.l   r7,@-r15
        mov.l   hh_bmb,r0           ! bomb maximum bonus (Ver 1.5 formula)
        jsr     @r0
        nop
        mov.l   hh_star,r0          ! big stars in hyper (1.5+: from hyper Lv 6)
        jsr     @r0
        nop
        mov.l   hh_bar,r0
        jsr     @r0
        nop
        mov.l   hh_gauge,r0         ! Power Mode: the BOOST gauge under INSERT COIN
        jsr     @r0
        nop
        mov.l   hh_strm,r0          ! Power Mode, the label level: enemies fire constant streams
        jsr     @r0
        nop
        mov.l   hh_mh,r0            ! Power Mode: our hyper meter
        jsr     @r0
        nop
        mov.l   @r15+,r7
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        lds.l   @r15+,pr
        mov.l   hh_rank,r0
        jmp     @r0
        nop
        .align 2
hh_bar:  .long bar_draw
hh_gauge: .long gauge_draw
hh_strm:  .long stream_frame
hh_mh:    .long mh_draw
hh_bmb:  .long bmb_frame
hh_star: .long star_frame
hh_rank: .long 0x0C1D1744           ! game: append a long to the list (here the end marker)

bar_draw:
        mov.l   bd_gfx,r0
        mov.l   @r0,r1
        mov.l   bd_magic,r2
        cmp/eq  r1,r2
        bt      bd_go
        rts
        nop
bd_go:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   r14,@-r15
        mov.l   bd_vars,r13
        add     #104,r13            ! r13 -> v_bwork, +4 / +8 pod timers
        mov.l   bd_ens,r0           ! big enemies: track HP, start bar timers
        jsr     @r0
        nop
        mov.l   bd_tus,r0           ! stage 3 ship turrets
        jsr     @r0
        nop
        mov.l   bd_s4f,r0           ! stage 4 boss arms: track, hit boxes, hide when destroyed
        jsr     @r0
        nop
        mov.l   bd_s5f,r0           ! stage 5 boss weapons
        jsr     @r0
        nop
        mov.l   @(4,r13),r0
        mov.l   @(8,r13),r1
        or      r1,r0
        mov.l   @(16,r13),r1        ! big enemy bars
        or      r1,r0
        mov.l   @(28,r13),r1        ! turret bars
        or      r1,r0
        mov.l   bd_s4v,r1           ! stage 4 arm bars / explosions
        mov.l   @(4,r1),r1
        or      r1,r0
        mov.l   bd_s5v,r1           ! stage 5 weapon bars / explosions
        mov.l   @(4,r1),r1
        or      r1,r0
        mov.l   bd_hg,r1            ! health bars wanted (their atlas is uploaded only then)
        mov.l   r0,@r1
        tst     r0,r0               ! (Power Mode's bottom bar no longer needs bar_draw every frame)
        bt      bd_end
        ! the game closes the frame's list (0xFFFFFFFF) before the HUD rank runs: step back over the
        ! end marker, add the bars, and write it again at the end (bd_end)
        mov.l   bd_lp,r1
        mov.l   @r1,r2
        add     #-4,r2
        mov.l   @r2,r0
        mov     #-1,r3
        cmp/eq  r3,r0
        bf      bd_open
        mov.l   r2,@r1
        mov     #1,r0
        mov.l   r0,@(12,r13)        ! v_relist
bd_open:
        mov.l   bd_hf,r0            ! note where the HUD starts, so the bars can go under it
        jsr     @r0
        nop
        ! upload the atlas: game routine writes the upload header, then the pixels follow in the list
        mov.l   bd_hg,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      bd_nohb             ! Power Mode only: no health bar atlas needed this frame
        mov.l   bd_gfx,r12
        mov     r12,r1
        add     #4,r1
        mov.w   @r1+,r10            ! atlas width (even)
        mov.w   @r1,r11             ! atlas height
        mov.l   bd_vx,r4
        mov.l   bd_vy,r5
        mov     r10,r6
        mov     r11,r7
        mov.l   bd_upl,r0
        jsr     @r0
        nop
        mov     r10,r0
        mul.l   r11,r0
        sts     macl,r0
        shlr    r0                  ! longs of pixel data
        mov.l   bd_lp,r1
        mov.l   @r1,r2              ! list write pointer
        mov     r12,r3
        mov     #64,r4
        add     r4,r3
        add     r4,r3               ! pixels at +0x80
bd_cp:  mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    bd_cp
        add     #4,r2
        mov.l   r2,@r1
bd_nohb:
        mov     #0,r14              ! pod index
bd_pod:
        mov     r13,r1
        add     #4,r1
        mov     r14,r0
        shll2   r0
        add     r0,r1               ! r1 -> this pod's timer
        mov.l   @r1,r0
        tst     r0,r0
        bt      bd_next
        add     #-1,r0
        mov.l   r0,@r1
        mov.l   @r13,r8             ! boss work
        mov.w   bd_290,r2
        mul.l   r14,r2
        sts     macl,r9
        add     r8,r9               ! work + index * 0x290
        mov.w   bd_784,r2
        mov     r9,r3
        add     r2,r3               ! pod block
        mov.l   @(4,r3),r0
        mov.l   bd_podhp,r2
        cmp/eq  r2,r0
        bf      bd_kill             ! not our pod data any more
        mov.l   @r3,r10             ! HP
        tst     r10,r10
        bt      bd_kill             ! destroyed: no bar
        mov.w   bd_550,r2
        add     r2,r9
        mov.l   @r9,r11
        shlr16  r11                 ! game x  -> native y
        mov.l   @(4,r9),r9
        shlr16  r9                  ! game up -> native x
        mov.l   bd_podhp,r8
        bsr     bd_bar
        nop
        bra     bd_next
        nop

! one health bar: r9 = native x (game up), r11 = native y (game x), r10 = HP, r8 = max HP.
! Clobbers r0-r12.
bd_bar:
        sts.l   pr,@-r15
        ! percentage, rounded up (1..100)
        mov     #100,r0
        mul.l   r10,r0
        sts     macl,r0
        mov     r8,r1
        add     r1,r0
        add     #-1,r0
        mov.l   bd_div,r2
        jsr     @r2
        nop
        mov     r0,r10              ! r10 = percent
        ! fill (piece 1), cut to the percentage from its far end; drawn first, behind the outline
        mov     #1,r0
        bsr     bd_piece
        nop
        mov     r1,r0
        shlr    r0
        mov     r9,r6
        sub     r0,r6
        mov     r2,r0
        shlr    r0
        mov     r11,r7
        sub     r0,r7
        mov     r2,r0
        mul.l   r10,r0
        sts     macl,r0
        mov.l   r1,@-r15
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov     #100,r1
        mov.l   bd_div,r2
        jsr     @r2
        nop
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        mov.l   @r15+,r1
        mov     r0,r2               ! kept length
        tst     r2,r2
        bt      bd_out
        bsr     bd_spr
        nop
bd_out:
        ! outline (piece 0), centred on the pod, over the fill
        mov     #0,r0
        bsr     bd_piece            ! r4 = src x, r5 = src y, r1 = w, r2 = h
        nop
        mov     r1,r0
        shlr    r0
        mov     r9,r6
        sub     r0,r6               ! dst x = up - w/2
        mov     r2,r0
        shlr    r0
        mov     r11,r7
        sub     r0,r7               ! dst y = x - h/2
        mov     r1,r12              ! keep the outline width for the digits
        bsr     bd_spr
        nop
bd_dig:
        ! digits of the percentage + '%', below the bar (smaller native x), along native y
        mov     r10,r0
        mov     #100,r1
        mov.l   bd_div,r2
        jsr     @r2
        nop
        mov     r0,r4               ! hundreds
        mov     #100,r1
        mul.l   r0,r1
        sts     macl,r1
        mov     r10,r0
        sub     r1,r0
        mov     r0,r5               ! rest 0..99
        mov     #10,r1
        mov.l   bd_div,r2
        jsr     @r2
        nop
        mov     r0,r6               ! tens
        mov     #10,r1
        mul.l   r0,r1
        sts     macl,r1
        mov     r5,r0
        sub     r1,r0               ! ones
        ! build the glyph list (piece numbers) on the stack: [hundreds] [tens] ones %
        add     #-8,r15
        mov     r15,r7
        tst     r4,r4
        bt      bd_d1
        mov     r4,r1
        add     #2,r1
        mov.b   r1,@r7
        add     #1,r7
        bra     bd_d2               ! with hundreds, always show the tens digit
        nop
bd_d1:  tst     r6,r6
        bt      bd_d3
bd_d2:  mov     r6,r1
        add     #2,r1
        mov.b   r1,@r7
        add     #1,r7
bd_d3:  add     #2,r0
        mov.b   r0,@r7
        add     #1,r7
        mov     #12,r0
        mov.b   r0,@r7              ! '%'
        add     #1,r7
        mov     #-1,r0
        mov.b   r0,@r7              ! end
        ! total length along native y
        mov     r15,r8
        mov     #0,r10
bd_tl:  mov.b   @r8+,r0
        cmp/pz  r0
        bf      bd_tl2
        bsr     bd_piece
        nop
        bra     bd_tl
        add     r2,r10
bd_tl2: shlr    r10
        mov     r11,r0
        sub     r10,r0
        mov     r0,r10              ! r10 = start native y = x - total/2
        mov     r15,r8
bd_dl:  mov.b   @r8+,r0
        cmp/pz  r0
        bf      bd_dend
        bsr     bd_piece
        nop
        mov     r1,r0
        shlr    r0
        mov     r9,r6
        sub     r0,r6               ! dst x = up - glyph w/2: centred on the bar, drawn over it (as on the 360)
        mov     r10,r7
        add     r2,r10
        bsr     bd_spr
        nop
        bra     bd_dl
        nop
bd_dend:
        add     #8,r15
        lds.l   @r15+,pr
        rts
        nop
bd_kill:
        mov     r13,r1
        add     #4,r1
        mov     r14,r0
        shll2   r0
        add     r0,r1
        mov     #0,r0
        mov.l   r0,@r1
bd_next:
        add     #1,r14
        mov     r14,r0
        cmp/eq  #2,r0
        bf      bd_pod
        mov.l   bd_end2,r0          ! big enemy bars
        jsr     @r0
        nop
        mov.l   bd_tud,r0           ! turret bars
        jsr     @r0
        nop
        mov.l   bd_s4d,r0           ! stage 4 arm bars and explosions
        jsr     @r0
        nop
        mov.l   bd_s5d,r0           ! stage 5 weapon bars and explosions
        jsr     @r0
        nop
        mov.l   bd_hm,r0            ! move the bars under the HUD
        jsr     @r0
        nop
        mov.l   @(12,r13),r0        ! list was closed: close it again after the bars
        tst     r0,r0
        bt      bd_end
        mov     #0,r0
        mov.l   r0,@(12,r13)
        mov.l   bd_lp,r1
        mov.l   @r1,r2
        mov     #-1,r0
        mov.l   r0,@r2
        add     #4,r2
        mov.l   r2,@r1
bd_end:
        mov.l   @r15+,r14
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! r0 = piece number -> r4 = VRAM x, r5 = VRAM y, r1 = w, r2 = h (from the atlas header)
bd_piece:
        mov.l   bd_gfx,r3
        shll2   r0
        shll    r0
        add     #8,r0
        add     r0,r3
        mov.w   @r3+,r4
        mov.l   bd_vx,r0
        add     r0,r4
        mov.w   @r3+,r5
        mov.l   bd_vy,r0
        add     r0,r5
        mov.w   @r3+,r1
        rts
        mov.w   @r3,r2

! draw VRAM (r4, r5) size r1 x r2 at native screen (r6, r7), transparent, normal tint
bd_spr:
        sts.l   pr,@-r15
        mov.l   r1,@-r15            ! keep w, h (the game routine clobbers r1, r2)
        mov.l   r2,@-r15
        add     #-16,r15            ! the game routine reads w, h, tint, flags from the stack
        mov.l   r1,@r15
        mov.l   r2,@(4,r15)
        mov.l   bd_tint,r0
        mov.l   r0,@(8,r15)
        mov     #0,r0
        mov.l   r0,@(12,r15)
        mov.l   bd_drw,r0
        jsr     @r0
        nop
        add     #16,r15
        mov.l   @r15+,r2
        mov.l   @r15+,r1
        lds.l   @r15+,pr
        rts
        nop
        .align 1
bd_290: .word 0x290
bd_784: .word 0x784
bd_550: .word 0x550
        .align 2
bd_gfx:   .long BAR_GFX
bd_magic: .long 0x48504252      ! 'HPBR'
bd_vars:  .long v_mode
bd_vx:    .long BAR_VX
bd_vy:    .long BAR_VY
bd_upl:   .long 0x0C1D17C0      ! game: upload header (x, y, w, h)
bd_drw:   .long 0x0C1D17EC      ! game: draw sprite (src x, src y, dst x, dst y; stack w, h, tint, flags)
bd_lp:    .long 0x0C1D1460      ! draw list write pointer
bd_podhp: .long POD_HP
bd_div:   .long udiv
bd_tint:  .long 0x00808080
bd_ens:   .long en_scan
bd_end2:  .long en_draw
bd_tus:   .long tu_scan
bd_tud:   .long tu_draw
bd_s4f:   .long s4_frame
bd_s4d:   .long s4_draw
bd_s4v:   .long s4_v
bd_hg:    .long dk_hgate
bd_s5f:   .long s5_frame
bd_s5d:   .long s5_draw
bd_s5v:   .long s5_v
bd_hf:    .long hud_find
bd_hm:    .long hud_move

! ================================================================ big enemy health bars
! Enemy objects sit in fixed slots (0x0C661BC0 + k * 0x21FC); each points to its work area at
! +0x21CC, and the work area points back at +0. Work: +4 x, +8 up (16.16), +0x20 HP, +0x30 max HP.
! Every enemy with max HP over EN_MIN gets the 360 bar while it is being hit (BAR_TIME frames after
! its HP last dropped). Slots 0-3 (boss / mid-boss objects, which use the boss bar) are skipped, and
! so is any work area whose values are not plausible HP.
        .equ EN_BASE,   0x0C661BC0
        .equ EN_STRIDE, 0x21FC
        .equ EN_FIRST,  0               ! first slot checked
        .equ EN_N,      68              ! slots checked
        .equ EN_MIN,    499             ! max HP must be over this (500 and up)
        .equ EN_MIN3,   223             ! stage 3: 224 and up (its medium ships, guns and buildings)

! from bar_draw (r13 = v_bwork, kept), every frame: update the per-slot table, then store the
! number of running bar timers in v_eany.
        .global en_scan
en_scan:
        mov.w   es_min,r8           ! threshold: EN_MIN, or EN_MIN3 in stage 3
        mov.l   es_stage,r0
        mov.l   @r0,r0              ! current stage (0 = stage 1)
        cmp/eq  #2,r0
        bf      1f
        mov.w   es_min3,r8
1:      mov.l   es_tab,r12          ! table: work, last HP, timer (12 bytes per slot)
        mov.l   es_obj,r11          ! first object
        mov     #EN_N,r10
        mov     #0,r9               ! running timers
es_l:   mov.w   es_wo,r0
        mov.l   @(r0,r11),r1        ! work
        mov.l   es_wlo,r2
        cmp/hs  r2,r1
        bf      es_off
        mov.l   es_whi,r2
        cmp/hs  r2,r1
        bt      es_off
        mov.l   @r1,r0              ! points back to this object?
        cmp/eq  r11,r0
        bf      es_off
        ! some enemy types keep the same fields 4 or 8 bytes later: find the marker that follows
        ! max HP (+0x34 = 1, +0x40 = pointer into the hit list) and use the shifted base from here on
        mov     #3,r6
es_sh:  mov     r1,r0
        add     #64,r0
        mov.l   @r0,r0              ! +0x40 (beyond mov.l's 60-byte reach)
        mov.l   es_nlo,r2
        cmp/hs  r2,r0
        bf      es_sn
        mov.l   es_nhi,r2
        cmp/hs  r2,r0
        bt      es_sn
        mov.l   @(52,r1),r0
        cmp/eq  #1,r0
        bt      es_shok
es_sn:  dt      r6
        bf/s    es_sh
        add     #4,r1
        bra     es_off
        nop
es_shok:
        mov.l   @(48,r1),r3         ! max HP
        cmp/gt  r8,r3
        bf      es_off
        mov.l   es_max,r0
        cmp/gt  r0,r3
        bt      es_off
        mov.l   @(32,r1),r4         ! HP
        cmp/pl  r4
        bf      es_off
        cmp/gt  r3,r4
        bt      es_off
        mov.l   @r12,r0             ! same enemy as last frame?
        cmp/eq  r1,r0
        bf      es_new
        mov.l   @(4,r12),r0
        cmp/gt  r4,r0               ! HP dropped: show the bar
        bf      es_keep
        mov     #BAR_TIME,r0
        mov.l   r0,@(8,r12)
es_keep:
        mov.l   r4,@(4,r12)
        mov.l   @(8,r12),r0
        tst     r0,r0
        bt      es_n
        bra     es_n
        add     #1,r9
es_new: mov.l   r1,@r12
        mov.l   r4,@(4,r12)
        mov     #0,r0
        bra     es_n
        mov.l   r0,@(8,r12)
es_off: mov     #0,r0
        mov.l   r0,@r12
        mov.l   r0,@(8,r12)
es_n:   mov.l   es_stride,r0
        add     r0,r11
        dt      r10
        bf/s    es_l
        add     #12,r12
        mov     r9,r0
        rts
        mov.l   r0,@(16,r13)        ! v_eany
        .align 1
es_wo:  .word 0x21CC
es_min: .word EN_MIN
es_min3: .word EN_MIN3
        .align 2
es_stage:  .long 0x0C31DFDC         ! game: current stage, 0-4 (0x0C4C897C is NOT the stage: it rises with rank)
es_nlo:    .long 0x0C800000         ! hit list pointers (marker after max HP)
es_nhi:    .long 0x0CA00000
es_tab:    .long en_tab
es_obj:    .long EN_BASE + EN_FIRST * EN_STRIDE
es_wlo:    .long 0x0C700000
es_whi:    .long 0x0CA00000
es_max:    .long 20000
es_stride: .long EN_STRIDE

! from bar_draw (r13 kept), with the atlas uploaded: a bar on every enemy whose timer runs
        .global en_draw
en_draw:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
        mov.l   ed_tab,r14
        mov     #EN_N,r13
ed_l:   mov.l   @(8,r14),r0         ! timer
        tst     r0,r0
        bt      ed_n
        add     #-1,r0
        mov.l   r0,@(8,r14)
        mov.l   @r14,r1             ! work (checked this frame by en_scan)
        tst     r1,r1
        bt      ed_n
        mov.l   @(8,r1),r9          ! up -> native x
        shlr16  r9
        exts.w  r9,r9
        mov.l   @(4,r1),r11         ! x -> native y
        shlr16  r11
        exts.w  r11,r11
        mov     r9,r0               ! on screen only
        cmp/pz  r0
        bf      ed_n
        mov.w   ed_320,r2
        cmp/gt  r2,r0
        bt      ed_n
        mov     r11,r0
        cmp/pz  r0
        bf      ed_n
        mov.w   ed_240,r2
        cmp/gt  r2,r0
        bt      ed_n
        mov.l   @(32,r1),r10        ! HP
        mov.l   @(48,r1),r8         ! max HP
        mov.l   ed_bar,r0
        jsr     @r0
        nop
ed_n:   dt      r13
        bf/s    ed_l
        add     #12,r14
        mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
        .align 1
ed_320: .word 320
ed_240: .word 240
        .align 2
ed_tab: .long en_tab
ed_bar: .long bd_bar
en_tab: .space EN_N * 12

! ================================================================ bars under the HUD
! The HUD is drawn last in the frame and all of it comes from the top VRAM row (source y < 256);
! the game's sprites before it come from lower rows. hud_find (before the bars are added) notes
! where the HUD starts: right after the last draw whose source y is 256 or more. hud_move (after
! the bars) moves the bar commands to that point by rotating the end of the list in place, so the
! HUD is drawn over the bars.
        .global hud_find
hud_find:
        mov.l   hf_lbase,r1
        mov.l   @r1,r4              ! list start
        mov.l   hf_lp,r1
        mov.l   @r1,r5              ! list end (bars start here)
        mov.l   r5,@(24,r13)        ! v_bstart
        mov     r5,r3               ! HUD start if nothing is found: the end
        mov.w   hf_1fff,r6
        mov.w   hf_fff,r7
        mov.w   hf_256,r2
hf_l:   cmp/hs  r5,r4
        bt      hf_ret
        mov.l   @r4,r0
        cmp/eq  #-1,r0
        bt      hf_ret
        shlr16  r0
        shlr8   r0
        shlr2   r0
        shlr2   r0
        cmp/eq  #1,r0
        bt      hf_drw
        cmp/eq  #2,r0
        bt      hf_upl
        bra     hf_l
        add     #4,r4
hf_upl: mov.w   @(12,r4),r0
        and     r6,r0
        add     #1,r0
        mov     r0,r1
        mov.w   @(14,r4),r0
        and     r7,r0
        add     #1,r0
        mul.l   r1,r0
        sts     macl,r0
        add     r0,r0
        add     #16,r0
        bra     hf_l
        add     r0,r4
hf_drw: mov.w   @(6,r4),r0          ! source y
        and     r7,r0
        add     #20,r4
        cmp/hs  r2,r0
        bf      hf_l
        bra     hf_l
        mov     r4,r3               ! a game sprite: the HUD starts after it
hf_ret: rts
        mov.l   r3,@(20,r13)        ! v_hud
        .align 1
hf_1fff: .word 0x1FFF
hf_fff:  .word 0x0FFF
hf_256:  .word 256
        .align 2
hf_lbase: .long 0x0C1D1454
hf_lp:    .long 0x0C1D1460

! r13 kept: rotate [v_hud, end) so the bars [v_bstart, end) come first
        .global hud_move
hud_move:
        sts.l   pr,@-r15
        mov.l   @(20,r13),r8        ! HUD start
        mov.l   @(24,r13),r9        ! bars start
        mov.l   hm_lp,r1
        mov.l   @r1,r10             ! end
        cmp/hs  r9,r8
        bt      hm_ret              ! no HUD after the sprites: nothing to move
        cmp/hs  r10,r9
        bt      hm_ret              ! no bars
        mov     r8,r4
        bsr     hm_rev
        mov     r9,r5
        mov     r9,r4
        bsr     hm_rev
        mov     r10,r5
        mov     r8,r4
        bsr     hm_rev
        mov     r10,r5
hm_ret: lds.l   @r15+,pr
        rts
        nop
! reverse the longs in [r4, r5)
hm_rev: add     #-4,r5
hr_l:   cmp/hs  r5,r4
        bt      hr_e
        mov.l   @r4,r0
        mov.l   @r5,r1
        mov.l   r1,@r4
        mov.l   r0,@r5
        add     #4,r4
        bra     hr_l
        add     #-4,r5
hr_e:   rts
        nop
        .align 2
hm_lp:  .long 0x0C1D1460

! ================================================================ boss part bars (stage 3 ship, stage 4 mid-boss)
! Some bosses keep destructible parts in their work area: part i block at work + base + i * stride:
! +0 HP, +4 max HP; the part's position (x, up 16.16) is at block + pos / + pos + 4. The boss is found
! among the object slots by two known max HP values (cfg id0 / id1). A part's bar shows for BAR_TIME
! frames after its HP drops; the boss itself (boss bar) gets none.
        .equ TU_N,      12              ! table size (most parts of any boss)

! from bar_draw (r13 = v_bwork, kept), every frame: running part timers -> v_tany
        .global tu_scan
tu_scan:
        sts.l   pr,@-r15
        mov.l   ts_cfgs,r9          ! group 1: boss configurations (0 = end)
        mov.l   ts_tab,r7
        bsr     tu_body
        nop
        mov.l   r0,@-r15
        mov.l   ts_cfgs2,r9         ! group 2 (second set of parts on the same boss)
        mov.l   ts_tab2,r7
        bsr     tu_body
        nop
        mov.l   @r15+,r1
        add     r1,r0
        mov.l   r0,@(28,r13)        ! v_tany
        lds.l   @r15+,pr
        rts
        nop
! r9 = configuration list, r7 = table -> r0 = running timers
tu_body:
ts_cfg: mov.l   @r9,r0
        tst     r0,r0
        bt      ts_nob
        mov.l   ts_obj,r11
        mov     #68,r10
ts_find:
        mov.w   ts_wo,r0
        mov.l   @(r0,r11),r1        ! work
        mov.l   ts_wlo,r2
        cmp/hs  r2,r1
        bf      ts_fn
        mov.l   ts_whi,r2
        cmp/hs  r2,r1
        bt      ts_fn
        mov.l   @(16,r9),r0         ! id0 offset
        mov.l   @(r0,r1),r2
        mov.l   @(20,r9),r3
        cmp/eq  r3,r2
        bf      ts_fn
        mov.l   @(24,r9),r0         ! id1 offset
        mov.l   @(r0,r1),r2
        mov.l   @(28,r9),r3
        cmp/eq  r3,r2
        bt      ts_got
ts_fn:  mov.l   ts_stride,r0
        add     r0,r11
        dt      r10
        bf      ts_find
        bra     ts_cfg
        add     #32,r9              ! next configuration
ts_nob: mov     r7,r12              ! no boss with parts: clear
        mov     #0,r0
        mov.l   r0,@r12             ! table +0 = boss work, +4 = configuration
        bra     ts_cnt
        nop
ts_got: mov     r7,r12
        mov.l   @r12,r0
        cmp/eq  r1,r0
        bt      ts_same
        mov.l   r1,@r12             ! new boss: last HP = current, timers off
        mov.l   r9,@(4,r12)
        mov.l   @r9,r4
        add     r1,r4               ! first block
        mov     r12,r5
        add     #8,r5
        mov.l   @(8,r9),r6
ts_init:
        mov.l   @r4,r0
        mov.l   r0,@r5
        mov     #0,r0
        mov.l   r0,@(4,r5)
        mov.l   @(4,r9),r0
        add     r0,r4
        dt      r6
        bf/s    ts_init
        add     #8,r5
        bra     ts_cnt
        nop
ts_same:
        mov.l   @r9,r4
        add     r1,r4
        mov     r12,r5
        add     #8,r5
        mov.l   @(8,r9),r6
ts_l:   mov.l   @r4,r2              ! HP now
        mov.l   @r5,r0              ! last
        cmp/gt  r2,r0
        bf      ts_k
        mov     #BAR_TIME,r0
        mov.l   r0,@(4,r5)
ts_k:   mov.l   r2,@r5
        mov.l   @(4,r9),r0
        add     r0,r4
        dt      r6
        bf/s    ts_l
        add     #8,r5
ts_cnt: mov     r7,r5               ! running timers
        mov.l   @r5,r0
        tst     r0,r0
        bt      ts_none
        mov.l   @(4,r5),r1
        mov.l   @(8,r1),r6          ! parts
        add     #8,r5
        mov     #0,r1
ts_c:   mov.l   @(4,r5),r0
        tst     r0,r0
        bt      1f
        add     #1,r1
1:      dt      r6
        bf/s    ts_c
        add     #8,r5
        rts
        mov     r1,r0
ts_none:
        rts
        mov     #0,r0
        .align 1
ts_wo:   .word 0x21CC
        .align 2
ts_cfgs:   .long tu_cfg
ts_obj:    .long EN_BASE
ts_wlo:    .long 0x0C700000
ts_whi:    .long 0x0CA00000
ts_stride: .long EN_STRIDE
ts_tab:    .long tu_tab
ts_cfgs2:  .long tu_cfg2
ts_tab2:   .long tu_tab2
        ! base, stride, parts, position offset in the block, id0 offset / value, id1 offset / value
tu_cfg:    .long 0xD0, 0xB8, 12, 0x44, 0xD4, 9216, 0xD0 + 6 * 0xB8 + 4, 4608        ! stage 3 ship turrets
           .long 0xA4, 0xC4, 8, -0x74, 0xA8, 16384, 0xA4 + 7 * 0xC4 + 4, 16384      ! stage 4 mid-boss orbiters
           .long 0
tu_cfg2:   .long 0x990, 0xDC, 3, 0x44, 0xD4, 9216, 0x990 + 4, 2048                  ! stage 3 ship helipad pods (phase 2)
           .long 0

! from bar_draw (r13 kept), atlas uploaded: a bar on each part whose timer runs
        .global tu_draw
tu_draw:
        sts.l   pr,@-r15
        mov.l   td_tab,r14
        bsr     td_body
        nop
        mov.l   td_tab2,r14
        bsr     td_body
        nop
        lds.l   @r15+,pr
        rts
        nop
td_body:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
        mov.l   @r14,r0             ! boss work
        tst     r0,r0
        bt      td_ret
        mov.l   @(4,r14),r1         ! configuration
        mov.l   r1,@-r15            ! [r15+4] = configuration
        mov.l   @r1,r2
        add     r2,r0
        mov.l   r0,@-r15            ! [r15] = block pointer
        mov.l   @(8,r1),r13         ! parts
        add     #8,r14
td_l:   mov.l   @(4,r14),r0         ! timer
        tst     r0,r0
        bt      td_n
        add     #-1,r0
        mov.l   r0,@(4,r14)
        mov.l   @r15,r1             ! block
        mov.l   @r1,r10             ! HP
        cmp/pl  r10
        bf      td_n
        mov.l   @(4,r1),r8          ! max
        mov.l   @(4,r15),r2
        mov.l   @(12,r2),r0         ! position offset
        add     r0,r1
        mov.l   @(4,r1),r9          ! up -> native x
        shlr16  r9
        exts.w  r9,r9
        mov.l   @r1,r11             ! x -> native y
        shlr16  r11
        exts.w  r11,r11
        mov     r9,r0               ! on screen only
        cmp/pz  r0
        bf      td_n
        mov.w   td_320,r2
        cmp/gt  r2,r0
        bt      td_n
        mov     r11,r0
        cmp/pz  r0
        bf      td_n
        mov.w   td_240,r2
        cmp/gt  r2,r0
        bt      td_n
        mov.l   td_bar,r0
        jsr     @r0
        nop
td_n:   mov.l   @(4,r15),r2
        mov.l   @(4,r2),r1          ! stride
        mov.l   @r15,r0
        add     r1,r0
        mov.l   r0,@r15
        dt      r13
        bf/s    td_l
        add     #8,r14
        add     #8,r15
td_ret: mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
        .align 1
td_320: .word 320
td_240: .word 240
        .align 2
td_tab: .long tu_tab
td_tab2: .long tu_tab2
td_bar: .long bd_bar
tu_tab: .space 8 + TU_N * 8             ! boss work, configuration, then (last HP, timer) per part
tu_tab2: .space 8 + TU_N * 8            ! second group

! ================================================================ stage 4 boss arms (breakable)
! The arms (phase before the hexagon barrier) are only drawn by the boss: their sprites come from VRAM
! x 4096-5503, y 3584-3839. Boss part rows 6 / 7 (hit routines 0x0C2D5AB0 / 0x0C2D5AF0) are two 8x8
! boxes at the arms' resting spots that only flash. Each frame (at the list close) the arm sprites
! are found, the two live hit boxes are moved and sized onto the arms, and the hit routines in their
! hit nodes are replaced: each arm takes damage from its own HP (S4_AHP, 25% of the boss), shows the
! bar, and at 0 gives 100,000, the explosion sound and an explosion; then its sprites are hidden, its
! box is moved away and bullets near it are cancelled. Boss HP is not touched by arm hits.
        .equ S4_AHP,    5000            ! per arm
        .equ S4_EXT,    24
        ! s4_v: +0 boss work, +4 bar/explosion count, +8 node L, +12 node R, +16 fight work,
        !       +20 arm L, +48 arm R (28 bytes: hp, timer, dead, ex, x 16.16, up 16.16, seen),
        !       +76 box L (min up, max up, min x, max x), +92 box R, +108 node search cursor,
!       +112 1 = arm 0 is right of arm 1, +116 node centres px (arm 0 x, up, arm 1 x, up)
        .global s4_frame
s4_frame:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
        mov.l   sa_v,r14
.ifdef DEBUG_S4
        mov.l   sa_dbo,r0           ! debug build: start on stage 4 (both stage order tables)
        mov     #3,r1               ! the first stage is read from entry 0, 1 or 2 (by mode)
        mov.l   r1,@r0
        mov.l   r1,@(4,r0)
        mov.l   r1,@(8,r0)
        mov.l   sa_dbo2,r0
        mov.l   r1,@r0
        mov.l   r1,@(4,r0)
        mov.l   r1,@(8,r0)
.endif
        .equ S4_ARMS,   0               ! 0 = stage 4 boss as in the original game (arms code off)
.if S4_ARMS == 0
        bra     sa_off
        nop
.endif
        ! (no stage check: 0x0C4C897C rises with rank and is not the stage; the part table
        ! below is only this boss's)
        mov.l   sa_row6,r0          ! stage 4 boss part table loaded?
        mov.l   @r0,r0
        mov.l   sa_o6,r1
        cmp/eq  r1,r0
        bf      sa_off
        mov.l   sa_bobj,r0
        mov.l   sa_wol,r1
        mov.l   @(r0,r1),r8         ! boss work
        mov.l   r8,@r14
        mov.l   @(16,r14),r0
        cmp/eq  r8,r0
        bt      sa_same
        mov.l   r8,@(16,r14)        ! new fight: reset
        mov     #0,r0
        mov.l   r0,@(8,r14)
        mov.l   r0,@(12,r14)
        mov     r14,r1
        add     #20,r1
        mov     #2,r2
sa_rs:  mov.l   sa_hp,r3
        mov.l   r3,@r1
        mov.l   r0,@(4,r1)
        mov.l   r0,@(8,r1)
        mov.l   r0,@(12,r1)
        mov.l   r0,@(24,r1)
        dt      r2
        bf/s    sa_rs
        add     #28,r1
sa_same:
        ! the arms are the hit nodes of rows 3 / 2 (owner = boss object; phase 2 moves them out to
        ! -104 / +104). Cached nodes are checked every frame
        ! (owner still the boss, routine still theirs or ours); a missing node is searched for over
        ! the whole node region, 16 KB per frame, so it is found wherever the game put it.
        mov.l   sa_bobj,r6
        mov     r14,r7
        add     #8,r7
        mov     #2,r2
sa_vc:  mov.l   @r7,r4
        tst     r4,r4
        bt      sa_vn
        mov.l   @(20,r4),r0
        cmp/eq  r6,r0
        bf      sa_vb
        mov.l   @(16,r4),r0
        mov.l   sa_o3,r3
        cmp/eq  r3,r0
        bt      sa_vn
        mov.l   sa_o2,r3
        cmp/eq  r3,r0
        bt      sa_vn
        mov.l   sa_hl,r3
        cmp/eq  r3,r0
        bt      sa_vn
        mov.l   sa_hr,r3
        cmp/eq  r3,r0
        bt      sa_vn
sa_vb:  mov     #0,r0
        mov.l   r0,@(8,r14)
        bra     sa_vd
        mov.l   r0,@(12,r14)
sa_vn:  dt      r2
        bf/s    sa_vc
        add     #4,r7
sa_vd:  mov.l   @(8,r14),r0
        tst     r0,r0
        bt      sa_sc
        mov.l   @(12,r14),r0
        tst     r0,r0
        bf      sa_hn
sa_sc:  mov     r14,r7
        add     #108,r7
        mov.l   @r7,r4              ! search cursor
        mov.l   sa_nlo,r1
        cmp/hs  r1,r4
        bf      1f
        mov.l   sa_nhi,r1
        cmp/hs  r1,r4
        bf      2f
1:      mov.l   sa_nlo,r4
2:      mov.l   sa_step,r5
        add     r4,r5
sa_ns:  mov     r4,r0
        add     #16,r0
        mov.l   @r0+,r1             ! routine
        mov.l   @r0,r2              ! owner
        cmp/eq  r6,r2
        bf      sa_nn
        mov.l   sa_o3,r3
        cmp/eq  r3,r1
        bt      3f
        mov.l   sa_hl,r3
        cmp/eq  r3,r1
        bf      1f
3:      mov.l   r4,@(8,r14)
1:      mov.l   sa_o2,r3
        cmp/eq  r3,r1
        bt      3f
        mov.l   sa_hr,r3
        cmp/eq  r3,r1
        bf      sa_nn
3:      mov.l   r4,@(12,r14)
sa_nn:  add     #8,r4
        cmp/hs  r5,r4
        bf      sa_ns
        mov.l   r4,@r7
sa_hn:  mov.l   sa_phl,r0           ! phase 2 (arms out, before the barrier): our routines in the
        mov.l   @(r0,r8),r0         ! two nodes; otherwise the game's own
        tst     r0,r0
        bt      sa_in
        mov.l   sa_ph8,r0
        mov.l   @(r0,r8),r0
        tst     r0,r0
        bf      sa_in
        mov.l   sa_hl,r1
        mov.l   sa_hr,r2
        bra     sa_wr
        mov     #1,r3
sa_in:  mov.l   sa_o3,r1
        mov.l   sa_o2,r2
        mov     #0,r3
sa_wr:  mov.l   @(8,r14),r0
        tst     r0,r0
        bt      1f
        mov.l   r1,@(16,r0)
1:      mov.l   @(12,r14),r0
        tst     r0,r0
        bt      2f
        mov.l   r2,@(16,r0)
2:      tst     r3,r3
        bf      7f
        bra     sa_ret
        nop
        .align 2
        ! constants for the part above (in reach of its mov.l)
sa_v:     .long s4_v
sa_row6:  .long 0x0C5D7D3C + 6 * 20 + 8
sa_o6:    .long 0x0C2D5AB0
sa_bobj:  .long 0x0C661BC0
sa_wol:   .long 0x21CC
sa_hp:    .long S4_AHP
sa_o3:    .long 0x0C2D58D0         ! row 3: left arm in phase 2
sa_o2:    .long 0x0C2D5830         ! row 2: right arm in phase 2
sa_hl:    .long s4_hitl
sa_hr:    .long s4_hitr
sa_nlo:   .long 0x0C800000
sa_nhi:   .long 0x0CA00000
sa_step:  .long 0x4000
sa_ph8:   .long 0x8C               ! boss work: set when the hex barrier phase starts
sa_phl:   .long 0xF9C              ! boss work: 0 in phase 1, 1 from phase 2 (arms out)
sa_dbo:   .long 0x0C4C8768
sa_dbo2:  .long 0x0C4C8834
7:      ! arm centres from their nodes (the game moves the boxes): boss + box offset
        mov     #0,r9
sa_pc:  mov     r9,r0
        shll2   r0
        add     r14,r0
        mov.l   @(8,r0),r4          ! node
        mov     r9,r0
        mov     #28,r1
        mul.l   r1,r0
        sts     macl,r10
        add     r14,r10
        add     #20,r10             ! arm
        mov     #0,r0
        tst     r4,r4
        bt      1f
        mov.l   @(12,r4),r4         ! its box
        mov.l   @(56,r4),r1         ! +0x38 x offset
        mov.l   @(12,r8),r2
        add     r2,r1
        mov.l   r1,@(16,r10)
        mov.l   @(60,r4),r1         ! +0x3C up offset
        mov.l   @(16,r8),r2
        add     r2,r1
        mov.l   r1,@(20,r10)
        mov     #1,r0
1:      mov.l   r0,@(24,r10)        ! seen
        mov     r9,r1               ! node centre in px at +116 + 8 * arm (30000 = no node)
        shll2   r1
        shll    r1
        add     r14,r1
        add     #116,r1
        tst     r0,r0
        bf      2f
        mov.l   sa_bigl,r2
        mov.l   r2,@r1
        bra     3f
        mov.l   r2,@(4,r1)
2:      mov.l   @(16,r10),r2
        shlr16  r2
        exts.w  r2,r2
        mov.l   r2,@r1
        mov.l   @(20,r10),r2
        shlr16  r2
        exts.w  r2,r2
        mov.l   r2,@(4,r1)
3:
        add     #1,r9
        mov     r9,r0
        cmp/eq  #2,r0
        bf      sa_pc
        mov.l   @(36,r14),r0        ! arm 0 x
        mov     r14,r2
        add     #64,r2
        mov.l   @r2,r1              ! arm 1 x
        cmp/gt  r1,r0               ! arm 0 on the right? (they swing)
        movt    r3
        mov     r14,r2
        add     #112,r2
        mov.l   r3,@r2
        add     r1,r0
        shar    r0
        shlr16  r0
        exts.w  r0,r13              ! middle between the arms (px): splits the sprites
        ! arm sprites in the list: bounding box per side; hide a destroyed arm's pieces
        mov     r14,r1
        add     #76,r1
        mov.l   sa_bigl,r2
        mov.l   sa_smalll,r3
        mov     #2,r0
sa_bi:  mov.l   r2,@r1
        mov.l   r3,@(4,r1)
        mov.l   r2,@(8,r1)
        mov.l   r3,@(12,r1)
        dt      r0
        bf/s    sa_bi
        add     #16,r1
        mov     r13,r12             ! split left / right at the middle between the arms
        mov.l   sa_lbase,r1
        mov.l   @r1,r4
        mov.l   sa_lp,r1
        mov.l   @r1,r5
        mov.l   @(4,r1),r6
        shlr16  r6
        exts.w  r6,r6               ! origin x
        mov.l   @(8,r1),r7          ! origin y
sa_l:   cmp/hs  r5,r4
        bt      sa_le
        mov.l   @r4,r0
        cmp/eq  #-1,r0
        bt      sa_le
        shlr16  r0
        shlr8   r0
        shlr2   r0
        shlr2   r0
        cmp/eq  #1,r0
        bt      sa_d
        cmp/eq  #2,r0
        bt      sa_u
        bra     sa_l
        add     #4,r4
sa_u:   mov.w   @(12,r4),r0
        mov.w   sa_1fff,r1
        and     r1,r0
        add     #1,r0
        mov     r0,r2
        mov.w   @(14,r4),r0
        mov.w   sa_fff,r1
        and     r1,r0
        add     #1,r0
        mul.l   r2,r0
        sts     macl,r0
        add     r0,r0
        add     #16,r0
        bra     sa_l
        add     r0,r4
sa_d:   ! arm pieces, found by their shape wherever the game keeps the picture: a body is
        ! 90-130 px tall (up extent); a cap is the command just before a body with the same
        ! source row and source x + its extent = the body's source x
        mov.w   sa_1fff,r1
        mov.w   @(12,r4),r0
        and     r1,r0
        add     #1,r0
        mov     #90,r2
        cmp/ge  r2,r0
        bf      1f
        mov     #127,r2
        add     #4,r2               ! 131
        cmp/ge  r2,r0
        bf      sa_pz               ! a body
1:      mov     r0,r3               ! r3 = this extent; cap of the next command?
        mov     r4,r12
        add     #20,r12
        cmp/hs  r5,r12
        bt      sa_n
        mov.l   @r12,r0
        shlr16  r0
        shlr8   r0
        shlr2   r0
        shlr2   r0
        cmp/eq  #1,r0
        bf      sa_n
        mov.w   @(12,r12),r0        ! next is a body
        and     r1,r0
        add     #1,r0
        mov     #90,r2
        cmp/ge  r2,r0
        bf      sa_n
        mov     #127,r2
        add     #4,r2
        cmp/ge  r2,r0
        bt      sa_n
        mov.w   @(4,r4),r0          ! source x + extent = next source x
        and     r1,r0
        add     r3,r0
        mov     r0,r2
        mov.w   @(4,r12),r0
        and     r1,r0
        cmp/eq  r2,r0
        bf      sa_n
        mov.w   sa_fff,r1           ! same source row
        mov.w   @(6,r4),r0
        and     r1,r0
        mov     r0,r2
        mov.w   @(6,r12),r0
        and     r1,r0
        cmp/eq  r2,r0
        bf      sa_n
sa_pz:
        mov.w   @(8,r4),r0          ! native x (up)
        sub     r6,r0
        mov     r0,r9
        mov.w   @(12,r4),r0
        mov.w   sa_1fff,r1
        and     r1,r0
        add     #1,r0
        add     r9,r0
        mov     r0,r10              ! up .. r10
        mov.w   @(10,r4),r0         ! native y (game x)
        sub     r7,r0
        mov     r0,r11
        mov.w   @(14,r4),r0
        mov.w   sa_fff,r1
        and     r1,r0
        add     #1,r0
        add     r11,r0
        mov     r0,r13              ! x .. r13
        mov     r11,r0              ! piece centre: x (r0), up (r1)
        add     r13,r0
        shar    r0
        mov     r9,r1
        add     r10,r1
        shar    r1
        mov     r14,r3
        add     #116,r3             ! node centres: arm 0 x, up, arm 1 x, up
        mov.l   @r3,r2
        sub     r0,r2
        cmp/pz  r2
        bt      1f
        neg     r2,r2
1:      mov.l   @(4,r3),r12
        sub     r1,r12
        cmp/pz  r12
        bt      1f
        neg     r12,r12
1:      add     r12,r2              ! distance to arm 0
        mov.l   @(8,r3),r12
        sub     r0,r12
        cmp/pz  r12
        bt      1f
        neg     r12,r12
1:      mov.l   @(12,r3),r0
        sub     r1,r0
        cmp/pz  r0
        bt      1f
        neg     r0,r0
1:      add     r0,r12              ! distance to arm 1
        cmp/gt  r2,r12
        bt      3f                  ! arm 0 nearer
        mov     r12,r2
        bra     4f
        mov     #1,r12
3:      mov     #0,r12
4:      mov.w   sa_near,r0          ! too far from both arms: not an arm piece
        cmp/gt  r0,r2
        bt      sa_n
        mov     r14,r2
        mov     r14,r3
        tst     r12,r12
        bt      1f
        add     #28,r2              ! arm 1
        add     #92,r3
        bra     2f
        nop
1:      add     #76,r3              ! arm 0
2:      add     #20,r2
        mov.l   @(8,r2),r0          ! dead: hide this piece
        tst     r0,r0
        bt      3f
        mov.w   sa_hide,r0
        bra     sa_n
        mov.w   r0,@(8,r4)
3:      mov.l   @r3,r0              ! grow the box
        cmp/gt  r9,r0
        bf      4f
        mov.l   r9,@r3
4:      mov.l   @(4,r3),r0
        cmp/gt  r0,r10
        bf      5f
        mov.l   r10,@(4,r3)
5:      mov.l   @(8,r3),r0
        cmp/gt  r11,r0
        bf      6f
        mov.l   r11,@(8,r3)
6:      mov.l   @(12,r3),r0
        cmp/gt  r0,r13
        bf      sa_n
        mov.l   r13,@(12,r3)
sa_n:   bra     sa_l
        add     #20,r4
        .align 1
sa_1fff:  .word 0x1FFF
sa_fff:   .word 0x0FFF
sa_le:  ! each arm: a destroyed one (boss alive) cancels the bullets near it
        mov     #0,r9
sa_a:   mov     r9,r0
        mov     #28,r1
        mul.l   r1,r0
        sts     macl,r10
        add     r14,r10
        add     #20,r10             ! r10 = arm
        mov     r9,r0               ! bar in the middle of the arm's picture, when it was seen
        shll2   r0                  ! (else it stays at the hit node)
        shll2   r0
        mov     r14,r11
        add     #76,r11
        add     r0,r11              ! r11 = picture box (min up, max up, min x, max x)
        mov.l   @r11,r0
        mov.l   @(4,r11),r1
        cmp/gt  r0,r1
        bf      1f
        add     r1,r0
        shll16  r0
        shar    r0
        mov.l   r0,@(20,r10)        ! centre up 16.16
        mov.l   @(8,r11),r0
        mov.l   @(12,r11),r1
        add     r1,r0
        shll16  r0
        shar    r0
        mov.l   r0,@(16,r10)        ! centre x 16.16
1:      mov.l   @(8,r10),r0
        tst     r0,r0
        bt      sa_an
        mov.w   sa_bhp,r0
        mov.l   @(r0,r8),r0
        cmp/pl  r0
        bf      sa_an
        mov.l   r9,@-r15
        bsr     sa_bul
        nop
        mov.l   @r15+,r9
sa_an:  add     #1,r9
        mov     r9,r0
        cmp/eq  #2,r0
        bf      sa_a
sa_ret: ! bar / explosion count for the gate
        mov     #0,r1
        mov     r14,r2
        add     #20,r2
        mov     #2,r3
1:      mov.l   @(4,r2),r0
        or      r0,r1
        mov.l   @(12,r2),r0
        or      r0,r1
        dt      r3
        bf/s    1b
        add     #28,r2
.ifdef DIAG_S4
        mov     #1,r0               ! diagnostic: keep the bar pass running
        or      r0,r1
.endif
        mov.l   r1,@(4,r14)
        mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
sa_off: mov     #0,r0
        mov.l   r0,@r14
        mov.l   r0,@(16,r14)
        mov.l   r0,@(8,r14)
        mov.l   r0,@(12,r14)
        bra     sa_ret
        nop

! cancel flying bullets within 40 px of arm r10 (player 0x0C5F9970)
sa_bul: sts.l   pr,@-r15
        mov.l   sa_bmgr,r9
        mov.l   @r9,r9
        tst     r9,r9
        bt      sb_r
        mov.l   sa_mgroff,r0
        add     r0,r9
        mov.l   @(28,r9),r0
        tst     r0,r0
        bt      sb_r
        mov.l   @(20,r9),r9
        mov.l   sa_player,r8
        mov     #0,r11
sb_l:   tst     r9,r9
        bt      sb_r
        mov.l   @r9,r0
        cmp/eq  #2,r0
        bf      sb_n
        mov.l   @(44,r9),r1
        mov.l   @(16,r10),r0
        sub     r0,r1
        cmp/pz  r1
        bt      1f
        neg     r1,r1
1:      mov.l   sa_rad,r2
        cmp/gt  r2,r1
        bt      sb_n
        mov.l   @(48,r9),r1
        mov.l   @(20,r10),r0
        sub     r0,r1
        cmp/pz  r1
        bt      2f
        neg     r1,r1
2:      cmp/gt  r2,r1
        bt      sb_n
        mov.l   sa_cancel,r0
        jsr     @r0
        nop
sb_n:   bra     sb_l
        mov.l   @(4,r9),r9
sb_r:   mov.l   sa_bossw,r8         ! restore r8 = boss work for the caller
        mov.l   @r8,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
sa_near:  .word 160               ! max |dx| + |dup| from the arm node (px)
sa_hide:  .word -16384
sa_bhp:   .word 0x98C              ! boss body HP
        .align 2
sa_bigl:  .long 30000
sa_smalll: .long -30000
sa_bossw: .long s4_v
sa_lbase: .long 0x0C1D1454
sa_lp:    .long 0x0C1D1460
sa_bmgr:  .long 0x0C4C8978
sa_mgroff: .long 0x00030DFC
sa_player: .long 0x0C5F9970
sa_rad:   .long 0x00280000         ! 40 px
sa_cancel: .long nc_cancel

! arm hit routines (r4 = hit entry, r5, r6 = boss object; r7 = arm)
        .global s4_hitl
s4_hitl: bra    s4_hit
        mov     #0,r7
        .global s4_hitr
s4_hitr: mov    #1,r7
s4_hit: mov.l   sh4_bw,r0           ! phase 1 (arms docked): the game's own routine
        mov.l   @r0,r0
        mov.l   sh4_ph,r1
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bf      s4_hit2
        tst     r7,r7
        mov.l   sh4_f6,r0
        bt      1f
        mov.l   sh4_f7,r0
1:      jmp     @r0
        nop
s4_hit2:
.ifdef DIAG_S4
        mov.l   sh4_dgh,r0          ! diagnostic: hit calls per arm
        mov     r7,r1
        shll2   r1
        add     r1,r0
        mov.l   @r0,r1
        add     #1,r1
        mov.l   r1,@r0
.endif
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r7,r9
        mov     r4,r10
        mov     #28,r0
        mul.l   r9,r0
        sts     macl,r8
        mov.l   sh4_v,r0
        add     r0,r8
        add     #20,r8              ! r8 = arm
        mov.l   @(8,r8),r0
        tst     r0,r0
        bt      1f
        bra     sh4_r
        mov     #0,r0               ! destroyed: no hit
1:      mov     #BAR_TIME,r0
        mov.l   r0,@(4,r8)
        mov.l   @r8,r1
        mov.l   @(4,r10),r2
        sub     r2,r1
        cmp/pl  r1
        bt      sh4_hurt
        mov     #0,r1
        mov.l   r1,@r8
        mov     #1,r0
        mov.l   r0,@(8,r8)          ! destroyed
        mov     #S4_EXT,r0
        mov.l   r0,@(12,r8)
        mov     r8,r7               ! bonus at the arm
        add     #16,r7
        mov     r10,r5
        mov.l   sh4_bonus,r6
        mov.l   sh4_bfn,r0
        jsr     @r0
        nop
        mov     #0,r4
        mov.l   sh4_sfx,r0
        jsr     @r0
        mov     #2,r5
        bra     sh4_r
        mov     #1,r0
sh4_hurt:
        mov.l   r1,@r8
        mov     r10,r4              ! the game's flash (its own routine for this row)
        mov     r9,r0
        tst     r0,r0
        mov.l   sh4_f6,r0
        bt      2f
        mov.l   sh4_f7,r0
2:      jsr     @r0                 ! (its result is returned)
        nop
sh4_r:  mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
sh4_v:     .long s4_v
sh4_bonus: .long 100000
sh4_bfn:   .long 0x0C2037B0
sh4_sfx:   .long 0x0C281F00
sh4_f6:    .long 0x0C2D58D0        ! row 3 (arm 0)
sh4_f7:    .long 0x0C2D5830        ! row 2 (arm 1)
.ifdef DIAG_S4
sh4_dgh:   .long s4_dgh
.endif
sh4_bw:    .long 0x0C661BC0 + 0x21CC
sh4_ph:    .long 0xF9C

! from bar_draw (r13 kept), atlas uploaded: arm bars and explosions
        .global s4_draw
s4_draw:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
.ifdef DIAG_S4
        mov.l   sd4_dg,r0
        jsr     @r0
        nop
.endif
        mov.l   sd4_v,r14
        mov.l   @r14,r0
        tst     r0,r0
        bt      sd4_r
        add     #20,r14
        mov     #2,r13
sd4_l:  mov.l   @(4,r14),r0         ! bar
        tst     r0,r0
        bt      sd4_ex
        add     #-1,r0
        mov.l   r0,@(4,r14)
        mov.l   @(8,r14),r0
        tst     r0,r0
        bf      sd4_ex
        mov.l   @(24,r14),r0
        tst     r0,r0
        bt      sd4_ex
        mov.l   @(20,r14),r9
        shlr16  r9
        exts.w  r9,r9
        mov.l   @(16,r14),r11
        shlr16  r11
        exts.w  r11,r11
        mov.l   @r14,r10
        mov.l   sd4_hp,r8
        mov.l   sd4_bar,r0
        jsr     @r0
        nop
sd4_ex: mov.l   @(12,r14),r0        ! explosion
        tst     r0,r0
        bt      sd4_n
        add     #-1,r0
        mov.l   r0,@(12,r14)
        mov     #S4_EXT-1,r2
        sub     r0,r2
        shlr2   r2
        shll2   r2
        shll    r2
        mov.l   sd4_exa,r3
        add     r2,r3
        mov.w   @r3+,r4
        mov.w   @r3+,r5
        mov.w   @r3+,r1
        mov.w   @r3,r2
        mov.l   @(20,r14),r9
        shlr16  r9
        exts.w  r9,r9
        mov.l   @(16,r14),r11
        shlr16  r11
        exts.w  r11,r11
        mov     r1,r0
        shlr    r0
        mov     r9,r6
        sub     r0,r6
        mov     r2,r0
        shlr    r0
        mov     r11,r7
        sub     r0,r7
        mov.l   sd4_spr,r0
        jsr     @r0
        nop
sd4_n:  dt      r13
        bf/s    sd4_l
        add     #28,r14
sd4_r:  mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
        .align 2
sd4_v:   .long s4_v
sd4_hp:  .long S4_AHP
sd4_bar: .long bd_bar
sd4_spr: .long bd_spr
sd4_exa: .long s4_ex
.ifdef DIAG_S4
sd4_dg:  .long s4_diag
.endif
s4_ex:   .word 1351, 1791, 88, 95       ! explosion pictures in VRAM (x, y, w, h)
         .word 1599, 1791, 98, 103
         .word 1699, 1791, 94, 100
         .word 1820, 1791, 100, 110
         .word 2307, 1791, 123, 126
         .word 2439, 1791, 119, 122
        .align 2
s4_v:    .space 132

! ================================================================ stage 5 boss floating weapons (breakable)
! The six weapons are objects of their own (work: +8 boss, +0xC x, +0x10 up 16.16, +0x14 hit node,
! +0x18 number 0-5). Their hit routine 0x0C2F5640 only flashes the boss. Each frame the hit node of
! every weapon gets s5_hit instead: each weapon has S5_WHP of its own, a bar, and at 0 gives 100,000,
! the explosion sound and an explosion; then its sprites are hidden, it takes no more hits and bullets
! near it are cancelled. Boss HP is not touched.
        .equ S5_WHP,    16384
        ! s5_v: +0 boss, +4 count, +8 weapons 6 x 32 (hp, timer, dead, ex, x, up, work, seen)
        .global s5_frame
s5_frame:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
        mov.l   s5f_v,r14
        mov     #0,r0
        mov     r14,r1
        add     #8,r1
        mov     #6,r2
1:      mov.l   r0,@(28,r1)         ! not seen yet this frame
        dt      r2
        bf/s    1b
        add     #32,r1
        .equ S5_WEAPONS, 0              ! 0 = stage 5 boss as in the original game (weapons code off)
.if S5_WEAPONS == 0
        bra     s5f_cnt
        nop
.endif
        mov.l   s5f_stage,r0
        mov.l   @r0,r0
        cmp/eq  #4,r0
        bf      s5f_cnt
        mov.l   s5f_obj,r11         ! object slots
        mov     #68,r10
s5f_l:  mov.l   s5f_wo,r0
        mov.l   @(r0,r11),r8        ! work
        mov.l   s5f_wlo,r1
        cmp/hs  r1,r8
        bf      s5f_n
        mov.l   s5f_whi,r1
        cmp/hs  r1,r8
        bt      s5f_n
        mov.l   @r8,r0
        cmp/eq  r11,r0
        bf      s5f_n
        mov.l   @(20,r8),r9         ! hit node
        mov.l   s5f_nlo,r1
        cmp/hs  r1,r9
        bf      s5f_n
        mov.l   s5f_nhi,r1
        cmp/hs  r1,r9
        bt      s5f_n
        mov.l   @(16,r9),r0         ! routine: original or ours
        mov.l   s5f_orig,r1
        cmp/eq  r1,r0
        bt      s5f_ok
        mov.l   s5f_new,r1
        cmp/eq  r1,r0
        bf      s5f_n
s5f_ok: mov.l   s5f_new,r1
        mov.l   r1,@(16,r9)
        mov.l   @(24,r8),r0         ! number 0-5
        cmp/hs  r0,r0
        mov     #6,r1
        cmp/hs  r1,r0
        bt      s5f_n
        mov.l   @(8,r8),r2          ! boss: a new fight resets all six
        mov.l   @r14,r3
        cmp/eq  r2,r3
        bt      s5f_same
        mov.l   r2,@r14
        mov     r14,r3
        add     #8,r3
        mov     #6,r4
        mov.l   s5f_hp,r5
        mov     #0,r6
2:      mov.l   r5,@r3
        mov.l   r6,@(4,r3)
        mov.l   r6,@(8,r3)
        mov.l   r6,@(12,r3)
        dt      r4
        bf/s    2b
        add     #32,r3
s5f_same:
        shll2   r0
        shll2   r0
        shll    r0                  ! * 32
        mov     r14,r3
        add     #8,r3
        add     r0,r3               ! r3 = weapon
        mov.l   r8,@(24,r3)
        mov     #1,r0
        mov.l   r0,@(28,r3)
        mov.l   @(8,r3),r0          ! destroyed: keep its last position (hide / bullets)
        tst     r0,r0
        bf      s5f_n
        mov.l   @(12,r8),r0
        mov.l   r0,@(16,r3)
        mov.l   @(16,r8),r0
        mov.l   r0,@(20,r3)
s5f_n:  mov.l   s5f_stride,r0
        add     r0,r11
        dt      r10
        bf      s5f_l
        ! destroyed weapons: hide their sprites, cancel bullets near them
        mov     #0,r13
s5f_d:  mov     r13,r0
        shll2   r0
        shll2   r0
        shll    r0
        mov     r14,r10
        add     #8,r10
        add     r0,r10
        mov.l   @(8,r10),r0
        tst     r0,r0
        bt      s5f_dn
        mov.l   @(28,r10),r0
        tst     r0,r0
        bt      s5f_dn
        bsr     s5_hide
        nop
        bsr     s5_bul
        nop
s5f_dn: add     #1,r13
        mov     r13,r0
        cmp/eq  #6,r0
        bf      s5f_d
s5f_cnt:
        mov     #0,r1
        mov     r14,r2
        add     #8,r2
        mov     #6,r3
3:      mov.l   @(4,r2),r0
        or      r0,r1
        mov.l   @(12,r2),r0
        or      r0,r1
        dt      r3
        bf/s    3b
        add     #32,r2
        mov.l   r1,@(4,r14)
        mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
        .align 2
s5f_v:     .long s5_v
s5f_stage: .long 0x0C31DFDC
s5f_obj:   .long 0x0C661BC0
s5f_wo:    .long 0x21CC
s5f_wlo:   .long 0x0C700000
s5f_whi:   .long 0x0CA00000
s5f_nlo:   .long 0x0C800000
s5f_nhi:   .long 0x0CA00000
s5f_orig:  .long 0x0C2F5640
s5f_new:   .long s5_hit
s5f_hp:    .long S5_WHP
s5f_stride: .long EN_STRIDE

! weapon r10: move this frame's draws centred within 20 px of it (size <= 64, not HUD) off screen
s5_hide:
        mov.l   s5h_lbase,r1
        mov.l   @r1,r4
        mov.l   s5h_lp,r1
        mov.l   @r1,r5
        mov.l   @(4,r1),r6
        shlr16  r6
        exts.w  r6,r6
        mov.l   @(8,r1),r7
        mov.l   @(20,r10),r8        ! weapon up -> native x (+ origin)
        shlr16  r8
        exts.w  r8,r8
        add     r6,r8
        mov.l   @(16,r10),r9        ! weapon x -> native y (+ origin)
        shlr16  r9
        exts.w  r9,r9
        add     r7,r9
5:      cmp/hs  r5,r4
        bt      9f
        mov.l   @r4,r0
        cmp/eq  #-1,r0
        bt      9f
        shlr16  r0
        shlr8   r0
        shlr2   r0
        shlr2   r0
        cmp/eq  #1,r0
        bt      6f
        cmp/eq  #2,r0
        bt      7f
        bra     5b
        add     #4,r4
7:      mov.w   @(12,r4),r0
        mov.w   s5h_1fff,r1
        and     r1,r0
        add     #1,r0
        mov     r0,r2
        mov.w   @(14,r4),r0
        mov.w   s5h_fff,r1
        and     r1,r0
        add     #1,r0
        mul.l   r2,r0
        sts     macl,r0
        add     r0,r0
        add     #16,r0
        bra     5b
        add     r0,r4
6:      mov.w   @(6,r4),r0          ! not the HUD row
        mov.w   s5h_fff,r1
        and     r1,r0
        mov.w   s5h_256,r1
        cmp/hs  r1,r0
        bf      8f
        mov.w   @(12,r4),r0
        mov.w   s5h_1fff,r1
        and     r1,r0
        add     #1,r0
        mov     r0,r2               ! w
        mov     #64,r1
        cmp/gt  r1,r2
        bt      8f
        mov.w   @(14,r4),r0
        mov.w   s5h_fff,r1
        and     r1,r0
        add     #1,r0
        mov     r0,r3               ! h
        mov     #64,r1
        cmp/gt  r1,r3
        bt      8f
        mov.w   @(8,r4),r0
        shlr    r2
        add     r0,r2               ! centre native x
        sub     r8,r2
        cmp/pz  r2
        bt      1f
        neg     r2,r2
1:      mov     #20,r1
        cmp/gt  r1,r2
        bt      8f
        mov.w   @(10,r4),r0
        shlr    r3
        add     r0,r3
        sub     r9,r3
        cmp/pz  r3
        bt      2f
        neg     r3,r3
2:      cmp/gt  r1,r3
        bt      8f
        mov.w   s5h_off,r0
        mov.w   r0,@(8,r4)
8:      bra     5b
        add     #20,r4
9:      rts
        nop
        .align 1
s5h_1fff: .word 0x1FFF
s5h_fff:  .word 0x0FFF
s5h_256:  .word 256
s5h_off:  .word -16384
        .align 2
s5h_lbase: .long 0x0C1D1454
s5h_lp:    .long 0x0C1D1460

! weapon r10: cancel flying bullets within 24 px of it (player 0x0C5F9970)
s5_bul: sts.l   pr,@-r15
        mov.l   s5b_bmgr,r9
        mov.l   @r9,r9
        tst     r9,r9
        bt      4f
        mov.l   s5b_mgroff,r0
        add     r0,r9
        mov.l   @(28,r9),r0
        tst     r0,r0
        bt      4f
        mov.l   @(20,r9),r9
        mov.l   s5b_player,r8
        mov     #0,r11
1:      tst     r9,r9
        bt      4f
        mov.l   @r9,r0
        cmp/eq  #2,r0
        bf      3f
        mov.l   @(44,r9),r1
        mov.l   @(16,r10),r0
        sub     r0,r1
        cmp/pz  r1
        bt      2f
        neg     r1,r1
2:      mov.l   s5b_rad,r2
        cmp/gt  r2,r1
        bt      3f
        mov.l   @(48,r9),r1
        mov.l   @(20,r10),r0
        sub     r0,r1
        cmp/pz  r1
        bt      5f
        neg     r1,r1
5:      cmp/gt  r2,r1
        bt      3f
        mov.l   s5b_cancel,r0
        jsr     @r0
        nop
3:      bra     1b
        mov.l   @(4,r9),r9
4:      lds.l   @r15+,pr
        rts
        nop
        .align 2
s5b_bmgr:   .long 0x0C4C8978
s5b_mgroff: .long 0x00030DFC
s5b_player: .long 0x0C5F9970
s5b_rad:    .long 0x00180000
s5b_cancel: .long nc_cancel

! weapon hit routine (r4 = hit entry, r5, r6 = weapon object)
        .global s5_hit
s5_hit: sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r4,r10
        mov.l   s5x_wo,r0
        mov.l   @(r0,r6),r9         ! weapon work
        mov.l   @(24,r9),r0
        mov     #6,r1
        cmp/hs  r1,r0
        bt      s5x_orig
        shll2   r0
        shll2   r0
        shll    r0
        mov.l   s5x_v,r8
        add     #8,r8
        add     r0,r8               ! weapon entry
        mov.l   @(8,r8),r0
        tst     r0,r0
        bt      1f
        bra     s5x_r
        mov     #0,r0               ! destroyed: no hit
1:      mov     #BAR_TIME,r0
        mov.l   r0,@(4,r8)
        mov.l   @r8,r1
        mov.l   @(4,r10),r2
        sub     r2,r1
        cmp/pl  r1
        bt      s5x_hurt
        mov     #0,r1
        mov.l   r1,@r8
        mov     #1,r0
        mov.l   r0,@(8,r8)
        mov     #S4_EXT,r0
        mov.l   r0,@(12,r8)
        mov     r9,r7               ! bonus at the weapon
        add     #12,r7
        mov     r10,r5
        mov.l   s5x_bonus,r6
        mov.l   s5x_bfn,r0
        jsr     @r0
        nop
        mov     #0,r4
        mov.l   s5x_sfx,r0
        jsr     @r0
        mov     #2,r5
        bra     s5x_r
        mov     #1,r0
s5x_hurt:
        mov.l   r1,@r8
s5x_orig:
        mov     r10,r4              ! the game's own routine (flashes the boss)
        mov.l   s5x_fn,r0
        jsr     @r0
        nop
        mov     #1,r0
s5x_r:  mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
s5x_wo:    .long 0x21CC
s5x_v:     .long s5_v
s5x_bonus: .long 100000
s5x_bfn:   .long 0x0C2037B0
s5x_sfx:   .long 0x0C281F00
s5x_fn:    .long 0x0C2F5640

! from bar_draw (r13 kept), atlas uploaded: weapon bars and explosions
        .global s5_draw
s5_draw:
        sts.l   pr,@-r15
        mov.l   r13,@-r15
        mov.l   s5d_v,r14
        add     #8,r14
        mov     #6,r13
s5d_l:  mov.l   @(4,r14),r0
        tst     r0,r0
        bt      s5d_ex
        add     #-1,r0
        mov.l   r0,@(4,r14)
        mov.l   @(8,r14),r0
        tst     r0,r0
        bf      s5d_ex
        mov.l   @(28,r14),r0
        tst     r0,r0
        bt      s5d_ex
        mov.l   @(20,r14),r9
        shlr16  r9
        exts.w  r9,r9
        mov.l   @(16,r14),r11
        shlr16  r11
        exts.w  r11,r11
        mov.l   @r14,r10
        mov.l   s5d_hp,r8
        mov.l   s5d_bar,r0
        jsr     @r0
        nop
s5d_ex: mov.l   @(12,r14),r0
        tst     r0,r0
        bt      s5d_n
        add     #-1,r0
        mov.l   r0,@(12,r14)
        mov     #S4_EXT-1,r2
        sub     r0,r2
        shlr2   r2
        shll2   r2
        shll    r2
        mov.l   s5d_exa,r3
        add     r2,r3
        mov.w   @r3+,r4
        mov.w   @r3+,r5
        mov.w   @r3+,r1
        mov.w   @r3,r2
        mov.l   @(20,r14),r9
        shlr16  r9
        exts.w  r9,r9
        mov.l   @(16,r14),r11
        shlr16  r11
        exts.w  r11,r11
        mov     r1,r0
        shlr    r0
        mov     r9,r6
        sub     r0,r6
        mov     r2,r0
        shlr    r0
        mov     r11,r7
        sub     r0,r7
        mov.l   s5d_spr,r0
        jsr     @r0
        nop
s5d_n:  dt      r13
        bf/s    s5d_l
        add     #32,r14
        mov.l   @r15+,r13
        lds.l   @r15+,pr
        rts
        nop
        .align 2
s5d_v:   .long s5_v
s5d_hp:  .long S5_WHP
s5d_bar: .long bd_bar
s5d_spr: .long bd_spr
s5d_exa: .long s4_ex
s5_v:    .space 8 + 6 * 32

! ================================================================ 1up: cancel bullets into stars
! Per frame (r4 = player): when the lives counter (byte 0x0C5F9973) goes up - a 1up picked up -
! every bullet is cancelled into big stars (the same call as the bomb item pickup).
        .global up_frame
up_frame:
        sts.l   pr,@-r15
        mov.l   up_lives,r1
        mov.b   @r1,r0
        extu.b  r0,r0
        mov.l   up_last,r1
        mov.l   @r1,r2
        mov.l   r0,@r1
        cmp/gt  r2,r0
        bf      1f
        mov     r4,r5               ! lives went up
        mov     #32,r4
        mov.l   up_cancel,r0
        jsr     @r0
        mov     #1,r6
1:      lds.l   @r15+,pr
        rts
        nop
        .align 2
up_lives:  .long 0x0C5F9973
up_last:   .long up_v
up_cancel: .long CANCEL
up_v:      .long 0


.ifdef DIAG_S4
! ================================================================ stage 4 arms diagnostic overlay
! Rows of numbers (bar digits, '%' between values) at the bottom left:
!  1: frames, boss found, phase 2, barrier, bar/explosion count, [0x0C4C897C]
!  2/3 (arm 0 / arm 1): node found, HP, bar timer, destroyed, seen, x+500, up+500, hit calls
s4_diag:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   dg_v,r8
        mov.l   dg_fr,r1            ! frame counter
        mov.l   @r1,r10
        add     #1,r10
        mov.l   r10,@r1
        mov     #76,r9              ! row 1 (native x = game up)
        mov     #4,r11
        bsr     dg_num
        nop
        mov.l   @r8,r0              ! boss found
        bsr     dg_flag
        nop
        mov.l   @r8,r1              ! phase 2, barrier
        mov     #0,r10
        tst     r1,r1
        bt      1f
        mov.l   dg_ph,r0
        mov.l   @(r0,r1),r10
1:      bsr     dg_num
        nop
        mov.l   @r8,r1
        mov     #0,r10
        tst     r1,r1
        bt      1f
        mov.l   dg_ph8,r0
        mov.l   @(r0,r1),r10
1:      bsr     dg_num
        nop
        mov.l   @(4,r8),r10         ! count
        bsr     dg_num
        nop
        mov.l   dg_stg,r0           ! the value the patch uses as "current stage" (0x0C4C897C)
        mov.l   @r0,r10
        bsr     dg_num
        nop
        mov     #0,r12              ! arms
dg_arm: mov     r12,r0
        mov     #14,r1
        mul.l   r1,r0
        sts     macl,r0
        mov     #62,r9
        sub     r0,r9               ! row 2 / 3
        mov     #4,r11
        mov     r12,r0
        shll2   r0
        add     r8,r0
        mov.l   @(8,r0),r0          ! node found
        bsr     dg_flag
        nop
        mov     r12,r0
        mov     #28,r1
        mul.l   r1,r0
        sts     macl,r13
        add     r8,r13
        add     #20,r13             ! r13 = arm
        mov.l   @r13,r10            ! hp
        bsr     dg_num
        nop
        mov.l   @(4,r13),r10        ! bar timer
        bsr     dg_num
        nop
        mov.l   @(8,r13),r10        ! destroyed
        bsr     dg_num
        nop
        mov.l   @(24,r13),r10       ! seen
        bsr     dg_num
        nop
        mov.l   @(16,r13),r10       ! x + 500
        shlr16  r10
        exts.w  r10,r10
        mov.w   dg_500,r0
        add     r0,r10
        bsr     dg_num
        nop
        mov.l   @(20,r13),r10       ! up + 500
        shlr16  r10
        exts.w  r10,r10
        mov.w   dg_500,r0
        add     r0,r10
        bsr     dg_num
        nop
        mov.l   dg_hits,r0          ! hit calls
        mov     r12,r1
        shll2   r1
        mov.l   @(r0,r1),r10
        bsr     dg_num
        nop
        add     #1,r12
        mov     r12,r0
        cmp/eq  #2,r0
        bf      dg_arm
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! r0 -> 0 / 1, drawn like dg_num
dg_flag:
        tst     r0,r0
        movt    r10
        mov     #1,r0
        xor     r0,r10
! r10 (unsigned, < 65536) in decimal at native (r9, r11), then '%'; r11 moves on. Keeps r8, r9, r12.
dg_num:
        sts.l   pr,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   dg_c65,r0           ! clamp (the subtraction divide is slow)
        cmp/hi  r0,r10
        bf      1f
        mov     r0,r10
1:      mov     r15,r12             ! digit buffer below the stack
        add     #-8,r15
        mov     r12,r13
2:      mov     r10,r0
        mov     #10,r1
        mov.l   dg_div,r2
        jsr     @r2
        nop
        mov     r0,r1
        mov     #10,r2
        mul.l   r1,r2
        sts     macl,r2
        mov     r10,r3
        sub     r2,r3
        mov     r1,r10
        add     #2,r3               ! digit piece
        add     #-1,r13
        mov.b   r3,@r13
        tst     r10,r10
        bf      2b
3:      cmp/hs  r12,r13
        bt      4f
        mov.b   @r13+,r0
        bsr     dg_gl
        nop
        bra     3b
        nop
4:      mov     #12,r0              ! '%' as separator
        bsr     dg_gl
        nop
        add     #8,r15
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        lds.l   @r15+,pr
        rts
        nop
! piece r0 at native (r9, r11); r11 += its height
dg_gl:  sts.l   pr,@-r15
        mov.l   dg_pc,r1
        jsr     @r1
        nop
        mov     r9,r6
        mov     r11,r7
        add     r2,r11
        mov.l   dg_sp,r0
        jsr     @r0
        nop
        lds.l   @r15+,pr
        rts
        nop
        .align 2
dg_v:    .long s4_v
dg_fr:   .long s4_dgf
dg_hits: .long s4_dgh
dg_ph:   .long 0xF9C
dg_ph8:  .long 0x8C
dg_div:  .long udiv
dg_pc:   .long bd_piece
dg_sp:   .long bd_spr
dg_c65:  .long 65535
dg_stg:  .long 0x0C4C897C
dg_500:  .word 500
        .align 2
s4_dgf:  .long 0
s4_dgh:  .long 0, 0
.endif

! ================================================================ hidden bee % (1.5+ chart)
! The bee pickup gives hits / 50 percent (capped, now at 100 by a boot patch) of a full meter.
! 1.5+: 0-200 hits 0 %, then +1 % per 200 hits, 100 % from 20,000 hits (Ver 1.5 chart).
! Every other mode: the hit count is capped at 1500, which gives the original 30 % cap.
        .global bee_hits
bee_hits:
        sts.l   pr,@-r15
        mov.l   bh_get,r0
        jsr     @r0
        nop
        mov.l   bh_vars,r1
        mov.l   @(4,r1),r1
        mov     r1,r2
        mov     #1,r3
        cmp/eq  r3,r2
        bt      bh_15
        mov.w   bh_1500,r1          ! original: same result as the 30 % cap
        cmp/gt  r1,r0
        bf      bh_r
        bra     bh_r
        mov     r1,r0
bh_15:  cmp/pl  r0
        bf      bh_0
        add     #-1,r0              ! (hits - 1) / 200 percent, at most 100
        mov.w   bh_200,r1
        mov.l   bh_div,r2
        jsr     @r2
        nop
        mov     #100,r1
        cmp/gt  r1,r0
        bf      1f
        mov     r1,r0
1:      mov     #50,r1              ! back to "hits" for the game's / 50: percent * 50
        mulu.w  r0,r1
        bra     bh_r
        sts     macl,r0
bh_0:   mov     #0,r0
bh_r:   lds.l   @r15+,pr
        rts
        nop
        .align 2
bh_get:  .long 0x0C1F8C60           ! game: player combo hits
bh_vars: .long v_mode
bh_div:  .long udiv
bh_1500: .word 1500
bh_200:  .word 200

! ================================================================ bomb maximum bonus (Ver 1.5)
! Picking up a bomb with full stock starts the bomb maximum bonus (player +0x33C block: +20 on,
! +32 per-tick base 2,222, +36 level). The game adds base x level to the score every few frames.
! 1.5+ / Power / Omake: base = 2,222 x (rank / 5 + 1), rank as shown on the HUD (1.5+: the game's
! rank; Power / Omake: their real rank). Original Arcade keeps 2,222.
        .global bmb_frame
bmb_frame:
        mov.l   bm_vars,r1
        mov.l   @(4,r1),r0          ! selected mode
        tst     r0,r0
        bt      bm_ret
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      bm_ret              ! not patched in
        sts.l   pr,@-r15
        cmp/eq  #1,r0
        mov.l   bm_rank15,r2        ! 1.5+: the game's HUD rank
        bt      1f
        mov     r1,r2
        add     #60,r2              ! Power / Omake: v_hudrank
1:      mov.l   @r2,r0
        cmp/pz  r0
        bt      2f
        mov     #0,r0
2:      mov     #5,r1
        mov.l   bm_div,r2
        jsr     @r2
        nop
        add     #1,r0
        mov.w   bm_2222,r1
        mulu.w  r0,r1
        sts     macl,r4             ! base = 2,222 x (rank / 5 + 1)
        mov.l   bm_p1,r5
        mov     #2,r6               ! both players
3:      mov.w   bm_33c,r0
        mov     r5,r1
        add     r0,r1
        mov.l   @(20,r1),r0         ! bonus running?
        tst     r0,r0
        bt      4f
        mov.l   r4,@(32,r1)
4:      mov.w   bm_3c8,r0
        add     r0,r5
        dt      r6
        bf      3b
        lds.l   @r15+,pr
bm_ret: rts
        nop
        .align 2
bm_vars:   .long v_mode
bm_rank15: .long 0x0C661B48         ! game: rank shown on the HUD
bm_div:    .long udiv
bm_p1:     .long 0x0C5F9970         ! player 1 (player 2 = +0x3C8)
bm_2222:   .word 2222
bm_33c:    .word 0x33C
bm_3c8:    .word 0x3C8

! ================================================================ big stars in hyper
! A cancelled bullet (state 3) turns into a star; its size is bullet +0x50 (0 small, 1 big).
! Each frame, while the rule holds, every cancelled bullet is set to big:
!   1.5+: player 1 in a hyper started at HYPER Lv 6 or more (+0x2EC = level at the start)
!   Power / Omake: player 1 in any hyper.   Original Arcade: never.
        .global star_frame
star_frame:
        mov.l   st_vars,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      st_ret              ! not patched in
        mov.l   @(4,r1),r3          ! selected mode
        tst     r3,r3
        bt      st_ret
        mov     r3,r0               ! Power Mode: small stars (not made big here)
        cmp/eq  #2,r0
        bt      st_ret
        mov.l   st_p1,r2
        mov.w   st_2e0,r0
        mov.l   @(r0,r2),r0         ! in hyper?
        tst     r0,r0
        bt      st_ret
        mov     r3,r0
        cmp/eq  #1,r0
        bf      st_go               ! Omake: any hyper
        mov.w   st_2ec,r0
        mov.l   @(r0,r2),r0         ! 1.5+: hyper level at the start
        mov     #6,r1
        cmp/ge  r1,r0
        bf      st_ret
st_go:  mov.l   st_mgr,r0
        mov.l   @r0,r1
        tst     r1,r1
        bt      st_ret
        mov.l   st_30dfc,r2
        add     r2,r1
        mov.l   @(28,r1),r0
        tst     r0,r0
        bt      st_ret
        mov.l   @(20,r1),r2         ! first bullet
        mov     #1,r3
st_l:   tst     r2,r2
        bt      st_ret
        mov.l   @r2,r0              ! state
        cmp/eq  #3,r0
        bf      st_n
        mov     r2,r1
        add     #64,r1
        mov.l   r3,@(16,r1)         ! +0x50 = 1: big star
st_n:   bra     st_l
        mov.l   @(4,r2),r2
st_ret: rts
        nop
        .align 2
st_vars:  .long v_mode
st_p1:    .long 0x0C5F9970
st_mgr:   .long 0x0C4C8978
st_30dfc: .long 0x30DFC
st_2e0:   .word 0x2E0
st_2ec:   .word 0x2EC

! ================================================================ Power Mode: DFK bottom bar
! The DFK Black Label bottom bar (from the files given when patching, u4 0x3B0000: 'DFKB', w 48, h 240,
! pixels at +0x10, native orientation: cols 0-15 the bar; cols 16-30 NORMAL bright / dim (rows 0 / 48),
! BOOST bright / dim (rows 96 / 136); cols 32-47 the MAXIMUM strip) replaces the game's bottom bar and
! bomb icons. Button 4 switches NORMAL / BOOST (nothing else yet); MAXIMUM scrolls behind the words
! while a hyper is stocked.
        .equ DFK_GFX,   0xA03B0000
        .equ DFK_VX,    7600            ! free VRAM next to the health bar atlas (7568-7595, 200-318); 48 wide
        .equ DFK_VY,    200
! upload the atlas into the draw list (called by the bar pass, list open)
! after the game's per-frame sprite flush (0x0C1DE644, run after hud_hook): on the board the game's HUD
! sprites (its bottom bar) reach the draw list only there, so the DFK bar is drawn after it
        .global post_hook
post_hook:
        sts.l   pr,@-r15
        mov.l   ph_flush,r0
        jsr     @r0
        nop
        mov.l   ph_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      9f
        mov.l   r8,@-r15
        mov     #0,r8               ! the list may be closed (0xFFFFFFFF): step back, add ours, close again
        mov.l   ph_lp,r1
        mov.l   @r1,r2
        add     #-4,r2
        mov.l   @r2,r0
        cmp/eq  #-1,r0
        bf      1f
        mov.l   r2,@r1
        mov     #1,r8
1:      mov.l   r13,@-r15           ! r13 -> v_bwork, as hud_find / hud_move use it
        mov.l   r9,@-r15            ! hud_move uses r8-r12
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   ph_vars,r13
        add     #104,r13
        mov.l   ph_hf,r0            ! where the HUD starts (so the DFK bar goes under the words)
        jsr     @r0
        nop
        mov.l   ph_dku,r0
        jsr     @r0
        nop
        mov.l   ph_dkd,r0
        jsr     @r0
        nop
        mov.l   ph_hm,r0            ! move it under the HUD
        jsr     @r0
        nop
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r13
        tst     r8,r8
        bt      2f
        mov.l   ph_lp,r1
        mov.l   @r1,r2
        mov     #-1,r0
        mov.l   r0,@r2
        add     #4,r2
        mov.l   r2,@r1
2:      mov.l   @r15+,r8
9:      lds.l   @r15+,pr
        rts
        nop
        .align 2
ph_flush: .long 0x0C1DE644       ! game: sprite flush
ph_vars:  .long v_mode
ph_lp:    .long 0x0C1D1460
ph_dku:   .long dfk_upload
ph_dkd:   .long dfk_draw
ph_hf:    .long hud_find
ph_hm:    .long hud_move

! Power Mode: "HYPER SYSTEM READY" (game call at 0x0C213CEA: voice r4 = 9, r5 = 70) only once, when the meter
! fills; not again while the stock waits (the gauge raises it), until the stock is used (gauge_draw clears the
! flag when the stock is 0). Every other mode as the original.
        .global ready_hook
ready_hook:
        mov.l   rh_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      2f
        bra     1f                  ! Power Mode: never (our hyper meter, hn_frame, says it)
        nop
        mov.l   rh_p1,r1            ! never during a hyper (the level ups)
        mov.w   rh_2e0,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bf      1f
        mov.l   rh_said,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      1f                  ! already said for this stock
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   rh_ok,r1            ! the banner after it may show too
        mov.l   r0,@r1
2:      mov.l   rh_voice,r0
        jmp     @r0
        nop
1:      mov.l   rh_ok,r1
        mov     #0,r0
        rts
        mov.l   r0,@r1

! Power Mode: the game's ready sequence also plays a chime first (0x0C282860, literal 0x0C213DE8): never from
! there (it repeats while a stock waits); hn_frame plays it once with the voice.
        .global rse_hook
rse_hook:
        mov.l   rh_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts
        nop
8:      mov.l   rh_se,r0
        jmp     @r0
        nop

! Power Mode: the ready sequence's other chime (sound 114, 0x0C282840, loaded at 0x0C2151E2 from literal
! 0x0C215234 and called at 0x0C213CE4): it repeats while a stock waits, so never in Power Mode.
        .global rse2_hook
rse2_hook:
        mov.l   rh_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts
        nop
8:      mov.l   rh_se2,r0
        jmp     @r0
        nop

! Power Mode: the HYPER SYSTEM READY banner (0x0C2778B0, called right after the voice, literal 0x0C213DF0) only
! when ready_hook let the voice play.
        .global rban_hook
rban_hook:
        mov.l   rh_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts                         ! Power Mode: never (hn_frame shows it)
        nop
        mov.l   rh_ok,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      8f
        rts
        nop
8:      mov.l   rh_ban,r0
        jmp     @r0
        nop
        .align 2
rh_vars:  .long v_mode
rh_voice: .long 0x0C276900       ! game: play voice
rh_said:  .long dk_said
rh_ok:    .long dk_rdyok
rh_ban:   .long 0x0C2778B0       ! game: HYPER SYSTEM READY banner
rh_se:    .long 0x0C282860       ! game: hyper ready chime
rh_se2:   .long 0x0C282840       ! game: chime (sound 114)
rh_p1:    .long 0x0C5F9970
rh_2e0:   .word 0x2E0
        .align 2

! Power Mode, BOOST: the ship moves 30% slower (like DFK BL), at its normal and its laser speed. The player
! move (0x0C210828) calls set-position (0x0C1F6960, r4 = player, r5 / r6 = new x / y 16.16); the step from
! the old position (+0xB0 / +0xB4) is cut to 179/256 (0.70).
        .global move_hook
move_hook:
        mov.l   mv_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      9f
        mov.l   mv_b,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      9f
        mov.l   r8,@-r15
        mov     #-8,r8
        mov     r4,r1
        add     #124,r1
        mov.l   @(52,r1),r2         ! old x (+0xB0)
        mov     r5,r0
        sub     r2,r0
        mov.w   mv_179,r3
        mul.l   r3,r0
        sts     macl,r0
        shad    r8,r0
        add     r2,r0
        mov     r0,r5
        mov.l   @(56,r1),r2         ! old y (+0xB4)
        mov     r6,r0
        sub     r2,r0
        mul.l   r3,r0
        sts     macl,r0
        shad    r8,r0
        add     r2,r0
        mov     r0,r6
        mov.l   @r15+,r8
9:      mov.l   mv_set,r0
        jmp     @r0
        nop
        .align 1
mv_179:   .word 179
        .align 2
mv_vars:  .long v_mode
mv_b:     .long dk_boost
mv_set:   .long 0x0C1F6960       ! game: set position

! Power Mode: no operator window. Its routine (0x0C2769B0, called once per frame from 0x0C277FB4) draws the
! window only while 0x0C7D5004 is set; it is cleared just before the routine runs.
        .global oper_hook
oper_hook:
        mov.l   op_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov.l   op_flag,r1
        mov     #0,r0
        mov.l   r0,@r1
1:      mov.l   op_orig,r0
        jmp     @r0
        nop
        .align 2
op_vars:  .long v_mode
op_flag:  .long 0x0C7D5004
op_orig:  .long 0x0C2769B0       ! game: operator window / HUD routine

! Power Mode, gauge at the label level (60% and up): every enemy (slots 4-67; 0-3 are the boss / mid-boss objects) that has
! hit points and is on screen fires a bullet aimed at player 1 every ST_RATE frames (staggered by slot), through
! the game's own bullet spawn (0x0C1FE4B0: r4 type, r5 / r6 x / y 16.16, r7 speed, stack: angle 0-0x1FF (0x100 =
! down the screen), pattern 0, four 0s); it refuses when the bullet list is full.
        .equ ST_RATE,   10              ! streams: one bullet every 10 frames per enemy
        .equ ST_TYPE,   0x29            ! bullet type the stage 1 enemies use
        .equ ST_SPEED,  0x10
        .global stream_frame
stream_frame:
        mov.l   sf_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #3,r0
        bt      sf_omk              ! Omake: grazing, streams during a hyper
        cmp/eq  #2,r0
        bf      9f
        mov.l   sf_play,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      9f
        mov.l   sf_val,r1           ! the gauge at the label level?
        mov.l   @r1,r0
        mov.w   sf_60,r1
        cmp/ge  r1,r0
        bf      9f
sf_go:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   sf_obj,r11          ! slot 4
        mov     #4,r10              ! slot number
1:      mov.w   sf_wo,r0            ! work, pointing back to the object?
        mov.l   @(r0,r11),r12
        mov.l   sf_wlo,r2
        cmp/hs  r2,r12
        bf      8f
        mov.l   sf_whi,r2
        cmp/hs  r2,r12
        bt      8f
        mov.l   @r12,r0
        cmp/eq  r11,r0
        bf      8f
        mov.l   sf_fc,r1            ! staggered: (frame + slot) % ST_RATE == 0
        mov.l   @r1,r0
        add     r10,r0
        mov     #ST_RATE,r1
2:      cmp/hs  r1,r0
        bf      3f
        bra     2b
        sub     r1,r0
3:      tst     r0,r0
        bf      8f
        mov     #3,r6               ! an enemy with hit points (the health bar test: +0x34 = 1, +0x40 in
        mov     r12,r13             ! the hit list, at +0, +4 or +8)
4:      mov     r13,r0
        add     #64,r0
        mov.l   @r0,r0
        mov.l   sf_nlo,r2
        cmp/hs  r2,r0
        bf      5f
        mov.l   sf_nhi,r2
        cmp/hs  r2,r0
        bt      5f
        mov.l   @(52,r13),r0
        cmp/eq  #1,r0
        bt      6f
5:      dt      r6
        bf/s    4b
        add     #4,r13
        bra     8f
        nop
6:      mov.l   @(32,r13),r0        ! HP left
        cmp/pl  r0
        bf      8f
        mov.l   @(4,r12),r8         ! x, y (16.16)
        mov.l   @(8,r12),r9
        cmp/pz  r8                  ! on screen: x 0-240, y 32-352
        bf      8f
        mov.l   sf_xmax,r0
        cmp/gt  r0,r8
        bt      8f
        mov.l   sf_ymin,r0
        cmp/gt  r9,r0
        bt      8f
        mov.l   sf_ymax,r0
        cmp/gt  r0,r9
        bt      8f
        mov.l   sf_p1,r1            ! aim: dx, dy to player 1 (+0xB0 / +0xB4)
        mov     r1,r2
        add     #124,r2
        mov.l   @(52,r2),r4
        sub     r8,r4               ! dx
        mov.l   @(56,r2),r5
        sub     r9,r5               ! dy
        bsr     sf_atan             ! r0 = angle 0-0x1FF
        nop
        add     #-24,r15
        mov.l   r0,@r15             ! angle
        mov.l   sf_pat,r0           ! a (zero) pattern block, so the bullet is set up like the game's
        mov.l   r0,@(4,r15)
        mov     #0,r0
        mov.l   r0,@(8,r15)
        mov.l   r0,@(12,r15)
        mov.l   r0,@(16,r15)
        mov.l   r0,@(20,r15)
        mov     #ST_TYPE,r4
        mov     r8,r5
        mov     r9,r6
        mov     #ST_SPEED,r7
        mov.l   sf_spawn,r0
        jsr     @r0
        nop
        add     #24,r15
8:      mov.l   sf_stride,r0
        add     r0,r11
        add     #1,r10
        mov     #68,r0
        cmp/ge  r0,r10
        bf      1b
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
9:      rts
        nop

! r4 = dx, r5 = dy (16.16, x right, y up): r0 = angle 0-0x1FF from +y towards +x (0x100 = -y), approximate
sf_atan:
        mov     r4,r6               ! keep the signs
        mov     r5,r7
        cmp/pz  r4
        bt      1f
        neg     r4,r4
1:      cmp/pz  r5
        bt      2f
        neg     r5,r5
2:      shlr8   r4                  ! small values for the divide
        shlr8   r5
        cmp/hi  r5,r4               ! |dx| > |dy| ?
        bt      3f
        mov     r4,r0               ! a = |dx| * 0x40 / |dy|
        mov     r5,r1
        bra     4f
        mov     #0,r3
3:      mov     r5,r0               ! a = 0x80 - |dy| * 0x40 / |dx|
        mov     r4,r1
        mov     #1,r3
4:      tst     r1,r1
        bt      5f
        shll2   r0
        shll2   r0
        shll2   r0                  ! * 0x40
        mov     #0,r2
6:      cmp/hs  r1,r0
        bf      7f
        sub     r1,r0
        bra     6b
        add     #1,r2
7:      mov     r2,r0
        tst     r3,r3
        bt      8f
        mov     #0x40,r1
        add     r1,r1
        sub     r0,r1
        mov     r1,r0
8:      cmp/pz  r7                  ! quadrant
        bt      10f
        cmp/pz  r6                  ! dy < 0
        bf      11f
        mov     #1,r1               ! dx >= 0: 0x100 - a
        shll8   r1
        sub     r0,r1
        rts
        mov     r1,r0
11:     mov     #1,r1               ! dx < 0: 0x100 + a
        shll8   r1
        rts
        add     r1,r0
10:     cmp/pz  r6                  ! dy >= 0
        bt      12f
        neg     r0,r0               ! dx < 0: 0x200 - a
        mov     #2,r1
        shll8   r1
        rts
        add     r1,r0
12:     rts
        nop
5:      rts
        mov     #0,r0

        .align 1
sf_wo:    .word 0x21CC
sf_60:    .word 16384             ! streams from 50% (with the 烈怒 label)
        .align 2
! Omake: graze every frame in play (adds to HIT), then the streams only while a hyper is running
sf_omk:
        mov.l   sf_play,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      1f
        sts.l   pr,@-r15
        mov.l   sf_gz,r0
        jsr     @r0
        nop
        lds.l   @r15+,pr
        mov.l   sf_pl1,r1
        mov.l   sf_2e0,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bt      1f
        mov.l   sf_goa,r0
        jmp     @r0
        nop
1:      rts
        nop
        .align 2
sf_2e0:   .long 0x2E0
sf_goa:   .long sf_go
sf_gz:    .long graze
sf_pl1:   .long 0x0C5F9970
        .align 2
sf_vars:  .long v_mode
sf_play:  .long 0x0C5F7E8C
sf_val:   .long dk_gauge
sf_obj:   .long EN_BASE + 4 * EN_STRIDE
sf_stride: .long EN_STRIDE
sf_wlo:   .long 0x0C700000
sf_whi:   .long 0x0CA00000
sf_nlo:   .long 0x0C800000
sf_nhi:   .long 0x0CA00000
sf_fc:    .long 0x0C5F7D60
sf_xmax:  .long 240 << 16
sf_ymin:  .long 32 << 16
sf_ymax:  .long 352 << 16
sf_p1:    .long 0x0C5F9970
sf_spawn: .long 0x0C1FE4B0       ! game: spawn a bullet
sf_pat:   .long sf_zero


! Power Mode: the spawn (0x0C21B0xx) builds the weapons from the player's level (literal 0x0C21B1C0,
! 0x0C1F75F0): always level 8 (Expert), whatever dress was picked.
        .global wobj_hook
wobj_hook:
        mov.l   wo_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bt      1f
        mov.l   wo_orig,r0
        jmp     @r0
        nop
1:      rts                         ! Power: build the weapons at level 8 whatever dress was picked
        mov     #8,r0
! Power Mode: the dress picked on the select screen (0x0C1F7810 dress, 0x0C1F75E0 level, set at 0x0C2759xx,
! 0x0C2761xx, 0x0C2765xx) is always taken as Expert, so the weapons and options start from the Expert set
! whatever was picked.
        .global pkd_hook, pkl_hook
pkd_hook:
        mov.l   wo_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov     #2,r5
1:      mov.l   wo_pkd,r0
        jmp     @r0
        nop
pkl_hook:
        mov.l   wo_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov     #8,r5
1:      mov.l   wo_pkl,r0
        jmp     @r0
        nop
! +0x14 (0x0C1F7830) also comes from the pick (0 Expert, 1 Shot dress: the options then drop their shots in
! the Laser-dress set): Power keeps it 0.
        .global pks_hook
pks_hook:
        mov.l   wo_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov     #0,r5
1:      mov.l   wo_pks,r0
        jmp     @r0
        nop
! Power: the spawn always builds the Expert set (all four option slots set up; NORMAL then uses part of it).
        .global wsd_hook
wsd_hook:
        mov.l   wo_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bt      1f
        mov.l   wo_pkd2,r0
        jmp     @r0
        nop
1:      rts
        mov     #2,r0
        .align 2
wo_vars:  .long v_mode
wo_pks:   .long 0x0C1F7830
wo_pkd:   .long 0x0C1F7810
wo_pkd2:  .long 0x0C1F7820       ! game: player dress
wo_pkl:   .long 0x0C1F75E0
wo_orig:  .long 0x0C1F75F0       ! game: player level (+0x24)

! Power Mode: every read of the player's dress (+0x10: 0 Shot, 1 Laser, 2 Expert; 0x0C1F7820, every literal
! pointing at it) says Expert - NORMAL and BOOST both play the Expert dress.
wdx_hook:                           ! every other dress read (spawn, options, ...): Expert in Power, so a spawn
        mov.l   wd_vars,r1          ! always builds the full Expert set (NORMAL's dress at the first spawn left
        mov.l   @(4,r1),r0          ! BOOST without its side ships)
        cmp/eq  #2,r0
        bf      1f
        rts
        mov     #2,r0
1:      mov.l   wd_orig,r0
        jmp     @r0
        nop
        .global wdx_hook
        .align 2
wd_vars:  .long v_mode
wd_orig:  .long 0x0C1F7820       ! game: player dress

! Power Mode, NORMAL: a hyper does not cancel bullets (BOOST: as the original). Starting a hyper
! (0x0C1FA168, literal 0x0C1FA234) calls 0x0C1FD040 (r4 = 40 frames, r5 = player): every bullet turns into
! a star for 40 frames; that call is skipped here.
        .global hcan_hook
hcan_hook:
        mov.l   hc_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov.l   hc_b,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      1f
        rts                         ! NORMAL: no bullet cancel
        nop
1:      mov.l   hc_vars,r1          ! Power Mode, BOOST: small stars
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      2f
        mov     #0,r6
2:      mov.l   hc_orig,r0
        jmp     @r0
        nop
        .align 2
hc_vars:  .long v_mode
hc_b:     .long dk_boost
hc_orig:  .long 0x0C1FD040       ! game: cancel bullets for r4 frames

! Power Mode: the game's queued voices (0x0C283D06, literal 0x0C283DF4) play HYPER SYSTEM READY (r5 = phrase 70)
! at every HYPER Lv up: never from here (the meter-full call, ready_hook, says it once per stock).
        .global vq_hook
vq_hook:
        mov.l   vq_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        bra     1f                  ! (phrase 70 is not HYPER SYSTEM READY - that is sound 114 - so nothing is held
        nop                         ! back here any more: the bee voice and others play)
1:      mov.l   vq_orig,r0
        jmp     @r0
        nop
        .align 2
vq_vars:  .long v_mode
vq_orig:  .long 0x0C276900       ! game: play voice

! Power Mode, NORMAL: hyper shots do not cancel bullets. Every bullet's hit handler is 0x0C1FE7A0 (registered at
! the spawn, literal 0x0C1FE748; r4 -> the hitter's flags, 1 = a hyper shot): for those it returns 1 (done)
! without turning the bullet into a star.
        .global hcol_hook
hcol_hook:
        mov.l   hk_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov.l   hk_b,r1
        mov.l   @r1,r0
        tst     r0,r0
        bf      1f
        mov.l   @r4,r0
        cmp/eq  #1,r0
        bf      1f
        rts
        mov     #1,r0
1:      mov.l   hk_orig,r0
        jmp     @r0
        nop
        .align 2
hk_vars:  .long v_mode
hk_b:     .long dk_boost
hk_orig:  .long 0x0C1FE7A0       ! game: bullet hit handler

! Power Mode: the game's own bottom bar shows the DFK BL bar. Its pieces come from the HUD sheet in VRAM: a
! solid layer (2608,130) 30 rows, (2608,160) 96, (2592,0) 115 (screen x 0-29, 30-125, 126-240), a half-transparent
! layer (2624,66), (2624,96), (2608,0) and an overlay (2768,0) 120 rows. Every frame the solid layer gets the DFK bar
! with its boxes (the lit one around the selected word) and the others are cleared, so the game keeps drawing
! "its" bar, in its own place in the drawing order (on the board too). From the DFK atlas (u4): columns 0-15 the bar,
! 16-31 the boxes (rows 0 / 58: NORMAL box dim / lit, 58 long; 116 / 166: BOOST box dim / lit, 50 long).
        .equ HB_NX,     1               ! screen x of the NORMAL box
        .equ HB_BX,     66              ! screen x of the BOOST box
dfk_hud:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   hb_cf,r1            ! first time: the DFK atlas to RAM (dk_atlas, 48 x 240)
        mov.l   @r1,r0
        tst     r0,r0
        bf      1f
        mov     #1,r0
        mov.l   r0,@r1
        mov.w   hb_cnt,r0
        mov.l   hb_src,r3
        mov.l   hb_atl,r2
2:      mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    2b
        add     #4,r2
1:      mov.l   hb_b,r1             ! r13 = box row offsets: NORMAL lit / BOOST dim, or NORMAL dim / BOOST lit
        mov.l   @r1,r0
        tst     r0,r0
        mov.w   hb_nlit,r12         ! NORMAL box rows
        bt      3f
        mov     #0,r12
3:      mov.w   hb_bdim,r13         ! BOOST box rows
        bt      4f
        mov.w   hb_blit,r13
4:      mov     #0,r8               ! the solid layer: three pieces
        mov.w   hb_vx1,r4
        mov.w   hb_vy1,r5
        mov     #30,r7
        bsr     hb_piece
        nop
        mov     #30,r8
        mov.w   hb_vx1,r4
        mov.w   hb_vy2,r5
        mov     #96,r7
        bsr     hb_piece
        nop
        mov     #126,r8
        mov.w   hb_vx3,r4
        mov     #0,r5
        mov     #115,r7
        bsr     hb_piece
        nop
        mov.w   hb_vxa,r4           ! the half-transparent layer and the overlay: cleared
        mov     #66,r5
        mov     #30,r7
        bsr     hb_clear
        nop
        mov.w   hb_vxa,r4
        mov     #96,r5
        mov     #96,r7
        bsr     hb_clear
        nop
        mov.w   hb_vx1,r4
        mov     #0,r5
        mov     #115,r7
        bsr     hb_clear
        nop
        mov.w   hb_vxo,r4
        mov     #0,r5
        mov     #120,r7
        bsr     hb_clear
        nop
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! upload a 16 x r7 piece at VRAM (r4, r5): screen rows r8.. of the DFK bar with the boxes (r12 / r13 box rows)
hb_piece:
        sts.l   pr,@-r15
        mov.l   r7,@-r15
        mov     #16,r6
        mov.l   hb_upl,r0
        jsr     @r0
        nop
        mov.l   @r15+,r9            ! rows
        mov.l   hb_lp,r1
        mov.l   @r1,r2
        mov     r8,r10              ! screen row
5:      mov.l   hb_atl,r3           ! bar row: dk_atlas + row * 96
        mov     r10,r0
        mov     #96,r1
        mulu.w  r1,r0
        sts     macl,r0
        mov     #-1,r11             ! box row (-1: none)
        mov     r10,r1              ! NORMAL box: rows HB_NX .. +57
        add     #-HB_NX,r1
        cmp/pz  r1
        bf      6f
        mov     #58,r6
        cmp/ge  r6,r1
        bt      6f
        mov     r1,r11
        bra     7f
        add     r12,r11
6:      mov     r10,r1              ! BOOST box: rows HB_BX .. +49
        add     #-HB_BX,r1
        cmp/pz  r1
        bf      7f
        mov     #50,r6
        cmp/ge  r6,r1
        bt      7f
        mov     r1,r11
        add     r13,r11
7:      add     r0,r3               ! r3 -> bar row (columns 0-15)
        mov     #16,r6
8:      mov.w   @r3,r4
        cmp/pz  r11
        bf      10f
        mov     r11,r0              ! box pixel: atlas row r11, column 16 + c
        mov     #96,r1
        mulu.w  r1,r0
        sts     macl,r0
        mov.l   hb_atl,r1
        add     r1,r0
        mov     #16,r1
        sub     r6,r1               ! c
        add     r1,r1
        add     r1,r0
        add     #32,r0
        mov.w   @r0,r0
        mov     r0,r1               ! transparent unless bit 15
        shll16  r1
        cmp/pz  r1
        bt      10f
        mov     r0,r4
10:     mov.w   r4,@r2
        add     #2,r2
        add     #2,r3
        dt      r6
        bf      8b
        add     #1,r10
        dt      r9
        bf      5b
        mov.l   hb_lp,r1
        mov.l   r2,@r1
        lds.l   @r15+,pr
        rts
        nop

! clear a 16 x r7 area at VRAM (r4, r5)
hb_clear:
        sts.l   pr,@-r15
        mov.l   r7,@-r15
        mov     #16,r6
        mov.l   hb_upl,r0
        jsr     @r0
        nop
        mov.l   @r15+,r9
        shll2   r9
        shll    r9                  ! longs: 8 per row
        mov.l   hb_lp,r1
        mov.l   @r1,r2
        mov     #0,r0
11:     mov.l   r0,@r2
        dt      r9
        bf/s    11b
        add     #4,r2
        mov.l   r2,@r1
        lds.l   @r15+,pr
        rts
        nop
        .align 1
hb_cnt:   .word 48 * 240 / 2
hb_nlit:  .word 58
hb_bdim:  .word 116
hb_blit:  .word 166
hb_vx1:   .word 2608
hb_vx3:   .word 2592
hb_vxa:   .word 2624
hb_vxo:   .word 2768
hb_vy1:   .word 130
hb_vy2:   .word 160
        .align 2
hb_cf:    .long dk_hcopy
hb_src:   .long DFK_GFX + 16
hb_atl:   .long dk_atlas
hb_b:     .long dk_boost
hb_upl:   .long 0x0C1D17C0
hb_lp:    .long 0x0C1D1460


! Power Mode: no "HYPER Lv" label (sprite 0x11686, drawn through literal 0x0C27B22C, which also draws another
! HUD piece) and no HYPER Lv digits (literal 0x0C27E86C, those digits only) on the HUD.
        .global hlvl_hook
hlvl_hook:
        mov.l   hl_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   hl_lbl,r1
        cmp/eq  r1,r4
        bf      8f
        mov.l   hl_pos,r1           ! where the label would be (the HUD shakes): hud_extra / mh_draw follow it
        mov.l   r5,@r1
        mov.l   r6,@(4,r1)
        rts
        mov     #0,r0
8:      mov.l   hl_spr,r0
        jmp     @r0
        nop
        .global hlvd_hook
hlvd_hook:
        mov.l   hl_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts
        mov     #0,r0
8:      mov.l   hl_spr,r0
        jmp     @r0
        nop
        .align 2
hl_vars:  .long v_mode
hl_lbl:   .long 0x11686
hl_pos:   .long dk_lblpos
hl_spr:   .long 0x0C1E4990       ! game: draw a sprite

! Power Mode: the RANK digits (both draws through literal 0x0C27EE0C: the digit and its shadow, P1 at x 115 / 125)
! are not drawn there; their sprites are noted and hud_extra draws them where the HYPER Lv digits were (later in
! the frame, over the panel).
        .global rkd_hook
rkd_hook:
        mov.l   rk_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   rk_xmax,r1          ! player 1's (x < 160)
        cmp/ge  r1,r5
        bt      8f
        mov.l   rk_ids,r1           ! note the digit (tens at x 115, ones at x 125) for hud_extra; not drawn here
        mov.l   rk_xmid,r0
        cmp/ge  r0,r5
        bf      1f
        add     #4,r1
1:      mov.l   r4,@r1
        rts
        mov     #0,r0
8:      mov.l   rk_spr,r0
        jmp     @r0
        nop
        .align 2
rk_vars:  .long v_mode
rk_xmax:  .long 160 << 16
rk_xmid:  .long 120 << 16
rk_ids:   .long dk_rkid
rk_spr:   .long 0x0C1E4990       ! game: draw a sprite

! Power Mode: no RANK box (sprites 0x116C4 / 0x116C5, drawn through literal 0x0C279E40 with other HUD pieces).
        .global rbx_hook
rbx_hook:
        mov.l   rb_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   rb_id,r1
        mov     r4,r0
        and     #0xFE,r0            ! 0x116C4 or 0x116C5
        mov     r4,r2
        shlr8   r2
        shll8   r2
        or      r2,r0
        cmp/eq  r1,r0
        bf      8f
        rts
        mov     #0,r0
8:      mov.l   rb_spr,r0
        jmp     @r0
        nop
        .align 2
rb_vars:  .long v_mode
rb_id:    .long 0x116C4
rb_spr:   .long 0x0C1E4990

! Power Mode (from bicon_hook, P1, in play, late in the HUD): the rank digits where HYPER Lv was, and "HYPER" in
! the game's font in its old place: gold with a hyper stocked, dark without.
        .equ HX_X,      27              ! "HYPER" text
        .equ HX_Y,      37
        .equ RX_X,      80              ! rank digits
hud_extra:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   hx_pos,r1           ! r9 = dx, r10 = -dy (the HUD shake)
        mov.l   @r1,r9
        shlr16  r9
        exts.w  r9,r9
        add     #-50,r9
        mov.l   @(4,r1),r10
        shlr16  r10
        exts.w  r10,r10
        mov.w   hx_278,r0
        sub     r0,r10
        neg     r10,r10
        mov.l   hx_ids,r8           ! the rank: two digits in the game's font (sprites 0x1168B + digit)
        mov.l   @r8,r0
        tst     r0,r0
        bt      1f
        mov.l   hx_d0,r1
        sub     r1,r0
        add     #48,r0
        mov.l   hx_buf,r2
        mov.b   r0,@r2
        mov.l   @(4,r8),r0
        sub     r1,r0
        add     #48,r0
        mov.b   r0,@(1,r2)
        mov     #0,r0
        mov.b   r0,@(2,r2)
        mov.l   hx_rkc,r4
        mov.l   hx_col,r0
        jsr     @r0
        nop
        mov     #RX_X,r4
        add     r9,r4
        mov     #HX_Y,r5
        add     r10,r5
        mov.w   hx_f0,r6
        mov.l   hx_buf,r7
        mov.l   hx_ds,r0
        jsr     @r0
        nop
1:      mov.l   hx_p1,r1            ! HYPER: flashing gold / white with a stock ready, dark without
        mov.w   hx_2e4,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        mov.l   hx_dark,r4
        bt      2f
        mov.l   hx_fc,r0            ! every 8 frames
        mov.l   @r0,r0
        tst     #8,r0
        mov.l   hx_gold,r4
        bt      2f
        mov.l   hx_white,r4
2:      mov.l   hx_col,r0
        jsr     @r0
        nop
        mov     #HX_X,r4
        add     r9,r4
        mov     #HX_Y,r5
        add     r10,r5
        mov.w   hx_f0,r6
        mova    hx_str,r0
        mov     r0,r7
        mov.l   hx_ds,r0
        jsr     @r0
        nop
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
hx_278:   .word 278
hx_2e4:   .word 0x2E4
hx_f0:    .word 0xF0
        .align 2
hx_ids:   .long dk_rkid
hx_pos:   .long dk_lblpos
hx_d0:    .long 0x1168B
hx_buf:   .long dk_rkbuf
hx_rkc:   .long 0x00807878       ! rank: light pink like the old digits
hx_p1:    .long 0x0C5F9970
hx_dark:  .long 0x00181818
hx_gold:  .long 0x00806020
hx_white: .long 0x00808080
hx_fc:    .long 0x0C5F7D60       ! frame counter
hx_col:   .long 0x0C1DD4B4       ! game: text colour
hx_ds:    .long ORIG_DS
hx_str:   .asciz "HYPER"
        .align 2

! Power Mode: while a stock waits (+0x2E4 >= 1) the game may not add another: its meter-full routine (0x0C1FA490,
! called from the meter add, literal 0x0C1FA8B4: stock + 1, HYPER SYSTEM READY banner and voice) and its stock add
! (0x0C1F9D90, literal 0x0C22AE64: hyper item) do nothing. The stock stays Lv 1, nothing replays.
        .global mfull_hook
mfull_hook:                         ! Power Mode: never (our meter gives the stocks); the caller takes 512 off the meter
        mov.l   mf_vars,r2          ! afterwards, so it is set to 512 (-> 0)
        mov.l   @(4,r2),r0
        cmp/eq  #2,r0
        bf      7f
        mov.w   mf_2fc,r0
        mov.w   mf_1022,r1
        rts
        mov.l   r1,@(r0,r4)
7:      mov.l   mf_orig1,r0
        jmp     @r0
        nop
        .global sadd_hook
sadd_hook:
        mov.l   mf_ok,r2            ! (the item's notification: only when this added a stock)
        mov     #1,r0
        mov.l   r0,@r2
        mov.l   mf_orig2,r1
1:      mov.l   mf_vars,r2
        mov.l   @(4,r2),r0
        cmp/eq  #2,r0
        bf      8f
        mov.w   mf_2e4,r0
        mov.l   @(r0,r4),r0
        cmp/pl  r0
        bt      6f
        mov.w   mf_2e0,r0           ! nor during a hyper (our meter gives the next stock)
        mov.l   @(r0,r4),r0
        tst     r0,r0
        bt      8f
6:      mov.l   mf_ok,r2
        mov     #0,r0
        rts
        mov.l   r0,@r2
8:      jmp     @r1
        nop
        .global inot_hook
inot_hook:                          ! the hyper item's HYPER notification (0x0C22AEF0, literal 0x0C22AE68)
        mov.l   mf_vars,r2
        mov.l   @(4,r2),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   mf_ok,r2
        mov.l   @r2,r0
        tst     r0,r0
        bf      8f
        rts
        nop
8:      mov.l   mf_orig3,r0
        jmp     @r0
        nop
        .align 1
mf_2e4:   .word 0x2E4
mf_2e0:   .word 0x2E0
mf_2fc:   .word 0x2FC
mf_1022:  .word 512             ! (after the caller's - 512: 0)
        .align 2
mf_vars:  .long v_mode
mf_orig1: .long 0x0C1FA490       ! game: meter full
mf_orig2: .long 0x0C1F9D90       ! game: add a stock
mf_orig3: .long 0x0C22AEF0       ! game: item notification
mf_ok:    .long dk_sadok

! Power Mode, during a hyper: every bullet cancel makes small stars. All cancels go through 0x0C1FE220 (r4 = big
! stars flag, r5 = player; literals 0x0C1FCF70, 0x0C1FCFC0, 0x0C1FD03C, 0x0C1FD070, 0x0C1FDB50): r4 = 0.
        .global sml_hook
sml_hook:
        mov.l   sm_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   sm_p1,r1
        mov.w   sm_2e0,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bt      8f
        mov     #0,r4               ! small stars
8:      mov.l   sm_orig,r0
        jmp     @r0
        nop
        .align 1
sm_2e0:   .word 0x2E0
        .align 2
sm_vars:  .long v_mode
sm_p1:    .long 0x0C5F9970
sm_orig:  .long 0x0C1FE220       ! game: cancel the listed bullets into stars

! Power Mode, every frame in play: our own hyper meter (dk_hnext, 0-1024) is the only source of stocks (the game's
! meter-full is blocked, mfull_hook). It fills at the game's own rate (+1 each time a countdown reloaded from +0x30C
! runs out), empties when a hyper starts and fills again during it. Full with no stock (and not in a hyper): the
! stock (Lv 1) with HYPER SYSTEM READY and its banner. A stock waiting (also from a hyper item): full.
hn_frame:
        sts.l   pr,@-r15
        mov.l   hn_p1,r2
        mov.w   hn_2e0,r0
        mov.l   @(r0,r2),r0         ! in a hyper?
        mov.l   hn_vars,r3          ! r3 -> dk_hwas, dk_hnext, dk_hcnt
        mov.l   @r3,r1              ! in a hyper last frame?
        mov.l   r0,@r3
        tst     r0,r0
        bt      1f
        tst     r1,r1               ! a hyper just started: empty
        bf      1f
        mov     #0,r1
        mov.l   r1,@(4,r3)
        mov.l   r1,@(8,r3)
1:      mov.l   @r3,r0              ! the tick: only during a hyper (outside, ameter_hook adds what the game adds)
        tst     r0,r0
        bt      2f
        mov.l   @(8,r3),r1
        add     #-1,r1
        cmp/pz  r1
        bt      5f
        mov.w   hn_30c,r0
        mov.l   @(r0,r2),r1         ! reload
        mov.l   @(4,r3),r0
        add     #1,r0
        mov.w   hn_512,r4
        cmp/gt  r4,r0
        bf      3f
        mov     r4,r0
3:      mov.l   r0,@(4,r3)
5:      mov.l   r1,@(8,r3)
2:      mov.l   @r3,r0              ! in a hyper: nothing more
        tst     r0,r0
        bf      9f
        mov.w   hn_2e4,r0
        mov.l   @(r0,r2),r1         ! a stock waiting: full
        tst     r1,r1
        bt      4f
        mov.w   hn_512,r0
        bra     9f
        mov.l   r0,@(4,r3)
4:      mov.l   @(4,r3),r1          ! full, no stock: the stock
        mov.w   hn_512,r0
        cmp/ge  r0,r1
        bf      9f
        mov     #1,r1
        mov.w   hn_2e4,r0
        mov.l   r1,@(r0,r2)
9:      mov.l   hn_p1,r2            ! HYPER turned gold (no stock -> a stock, not in a hyper; from the meter or an
        mov.w   hn_2e4,r0           ! item): phrase 115 and the HYPER SYSTEM READY banner, once
        mov.l   @(r0,r2),r1
        mov.l   hn_last,r3
        mov.l   @r3,r0
        mov.l   r1,@r3
        tst     r1,r1
        bt      8f
        tst     r0,r0
        bf      8f
        mov.w   hn_2e0,r0
        mov.l   @(r0,r2),r0
        tst     r0,r0
        bf      8f
        mov.l   hn_se,r0
        jsr     @r0
        nop
        mov.l   hn_p1,r4
        mov.l   hn_ban,r0
        jsr     @r0
        nop
8:      lds.l   @r15+,pr
        rts
        nop
        .align 1
hn_2e0:   .word 0x2E0
hn_2e4:   .word 0x2E4
hn_30c:   .word 0x30C
hn_512:   .word 1024             ! our meter's full
        .align 2
hn_p1:    .long 0x0C5F9970
hn_vars:  .long dk_hwas
hn_ban:   .long 0x0C2778B0       ! game: HYPER SYSTEM READY banner
hn_se:    .long 0x0C282860       ! game: phrase 115
hn_last:  .long dk_hlast

! Power Mode: outside a hyper our meter gains what the game's meter gains: its add (0x0C1FA830, r4 = player,
! r5 = amount, from its tick at literal 0x0C1FA488) also adds to dk_hnext (at most 1024).
        .global ameter_hook
ameter_hook:
        mov.l   am_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   am_val,r1
        mov.l   @r1,r0
        add     r5,r0
        mov.w   am_512,r2
        cmp/gt  r2,r0
        bf      1f
        mov     r2,r0
1:      mov.l   r0,@r1
8:      mov.l   am_orig,r0
        jmp     @r0
        nop
        .align 1
am_512:   .word 1024
        .align 2
am_vars:  .long v_mode
am_val:   .long dk_hnext
am_orig:  .long 0x0C1FA830       ! game: add to the hyper meter

! Power Mode (from hud_hook, in play): our hyper meter drawn where the game's bar was (screen x 27-74, y 47-51): a
! solid yellow 8 x 64 block uploaded at VRAM (7648,200) every frame, drawn dk_hnext * 48 / 1024 pixels long.
        .equ MH_VX,     7648
        .equ MH_VY,     200
        .equ MH_UP,     268             ! game "up" (screen y 47)
        .equ MH_X,      27
        .global mh_draw
mh_draw:
        mov.l   mh_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      9f
        mov.l   mh_play,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      9f
        sts.l   pr,@-r15
        mov.l   mh_upl,r0           ! upload the block
        mov.w   mh_vx,r4
        mov.w   mh_vy,r5
        mov     #8,r6
        mov     #64,r7
        jsr     @r0
        nop
        mov.l   mh_lp,r1
        mov.l   @r1,r2
        mov.l   mh_col,r3
        mov     #0,r0
        mov     #1,r4
        shll8   r4                  ! 8 x 64 pixels = 256 longs
1:      mov.l   r3,@r2
        dt      r4
        bf/s    1b
        add     #4,r2
        mov.l   r2,@r1
        mov.l   mh_val,r1           ! length = value * 48 / 1024 = value * 3 / 64
        mov.l   @r1,r2
        mov     r2,r0
        add     r2,r0
        add     r2,r0
        shlr2   r0
        shlr2   r0
        shlr2   r0
        tst     r0,r0
        bt      8f
        mov     r0,r2               ! h = length (along the screen x)
        mov.l   mh_pos,r3           ! follow the HUD shake
        mov.l   @r3,r7
        shlr16  r7
        exts.w  r7,r7
        add     #MH_X - 50,r7
        mov.l   @(4,r3),r6
        shlr16  r6
        exts.w  r6,r6
        mov.w   mh_d278,r0
        sub     r0,r6
        mov.w   mh_up,r0
        add     r0,r6
        mov.w   mh_vx,r4
        mov.w   mh_vy,r5
        mov     #5,r1               ! w = 5 (screen y)
        mov.l   mh_spr,r0
        jsr     @r0
        nop
8:      lds.l   @r15+,pr
9:      rts
        nop
        .align 1
mh_vx:    .word MH_VX
mh_vy:    .word MH_VY
mh_up:    .word MH_UP
mh_d278:  .word 278
        .align 2
mh_vars:  .long v_mode
mh_play:  .long 0x0C5F7E8C
mh_upl:   .long 0x0C1D17C0       ! game: upload header
mh_lp:    .long 0x0C1D1460
mh_col:   .long 0xFFE6FFE6       ! light yellow, opaque (bit 15)
mh_val:   .long dk_hnext
mh_pos:   .long dk_lblpos
mh_spr:   .long bd_spr

! Power Mode: the HUD's hyper meter bar value for player 1 (0x0C27A0B0: the meter through literal 0x0C27A124,
! during a hyper the time left through 0x0C27A128) reads 0, so the game's bar is empty; ours (mh_draw) shows.
        .global hbv_hook
hbv_hook:
        mov.l   hv_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts
        mov     #0,r0
8:      mov.l   hv_o1,r0
        jmp     @r0
        nop
        .global hbt_hook
hbt_hook:
        mov.l   hv_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        rts
        mov     #0,r0
8:      mov.l   hv_o2,r0
        jmp     @r0
        nop
        .align 2
hv_vars:  .long v_mode
hv_o1:    .long 0x0C1FA5D0       ! game: hyper meter
hv_o2:    .long 0x0C1FA5F0       ! game: hyper time

! Power Mode: the game's hyper meter bar is not drawn for player 1 (x < 160): sprites 0x1BE + fill (literal
! 0x0C2784E4) and, in a hyper, sprite 0x11685 (literal 0x0C27BB34).
        .global hbar_hook
hbar_hook:
        mov.l   hb2_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      8f
        mov.l   hb2_x,r1
        cmp/ge  r1,r5
        bt      8f
        rts
        mov     #0,r0
8:      mov.l   hb2_spr,r0
        jmp     @r0
        nop
        .align 2
hb2_vars: .long v_mode
hb2_x:    .long 160 << 16
hb2_spr:  .long 0x0C1E4990

! Power Mode: the BOOST gauge (from dfkbl, u4 DFK_GFX + 0x8000) under INSERT COIN. It fills while BOOST is on
! and the laser is held (A or C), and drains otherwise: blue up to the middle, then red; the fill shimmers.
        .equ GA_VX,     7600            ! VRAM: frame block 32 x 128 at (7600,200), fill slice 16 x 64 at (7632,200)
        .equ GA_VY,     200
        .equ GA_UP,     270             ! game "up" of the gauge (screen y 33-48, just under INSERT COIN)
        .equ GA_X,      110             ! game x (screen x 110-237)
! gauge height for this frame -> dk_gaup: GA_UP, or GA_DOWN while one of the boss / mid-boss enemy slots
! (0-3) holds a live enemy (work area points back at it, 0 < HP <= max HP, max HP 500 and up).
        .equ GA_ICO,    -16             ! bar vs INSERT COIN's draw height
ga_boss:                            ! target: where the game last drew INSERT COIN (dk_icy, 16.16; it moves down
        mov.l   gb_icy,r1           ! under a boss bar), plus GA_ICO; GA_UP until it has been drawn
        mov.l   @r1,r1
        tst     r1,r1
        bf      1f
        mov.w   gb_up,r0
        bra     3f
        nop
1:      shlr16  r1
        exts.w  r1,r0
        add     #GA_ICO,r0
3:      mov.l   gb_v,r1             ! slide 1 px a frame toward it
        mov.l   @r1,r2
        cmp/eq  r0,r2
        bt      6f
        cmp/gt  r0,r2
        bt/s    6f
        add     #-1,r2
        add     #2,r2
6:      rts
        mov.l   r2,@r1
        .align 1
gb_up:    .word GA_UP
        .align 2
gb_icy:   .long dk_icy
gb_v:     .long dk_gaup

! Power Mode: no INSERT COIN on the HUD. The HUD's message routine (0x0C279630-0x0C279674) draws it as sprite
! 0x11534 + message through literal 0x0C2796B4 (0x0C1E4990): those sprites (0x11534-0x11543) go off screen.
        .global icoin_hook
icoin_hook:
        mov.l   ic_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      1f
        mov.l   ic_lo,r0
        cmp/hs  r0,r4
        bf      1f
        add     #48,r0              ! (0x11524-0x11553: INSERT COIN, PRESS 2P START, ...)
        cmp/hs  r0,r4
        bt      1f
        mov.l   ic_y,r1             ! its height (game up, 16.16 in r6) is where the 烈怒 bar goes, and the frame
        mov.l   r6,@r1
        mov.l   ic_fc,r2
        mov.l   @r2,r2
        mov.l   r2,@(4,r1)          ! (dk_icfc: no INSERT COIN for a while = no bar, e.g. the score tally)
        mov.l   ic_far,r5           ! drawn far off screen (the caller uses the call's result)
1:      mov.l   ic_orig,r0
        jmp     @r0
        nop
        .align 2
ic_vars:  .long v_mode
ic_lo:    .long 0x11524
ic_orig:  .long 0x0C1E4990
ic_far:   .long 0xE0000000
ic_y:     .long dk_icy
ic_fc:    .long 0x0C5F7D60

! Power Mode: grazing. Every frame, each enemy bullet and each live enemy within GR_RAD pixels of player 1 (x and y,
! a box about the ship's body) adds GR_ADD to the HIT count (+0x1FC) and to the graze count (dk_graze, shown under
! the 烈怒 bar). Player 1 at +0xB0 / +0xB4. Bullets: the manager (*0x0C4C8978 + 0x30DFC), +20 first, each +4 next,
! +0 state (2 = live), +0x2C / +0x30 x / y. Enemies: slots EN_BASE + k * EN_STRIDE, work at +0x21CC (pointing back),
! +4 / +8 x / y. All 16.16, the same axes.
        .equ GR_RAD,    20              ! graze distance (px)
        .equ GR_ADD,    1               ! hits per grazing bullet / enemy per frame
graze:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   gz_p1,r1            ! r10 / r11 = player x / y
        mov.w   gz_b0,r0
        mov.l   @(r0,r1),r10
        add     #4,r0
        mov.l   @(r0,r1),r11
        mov     #0,r8               ! grazing things
        mov.l   gz_rad,r9
        mov.l   gz_mgr,r1           ! bullets
        mov.l   @r1,r1
        tst     r1,r1
        bt      5f
        mov.l   gz_off,r0
        add     r0,r1
        mov.l   @(20,r1),r2
        mov     #0,r7               ! (at most 1000: a broken list stops)
        mov.w   gz_max,r6
1:      tst     r2,r2
        bt      5f
        add     #1,r7
        cmp/gt  r6,r7
        bt      5f
        mov.l   @r2,r0
        cmp/eq  #2,r0
        bf      4f
        mov     r2,r3
        add     #0x2C,r3
        mov.l   @r3+,r4
        bsr     gz_near
        mov.l   @r3,r5
4:      bra     1b
        mov.l   @(4,r2),r2
5:      mov.l   gz_en,r2            ! enemies
        mov     #EN_N,r6
6:      mov.w   gz_wo,r0
        mov.l   @(r0,r2),r3
        mov.l   gz_lo,r0
        cmp/hs  r0,r3
        bf      7f
        mov.l   gz_hi,r0
        cmp/hs  r0,r3
        bt      7f
        mov.l   @r3,r0
        cmp/eq  r2,r0
        bf      7f
        mov.l   @(4,r3),r4
        bsr     gz_near
        mov.l   @(8,r3),r5
7:      mov.l   gz_str,r0
        dt      r6
        bf/s    6b
        add     r0,r2
        tst     r8,r8
        bt      9f
        mov.l   gz_p1,r1            ! HIT count and graze count += grazing
        mov.w   gz_1fc,r0
        mov.l   @(r0,r1),r2
        add     r8,r2
        mov.l   r2,@(r0,r1)
        mov.l   gz_cnt,r1
        mov.l   @r1,r2
        add     r8,r2
        mov.l   r2,@r1
9:      mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
gz_near:                            ! r4 / r5 = x / y: within r9 of the player (r10 / r11) -> r8 += GR_ADD
        sub     r10,r4
        cmp/pz  r4
        bt      1f
        neg     r4,r4
1:      cmp/gt  r9,r4
        bt      2f
        sub     r11,r5
        cmp/pz  r5
        bt      3f
        neg     r5,r5
3:      cmp/gt  r9,r5
        bt      2f
        add     #GR_ADD,r8
2:      rts
        nop
        .align 1
gz_max:   .word 1000
gz_1fc:   .word 0x1FC
gz_b0:    .word 0xB0
gz_wo:    .word 0x21CC
        .align 2
gz_p1:    .long 0x0C5F9970
gz_mgr:   .long 0x0C4C8978
gz_off:   .long 0x00030DFC
gz_rad:   .long GR_RAD << 16
gz_en:    .long EN_BASE
gz_str:   .long EN_STRIDE
gz_lo:    .long 0x0C000000
gz_hi:    .long 0x0D000000
gz_cnt:   .long dk_graze

! The graze count (dk_graze) under the right end of the 烈怒 bar, while the bar is shown: the game's orange
! digit sprites 0x11554-0x1155D (its CONTINUE countdown digits), GT_DX apart
graze_text:
        mov.l   gt_icy,r1           ! hidden with the bar (no INSERT COIN for half a second)
        mov.l   @(4,r1),r1
        mov.l   gt_fc,r2
        mov.l   @r2,r2
        sub     r1,r2
        mov     #30,r1
        cmp/hi  r1,r2
        bt      9f
        sts.l   pr,@-r15
        mov.l   gt_buf,r2           ! the number's digits, no leading zeros
        mov.l   gt_cnt,r1
        mov.l   @r1,r4              ! value
        mova    gt_p10,r0
        mov     r0,r5               ! powers of ten, 0-terminated
        mov     #0,r6               ! a digit written yet
3:      mov.l   @r5+,r7
        tst     r7,r7
        bt      6f
        mov     #0,r0
4:      cmp/hs  r7,r4
        bf      5f
        sub     r7,r4
        bra     4b
        add     #1,r0
5:      tst     r0,r0
        bf      7f
        tst     r6,r6
        bt      3b
7:      mov     #1,r6
        add     #48,r0
        mov.b   r0,@r2
        bra     3b
        add     #1,r2
6:      tst     r6,r6
        bf      8f
        mov     #48,r0              ! 0
        mov.b   r0,@r2
        add     #1,r2
8:      mov     #0,r0
        mov.b   r0,@r2
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   gt_buf,r8           ! one sprite per digit, right-aligned to the bar's right end
        mov     r2,r9
        sub     r8,r9               ! digits
        mov     #GT_DX,r0
        mulu.w  r0,r9
        sts     macl,r0
        mov.w   gt_x,r9
        sub     r0,r9
10:     mov.b   @r8+,r0
        tst     r0,r0
        bt      11f
        add     #-48,r0
        mov.l   gt_d0,r4
        add     r0,r4               ! sprite 0x11554 + digit
        mov     r9,r5
        shll16  r5
        mov.l   gt_up,r6            ! game up = bar height - 7 (just under the bar)
        mov.l   @r6,r6
        add     #-7,r6
        shll16  r6
        mov     #-24,r7
        extu.b  r7,r7               ! priority 0xE8
        mov.l   gt_spr,r0
        jsr     @r0
        nop
        bra     10b
        add     #GT_DX,r9
11:     mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
9:      rts
        nop
        .align 1
gt_x:     .word GT_RX
        .equ GT_RX,     234             ! right end of the number (screen x)
        .equ GT_DX,     12              ! digit spacing (px)
        .align 2
gt_icy:   .long dk_icy
gt_fc:    .long 0x0C5F7D60
gt_buf:   .long dk_gbuf
gt_cnt:   .long dk_graze
gt_up:    .long dk_gaup
gt_d0:    .long 0x11554          ! sprite: orange digit 0
gt_spr:   .long 0x0C1E4990       ! game: draw a sprite
gt_p10:   .long 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1, 0

! Power Mode (from bicon_hook, P1, in play): one bomb icon (the 2P one, sprite 0x113C0) per bomb P1 holds, in the
! 2P bomb slots (screen x 227, 208, 189, 170, 151, 132), up to 6
p2_bombs:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.w   pb_ty,r10           ! game up = pb_y + (bic_y - text y): follows the HUD's moves
        sub     r4,r10
        mov.w   pb_y,r0
        add     r0,r10
        shll16  r10
        mov.l   pb_p1,r1
        mov.b   @(6,r1),r0          ! bombs
        extu.b  r0,r8
        mov     #6,r0
        cmp/gt  r0,r8
        bf      1f
        mov     r0,r8
1:      tst     r8,r8
        bt      9f
        mova    pb_x,r0
        mov     r0,r9
2:      mov.l   pb_fc,r1            ! animated like the game's: id + frame % 15
        mov.l   @r1,r0
        mov     #15,r1
3:      cmp/hs  r1,r0
        bf      4f
        bra     3b
        sub     r1,r0
4:      mov.l   pb_id,r4
        add     r0,r4
        mov.w   @r9+,r5
        shll16  r5
        mov     r10,r6
        mov     #-1,r7
        extu.b  r7,r7               ! priority 0xFF: over the HUD
        mov.l   pb_spr,r0
        jsr     @r0
        nop
        dt      r8
        bf      2b
9:      mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
pb_x:     .word 140, 159, 178, 197, 216, 235
pb_y:     .word 5
pb_ty:    .word 311             ! the text y with the HUD at rest (bic_y)
        .align 2
pb_p1:    .long 0x0C5F9970
pb_id:    .long 0x113B0
pb_spr:   .long 0x0C1E4990       ! game: draw a sprite
pb_fc:    .long 0x0C5F7D60

        .global gauge_draw
gauge_draw:
        mov.l   ga_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      9f
        mov.l   ga_play,r1          ! only while a game is in play
        mov.l   @r1,r0
        tst     r0,r0
        bf      47f
        mov.l   ga_earn,r1          ! not in play: no bombs earned, no grazes
        mov     #0,r0
        mov.l   r0,@r1
        mov.l   ga_gzc,r1
        bra     9f
        mov.l   r0,@r1
47:
        sts.l   pr,@-r15
        mov.l   ga_stg,r1           ! a new stage: the graze count starts again
        mov.l   @r1,r1
        mov.l   ga_lstg,r2
        mov.l   @r2,r0
        cmp/eq  r1,r0
        bt      48f
        mov.l   r1,@r2
        mov.l   ga_gzc,r2
        mov     #0,r0
        mov.l   r0,@r2
48:
        mov.l   ga_graze,r0         ! grazing: bullets near player 1 add to the HIT count
        jsr     @r0
        nop
        mov.l   ga_bossf,r0         ! height: where INSERT COIN would be (it moves under a boss bar)
        jsr     @r0
        nop
        mov.l   ga_hn,r0            ! the hyper meter keeps filling during a hyper (banked for the next stock)
        jsr     @r0
        nop
        lds.l   @r15+,pr
        mov.l   ga_p1,r1            ! only the bombs picked up count: none at the start, none after a death
        mov.b   @(6,r1),r0
        extu.b  r0,r0
        mov.l   ga_earn,r2
        mov.l   @r2,r3
        cmp/hi  r3,r0
        bf      46f
        mov     r3,r0               ! more than earned (the respawn bomb): back to the earned count
        mov.b   r0,@(6,r1)
46:     mov.l   r0,@r2              ! used bombs: earned follows the game
        mov.l   ga_p1,r1            ! bomb multiplier: cleared when a bomb goes off (the autobomb when hit) or a
        mov.b   @(3,r1),r0          ! life is lost (mov.b @(disp) only loads r0 on the SH-3)
        extu.b  r0,r2
        shll8   r2
        mov.b   @(6,r1),r0
        extu.b  r0,r0
        or      r2,r0               ! lives << 8 | bombs
        mov.l   ga_lastbl,r1
        mov.l   @r1,r2
        mov.l   r0,@r1
        extu.b  r0,r3               ! bombs now
        extu.b  r2,r4               ! bombs last frame
        cmp/hi  r3,r4
        bt      40f
        shlr8   r0                  ! lives now
        shlr8   r2
        cmp/hi  r0,r2
        bf      41f
        mov.l   ga_hnx,r1           ! a life lost: our hyper meter back to 0
        mov     #0,r0
        mov.l   r0,@r1
40:     mov.l   ga_mult,r1
        mov     #0,r0
        mov.l   r0,@r1
41:
        mov.l   ga_icy,r1           ! no INSERT COIN drawn for half a second (score tally, ...): no bar
        mov.l   @(4,r1),r1
        mov.l   ga_fc,r2
        mov.l   @r2,r2
        sub     r1,r2
        mov     #30,r1
        cmp/hi  r1,r2
        bt      9f
        mov.l   ga_gfx,r1
        mov.l   @r1,r0
        mov.l   ga_magic,r2
        cmp/eq  r2,r0
        bf      9f
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   ga_val,r8           ! the fill (pixels << 8): + 0x80 while BOOST and the laser, else - 0x80
        mov.l   @r8,r0
        mov.l   ga_b,r1
        mov.l   @r1,r1
        tst     r1,r1
        bt      2f
        mov.l   ga_in,r1            ! firing: the shot or the laser
        mov.l   @r1,r1
        mov     #0x50,r2            ! held: A 0x10, C 0x40
        tst     r2,r1
        bt      2f
        mov     #64,r1              ! step 0x80
        add     r1,r1
        add     r1,r0
        mov.l   ga_max,r1
        cmp/gt  r1,r0
        bf      3f
        mov     r1,r0
        bra     3f
        nop
2:      mov     #64,r1              ! step 0x80
        add     r1,r1
        sub     r1,r0
        cmp/pz  r0
        bt      3f
        mov     #0,r0
3:      mov.l   r0,@r8
        mov     r0,r9
        mov.l   ga_p1,r2            ! the hyper stock: once the meter has filled, the stock is Lv 10 and the meter
        mov     #23,r0              ! 0x2E0 = 23 * 32
        shll2   r0
        shll2   r0
        shll    r0
        mov.l   @(r0,r2),r0         ! stays full while it waits; not during a hyper
        tst     r0,r0
        bf      23f
        mov     #23,r0              ! 0x2E4
        shll2   r0
        shll2   r0
        shll    r0
        add     #4,r0
        mov.l   @(r0,r2),r1
        tst     r1,r1
        bf      22f
        bra     18f
        nop
23:     mov.l   ga_said,r1          ! a hyper runs: the next stock may say HYPER SYSTEM READY again
        mov     #0,r3
        bra     18f
        mov.l   r3,@r1
22:     mov     #1,r1               ! a stock is always HYPER Lv 1 (烈怒 no longer sets it)
20:     mov.l   r1,@(r0,r2)
        add     #24,r0              ! the game's own meter (+0x2FC, hidden now) held at 0: held full, collecting
        mov     #0,r1               ! stars played its "meter full" chime for every star
        mov.l   r1,@(r0,r2)
18:     mov     r9,r0
        shlr8   r0
        mov     r0,r9               ! r9 = fill in pixels (0-128)
        mov.l   ga_fok,r1           ! the DFK bar (its 32 x 128 frame block: background + outline): copied from
        mov.l   @r1,r0              ! u4 to RAM once
        tst     r0,r0
        bf      35f
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   ga_src,r3
        mov.l   ga_fbuf,r2
        mov.w   ga_nfr,r0
37:     mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    37b
        add     #4,r2
35:     mov.l   ga_upl,r0           ! upload it at (GA_VX,GA_VY) from RAM
        mov.w   ga_vx,r4
        mov.w   ga_vy,r5
        mov     #32,r6
        mov.w   ga_128,r7
        jsr     @r0
        nop
        mov.l   ga_lp,r1
        mov.l   @r1,r2
        mov.l   ga_fbuf,r3
        mov.w   ga_nfr,r0
39:     mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    39b
        add     #4,r2
        mov.l   r2,@r1
        mov.l   ga_filok,r1         ! the DFK fill blocks (red, then blue, 64 x 64 each): copied from u4 to RAM once
        mov.l   @r1,r0
        tst     r0,r0
        bf      40f
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   ga_src,r3
        mov.w   ga_redo,r0
        add     r0,r3
        mov.l   ga_fbuf2,r2
        mov.w   ga_fn,r0
41:     mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    41b
        add     #4,r2
40:     mov.l   ga_fbuf2,r3         ! static red slice at (7632,200), blue at (7632,264)
        mov.w   ga_vx2,r4
        mov.w   ga_vy,r5
        bsr     ga_slice_st
        nop
        mov.l   ga_fbuf2,r3
        mov.w   ga_blk,r0
        add     r0,r3
        mov.w   ga_vx2,r4
        mov.w   ga_bvy,r5
        bsr     ga_slice_st
        nop
        mov.l   ga_fbuf2,r3         ! moving copies (scrolling right): red at (7616,340), blue at (7616,404)
        mov.w   ga_mvx,r4
        mov.w   ga_mvy,r5
        bsr     ga_slice
        nop
        mov.l   ga_fbuf2,r3
        mov.w   ga_blk,r0
        add     r0,r3
        mov.w   ga_mvx,r4
        mov.w   ga_mbvy,r5
        bsr     ga_slice
        nop
        mov.w   ga_vx,r4            ! background (DFK), half transparent
        mov.w   ga_vy,r5
        mov     #16,r1
        mov.w   ga_128,r2
        mov.l   ga_upv,r6
        mov.l   @r6,r6
        mov.w   ga_x,r7
        mov.l   ga_spr,r0
        jsr     @r0
        nop
        mov.l   ga_lp,r1            ! (its draw word 0x1300A05F, as DFK)
        mov.l   @r1,r2
        add     #-20,r2
        mov.l   ga_blend,r0
        mov.l   r0,@r2
        mov.w   ga_vx2,r0           ! static layer
        mov.l   ga_fvxp,r1
        mov.w   r0,@r1
        mov.w   ga_bvy,r5           ! the blue fill
        bsr     ga_fill
        mov     #0,r10              ! (no blend)
        mov.l   ga_val,r1           ! from the label's level: the red fill over it, more opaque over the next 10%
        mov.l   @r1,r0
        mov.w   ga_60,r1
        sub     r1,r0
        cmp/pl  r0
        bf      32f
        mov     r0,r10              ! (value - level) * 255 / 10%, at most 255
        mov.w   ga_255,r1
        mulu.w  r1,r10
        sts     macl,r10
        mov.w   ga_40,r1
        mov     #0,r0
15:     cmp/hs  r1,r10
        bf      16f
        sub     r1,r10
        bra     15b
        add     #1,r0
16:     mov.w   ga_255,r1
        cmp/hi  r1,r0
        bf      21f
        mov     r1,r0
21:     mov     r0,r10
        tst     r10,r10
        bt      32f
        mov.w   ga_vy,r5
        bsr     ga_fill
        nop
32:     mov.l   r10,@-r15           ! moving layer on top, a quarter opacity
        mov.w   ga_mvx,r0
        mov.l   ga_fvxp,r1
        mov.w   r0,@r1
        mov.w   ga_mbvy,r5
        mov     #64,r10             ! (a quarter opacity)
        bsr     ga_fill
        nop
        mov.l   @r15+,r10
        shlr2   r10                 ! red: a quarter of its static opacity
        tst     r10,r10
        bt      37f
        mov.w   ga_mvy,r5
        bsr     ga_fill
        nop
37:     mov.w   ga_vx,r4            ! the DFK outline on top
        add     #16,r4
        mov.w   ga_vy,r5
        mov     #16,r1
        mov.w   ga_128,r2
        mov.l   ga_upv,r6
        mov.l   @r6,r6
        mov.w   ga_x,r7
        mov.l   ga_spr,r0
        jsr     @r0
        nop
        mov.l   ga_val,r1           ! from 50%: the 烈怒 label over the left end, animated (its 4 frames, in RAM)
        mov.l   @r1,r0
        mov.w   ga_60,r1
        cmp/ge  r1,r0
        bf      13f
        mov.l   ga_lbuf,r10
        mov.l   ga_lok,r1           ! first time: copy it from u4 (slow ROM)
        mov.l   @r1,r0
        tst     r0,r0
        bf      33f
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   ga_src,r3
        mov.w   ga_lbo,r1
        add     r1,r3
        mov     r10,r2
        mov.w   ga_256,r0
        shll2   r0                  ! 4 frames x 256 longs
34:     mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    34b
        add     #4,r2
33:     mov.l   ga_fc,r1            ! frame: (counter / 2) & 3, 1024 bytes each
        mov.l   @r1,r0
        shlr    r0
        and     #3,r0
        shll8   r0
        shll2   r0
        add     r0,r10
        mov.l   ga_upl,r0           ! upload it (16 x 32) at (7632,330)
        mov.w   ga_vx2,r4
        mov.w   ga_lvy,r5
        mov     #16,r6
        mov     #32,r7
        jsr     @r0
        nop
        mov.l   ga_lp,r1
        mov.l   @r1,r2
        mov     r10,r3
        mov.w   ga_256,r0
14:     mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    14b
        add     #4,r2
        mov.l   r2,@r1
        mov.w   ga_vx2,r4
        mov.w   ga_lvy,r5
        mov     #16,r1
        mov     #32,r2
        mov.l   ga_upv,r6
        mov.l   @r6,r6
        mov.w   ga_x,r7
        mov.l   ga_spr,r0
        jsr     @r0
        nop
13:
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
9:      rts
        nop

        .align 1
ga_vx:    .word GA_VX
ga_vx2:   .word GA_VX + 32
ga_vy:    .word GA_VY
ga_bvy:   .word 264
ga_mvx:   .word GA_VX + 16
ga_mvy:   .word 340
ga_mbvy:  .word 404
ga_redo:  .word 32 * 128 * 2
ga_blk:   .word 64 * 64 * 2
ga_skip:  .word 128 - 32
ga_fn:    .word 2 * 64 * 64 / 2
ga_255:   .word 255
ga_40:    .word 3277
ga_128:   .word 128
ga_nfr:   .word 32 * 128 / 2
ga_x:     .word GA_X
ga_lvy:   .word 330
ga_60:    .word 16384             ! the 烈怒 label from 50% (where the GP bonus reaches 3.0)
ga_lbo:   .word 32 * 128 * 2 + 64 * 128 * 2
ga_256:   .word 256
ga_op:    .word 0x8000
        .align 2
ga_vars:  .long v_mode
ga_max:   .long 128 << 8
ga_p1:    .long 0x0C5F9970
ga_hn:    .long hn_frame
ga_hnx:   .long dk_hnext
ga_earn:  .long dk_earn
ga_lastbl: .long dk_lastbl
ga_mult:  .long dk_mult
ga_said:  .long dk_said
ga_blend: .long 0x1300A05F
ga_fvxp:  .long ga_fvx
ga_play:  .long 0x0C5F7E8C
ga_gfx:   .long DFK_GFX + 0x8000
ga_magic: .long 0x47415547       ! 'GAUG'
ga_src:   .long DFK_GFX + 0x8000 + 16
ga_val:   .long dk_gauge
ga_b:     .long dk_boost
ga_in:    .long 0x0C1DCD6C       ! P1 held buttons
ga_upl:   .long 0x0C1D17C0       ! game: upload header
ga_upv:   .long dk_gaup
ga_graze: .long graze
ga_stg:   .long 0x0C31DFDC       ! game: current stage
ga_lstg:  .long dk_lstage
ga_gzc:   .long dk_graze
ga_icy:   .long dk_icy
ga_bossf: .long ga_boss
ga_lp:    .long 0x0C1D1460
ga_lbuf:  .long 0x0CE14000       ! RAM after the fill blocks: the 烈怒 label's 4 frames (4 KB)
ga_fc:    .long 0x0C5F7D60
ga_filok: .long dk_filok
ga_fbuf2: .long 0x0CE10000       ! RAM after the patch area (free): the DFK red + blue fill blocks, 16 KB
ga_bw:    .long 0x13000000
ga_fc2:   .long 0x0C5F7D60
ga_lok:   .long dk_lblok
ga_fok:   .long dk_frmok
ga_fbuf:  .long dk_frm
ga_spr:   .long bd_spr

! r3 = fill block (64 x 64, in RAM), r5 = VRAM y: upload a 16 x 64 slice of it at (7632, r5), scrolling
ga_slice_st:
        bra     ga_sl0
        mov     #0,r0               ! static: start row 0
ga_slice:
        mov.l   gs_fc,r1            ! scroll along the bar (the block's rows = screen x): start row =
        mov.l   @r1,r0              ! (frame counter * 2) & 63, wrapping - 2 px a frame
        add     r0,r0
ga_sl0:
        sts.l   pr,@-r15
        mov.l   r3,@-r15
        mov.l   r0,@-r15
        mov.l   gs_upl,r0
        mov     #16,r6
        mov     #64,r7
        jsr     @r0
        nop
        mov.l   @r15+,r5
        mov.l   @r15+,r3
        mov.l   gs_lp,r1
        mov.l   @r1,r2
        mov     #64,r7              ! 64 rows of 16 pixels (8 longs) from columns 0-15, source stride 128 bytes
8:      mov     r5,r0
        and     #63,r0
        shll2   r0
        shll2   r0
        shll2   r0
        shll    r0                  ! row * 128
        add     r3,r0
        mov     r0,r6
        mov     #8,r0
10:     mov.l   @r6+,r4
        mov.l   r4,@r2
        add     #4,r2
        dt      r0
        bf      10b
        add     #1,r5
        dt      r7
        bf      8b
        mov.l   r2,@r1
        lds.l   @r15+,pr
        rts
        nop

! r5 = VRAM y of the slice, r9 = fill (pixels), r10 = 0 (solid) or the red's opacity 1-255: draw the fill
ga_fill:
        sts.l   pr,@-r15
        mov.l   r11,@-r15
        mov     r5,r11
        mov     r9,r2               ! up to 64, then the rest
        tst     r2,r2
        bt      19f
        mov     #64,r1
        cmp/gt  r1,r2
        bf      17f
        mov     #64,r2
17:     mov.l   gs_fvxp,r4
        mov.w   @r4,r4
        mov     r11,r5
        mov     #12,r1              ! the bar's inside only (columns 2-13)
        mov.l   gs_upv,r6
        mov.l   @r6,r6
        add     #2,r6
        mov.w   gs_x,r7
        mov.l   gs_spr,r0
        jsr     @r0
        nop
        bsr     ga_alpha
        nop
        mov     r9,r2
        add     #-64,r2
        cmp/pl  r2
        bf      19f
        mov.l   gs_fvxp,r4
        mov.w   @r4,r4
        mov     r11,r5
        mov     #12,r1
        mov.l   gs_upv,r6
        mov.l   @r6,r6
        add     #2,r6
        mov.w   gs_x,r7
        add     #64,r7
        mov.l   gs_spr,r0
        jsr     @r0
        nop
        bsr     ga_alpha
        nop
19:     mov.l   @r15+,r11
        lds.l   @r15+,pr
        rts
        nop

! the draw just written gets opacity r10 (0 = leave it solid): word 0x1300AABB, AA = r10, BB = 255 - r10
ga_alpha:
        tst     r10,r10
        bt      1f
        mov.l   gs_lp,r1
        mov.l   @r1,r2
        add     #-20,r2
        mov     r10,r0
        shll8   r0
        mov     #-1,r1
        extu.b  r1,r1
        sub     r10,r1
        or      r1,r0
        mov.l   gs_bw,r1
        or      r1,r0
        mov.l   r0,@r2
1:      rts
        nop
        .align 1
gs_vx2:   .word GA_VX + 32
gs_x:     .word GA_X
        .align 2
gs_upl:   .long 0x0C1D17C0       ! game: upload header
gs_fc:    .long 0x0C5F7D60
gs_lp:    .long 0x0C1D1460
gs_upv:   .long dk_gaup
gs_spr:   .long bd_spr
gs_bw:    .long 0x13000000
gs_fvxp:  .long ga_fvx
ga_fvx:   .long 0                  ! VRAM x of the fill slice ga_fill draws

! Power Mode: the HUD's bomb icon loop (0x0C2806E6) gets 0 bombs, so the old icons are never drawn; in
! their place (same spot in the game's drawing, so on top of the game's bar) NORMAL / BOOST are written
! with the game's font: the selected one gold (NORMAL) / red (BOOST), the other grey. Button 4 switches them (dfk_draw).
        .global bicon_hook
bicon_hook:
        mov.l   bic_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bt      1f
        mov.l   bic_orig,r0
        jmp     @r0
        nop
1:      mov.l   bic_p1,r0
        cmp/eq  r0,r4
        bf      9f                  ! player 2: nothing
        mov.l   bic_play,r1         ! game +0x64: 0 on the select / intro screens, 1 once the bar is in play
        mov.l   @r1,r0
        tst     r0,r0
        bt      9f
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     #0,r9               ! y offsets of the words: HUD offset +16, caller's frame (r14) +8
        mov.l   bic_hud,r1
        mov.l   @(16,r1),r0
        add     r0,r9
        mov.l   @(8,r14),r0
        add     r0,r9
        shlr16  r9
        exts.w  r9,r9
        mov.l   bic_yl,r0
        sub     r9,r0               ! text y follows the bar (the offsets count upwards)
        mov     r0,r9
        mov.l   bic_in,r1           ! P1 newly pressed (+0x10): button 4 = 0x80 switches NORMAL / BOOST
        mov.l   @(16,r1),r0
        tst     #0x80,r0
        mov.l   bic_b,r1
        bt      15f
        mov.l   @r1,r0
        xor     #1,r0
        mov.l   r0,@r1
        mov     #5,r4               ! a sound on the switch: dfkbl's (its phrase 78, copied into the sound ROM as
        mov     #124,r5             ! phrase 248 by the patcher), through the game's sound call
        add     #124,r5
        mov     #104,r6
        mov     #-4,r7
        extu.b  r7,r7               ! 0xFC
        mov.l   bic_se,r0
        jsr     @r0
        nop
        mov.l   bic_b,r1
15:     mov.l   @r1,r8              ! 0 = NORMAL, 1 = BOOST
        mov.l   bic_gfx,r1          ! DFK boxes around the words (from dfkbl, after the atlas in u4)
        mov.l   @r1,r0
        mov.l   bic_magic,r1
        cmp/eq  r1,r0
        bra     2f                  ! bar and boxes: drawn by post_hook now (after the game's sprite flush)
        nop
        mov     #0,r0               ! the list is already closed here (0xFFFFFFFF): step back over the end
        mov.l   r0,@-r15            ! marker, add ours, close it again at the end
        mov.l   bic_lp,r1
        mov.l   @r1,r2
        add     #-4,r2
        mov.l   @r2,r0
        cmp/eq  #-1,r0
        bf      14f
        mov.l   r2,@r1
        mov     #1,r0
        mov.l   r0,@r15
14:     mov.l   bic_dku,r0          ! the DFK atlas (bar, MAXIMUM): RAM copy, upload right here
        jsr     @r0
        nop
        mov.l   bic_bcf,r1          ! first time: copy the boxes from u4 (slow ROM) to RAM
        mov.l   @r1,r0
        tst     r0,r0
        bf      4f
        mov     #1,r0
        mov.l   r0,@r1
        mov.w   bic_bn,r0
        mov.l   bic_bsrc,r3
        mov.l   bic_bram,r2
5:      mov.l   @r3+,r1
        mov.l   r1,@r2
        dt      r0
        bf/s    5b
        add     #4,r2
4:      mov.l   bic_vx,r4           ! upload the boxes over atlas columns 16-31 (the unused DFK words)
        add     #16,r4
        mov.w   bic_bvy,r5
        mov     #16,r6
        mov.w   bic_216,r7
        mov.l   bic_upl,r0
        jsr     @r0
        nop
        mov.w   bic_bn,r0
        mov.l   bic_lp,r1
        mov.l   @r1,r2
        mov.l   bic_bram,r3
6:      mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    6b
        add     #4,r2
        mov.l   r2,@r1
        mov.l   bic_lp,r1           ! draw with dfk_draw's origin (the HUD code has its own)
        mov.l   @(4,r1),r0
        mov.l   r0,@-r15
        mov.l   @(8,r1),r0
        mov.l   r0,@-r15
        mov.l   bic_org,r2
        mov.l   @r2,r0
        mov.l   r0,@(4,r1)
        mov.l   @(4,r2),r0
        mov.l   r0,@(8,r1)
        mov.w   bic_y,r10           ! game "up": -1 plus the bar's offset
        sub     r9,r10
        add     #-1,r10
        mov.l   bic_vx,r4           ! the bar
        mov.w   bic_vy,r5
        mov     #16,r1
        mov.w   bic_240,r2
        mov     r10,r6
        mov     #0,r7
        mov.l   bic_spr,r0
        jsr     @r0
        nop
        mov.l   bic_p1,r1           ! hyper stocked or running: MAXIMUM scrolls behind the words
        mov.w   bic_2e4,r0
        mov.l   @(r0,r1),r0
        cmp/pl  r0
        bt      11f
        mov.w   bic_2e0,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bt      12f
11:     mov.l   bic_sc,r1
        mov.l   @r1,r0
        add     #1,r0
        mov     #95,r2
        cmp/ge  r2,r0
        bf      13f
        mov     #0,r0
13:     mov.l   r0,@r1
        mov.l   bic_vx,r4
        add     #32,r4
        mov.w   bic_vy,r5
        add     r0,r5
        mov     #16,r1
        mov     #96,r2
        mov     r10,r6
        mov     #8,r7
        mov.l   bic_spr,r0
        jsr     @r0
        nop
12:
        mov.l   bic_vx,r4           ! NORMAL box (58 long, rows 0 / 58 = not selected / selected)
        add     #16,r4
        mov.w   bic_bvy,r5
        tst     r8,r8
        bf      7f
        add     #58,r5
7:      mov     #16,r1
        mov     #58,r2
        mov     r10,r6
        mov     #1,r7
        mov.l   bic_spr,r0
        jsr     @r0
        nop
        mov.l   bic_vx,r4           ! BOOST box (50 long, rows 116 / 166)
        add     #16,r4
        mov.w   bic_bvy,r5
        mov.w   bic_116,r0
        add     r0,r5
        tst     r8,r8
        bt      8f
        add     #50,r5
8:      mov     #16,r1
        mov     #50,r2
        mov     r10,r6
        mov     #59,r7
        mov.l   bic_spr,r0
        jsr     @r0
        nop
        mov.l   bic_lp,r1           ! the HUD's origin back
        mov.l   @r15+,r0
        mov.l   r0,@(8,r1)
        mov.l   @r15+,r0
        mov.l   r0,@(4,r1)
        mov.l   @r15+,r0            ! close the list again if it was closed
        tst     r0,r0
        bt      2f
        mov.l   @r1,r2
        mov     #-1,r0
        mov.l   r0,@r2
        add     #4,r2
        mov.l   r2,@r1
2:
        mov.l   bic_gold,r4
        tst     r8,r8
        bf      16f
        mov.l   bic_fc,r1           ! selected: flashes (brighter every other 8 frames)
        mov.l   @r1,r0
        tst     #8,r0
        bt      2f
        mov.l   bic_goldf,r4
        bra     2f
        nop
16:     mov.l   bic_dgold,r4        ! not selected: dim gold
2:      mov.l   bic_col,r0
        jsr     @r0
        nop
        mov     #BIC_X1,r4
        mov     r9,r5
        mov.w   bic_f0,r6
        mova    bic_sn,r0
        mov     r0,r7
        mov.l   bic_ds,r0
        jsr     @r0
        nop
        mov.l   bic_dred,r4         ! not selected: dim red
        tst     r8,r8
        bt      3f
        mov.l   bic_red,r4          ! BOOST selected: red, flashing
        mov.l   bic_fc,r1
        mov.l   @r1,r0
        tst     #8,r0
        bt      3f
        mov.l   bic_redf,r4
3:      mov.l   bic_col,r0
        jsr     @r0
        nop
        mov     #BIC_X2,r4
        mov     r9,r5
        mov.w   bic_f0,r6
        mova    bic_sb,r0
        mov     r0,r7
        mov.l   bic_ds,r0
        jsr     @r0
        nop
        mov.l   bic_cyan,r4         ! separator between the words, in the bar's cyan
        mov.l   bic_col,r0
        jsr     @r0
        nop
        mov     #BIC_XS,r4
        mov     r9,r5
        mov.w   bic_f0,r6
        mova    bic_ss,r0
        mov     r0,r7
        mov.l   bic_ds,r0
        jsr     @r0
        nop
        mov.l   bic_p2b,r0          ! the bombs held as icons in the 2P bomb slots (r4 = text y: they move with
        jsr     @r0                 ! the HUD like NORMAL / BOOST)
        mov     r9,r4
42:
        mov.l   bic_gzf,r0          ! the graze count under the 烈怒 bar
        jsr     @r0
        nop
        mov.l   bic_hx,r0           ! rank digits and HYPER on the top HUD
        jsr     @r0
        nop
        mov.l   bic_white,r4
        mov.l   bic_col,r0
        jsr     @r0
        nop
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
9:      rts
        mov     #0,r0
        .equ BIC_X1, 8              ! screen x of NORMAL / BOOST
        .equ BIC_X2, 72
        .equ BIC_XS, 60             ! the separator (a '|' centred between them)
        .align 1
bic_y:    .word 311               ! screen y (on the bottom bar)
bic_f0:   .word 0xF0
bic_bn:   .word 16 * 216 / 2      ! longs of box pixels
bic_vy:   .word DFK_VY
bic_216:  .word 216
bic_116:  .word 116
bic_bvy:  .word DFK_VY
bic_240:  .word 240
bic_2e4:  .word 0x2E4
bic_2e0:  .word 0x2E0
        .align 2
bic_vars:  .long v_mode
bic_orig:  .long 0x0C1F7BA0       ! game: bombs of player r4
bic_p1:    .long 0x0C5F9970
bic_hud:   .long 0x0C7D3F14
bic_play:  .long 0x0C5F7E8C
bic_gfx:   .long DFK_GFX
bic_magic: .long 0x44464B42       ! 'DFKB'
bic_bcf:   .long dk_bcopy
bic_bsrc:  .long DFK_GFX + 16 + 48 * 240 * 2
bic_bram:  .long dk_boxes
bic_vx:    .long DFK_VX
bic_upl:   .long 0x0C1D17C0       ! game: upload header
bic_lp:    .long 0x0C1D1460       ! list write pointer
bic_spr:   .long bd_spr
bic_org:   .long dk_orgs
bic_dku:   .long dfk_upload
bic_sc:    .long dk_scroll
bic_b:     .long dk_boost
bic_col:   .long 0x0C1DD4B4       ! game: text colour
bic_ds:    .long ORIG_DS
bic_gold:  .long 0x00806020
bic_red:   .long 0x00801010
bic_dgold: .long 0x00483810
bic_dred:  .long 0x00480808
bic_hx:    .long hud_extra
bic_se:    .long 0x0C284A20       ! game: play a sound (r4 channel, r5 phrase, r6 volume, r7)
bic_yl:    .long 311              ! screen y of the words
bic_goldf: .long 0x00807848
bic_redf:  .long 0x00804848
bic_fc:    .long 0x0C5F7D60
bic_cyan:  .long 0x00287080
bic_in:    .long 0x0C1DCD6C
bic_white: .long 0x00808080
bic_gzf:   .long graze_text
bic_p2b:   .long p2_bombs
bic_sn:    .asciz "NORMAL"
        .align 2
bic_sb:    .asciz "BOOST"
        .align 2
bic_ss:    .asciz "|"
        .align 2

        .global dfk_upload
dfk_upload:
        mov.l   dk_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      du_ret
        sts.l   pr,@-r15
        mov.l   dk_gfx,r3
        mov.l   @r3,r0
        mov.l   dk_magic,r1
        cmp/eq  r1,r0
        bf      du_r2               ! no DFK bar in this u4
        mov.l   dk_uc,r1            ! first time: copy the atlas from u4 (slow ROM) to RAM
        mov.l   @r1,r0
        tst     r0,r0
        bf      2f
        mov     #1,r0
        mov.l   r0,@r1
        mov.l   dk_cntl,r0
        mov.l   dk_gfx,r3
        add     #16,r3
        mov.l   dk_cache,r2
3:      mov.l   @r3+,r1
        mov.l   r1,@r2
        dt      r0
        bf/s    3b
        add     #4,r2
2:                                  ! upload it every frame (on MiSTer the area does not keep it)
        mov.l   dk_vx,r4
        mov.l   dk_vy,r5
        mov     #48,r6
        mov.l   dk_240l,r7
        mov.l   dk_upl,r0
        jsr     @r0
        nop
        mov.l   dk_cntl,r0           ! 32 x 240 / 2 longs
        mov.l   dk_lp,r1
        mov.l   @r1,r2
        mov.l   dk_cache,r3
1:      mov.l   @r3+,r4
        mov.l   r4,@r2
        dt      r0
        bf/s    1b
        add     #4,r2
        mov.l   r2,@r1
du_r2:  lds.l   @r15+,pr
du_ret: rts
        nop

! button 4 switches NORMAL / BOOST; hide the game's bottom bar and bomb icons (HUD sheet x 2560-2815,
! y < 256, at the bottom of the screen); draw the DFK bar there
        .global dfk_draw
dfk_draw:
        mov.l   dk_vars,r1
        mov.l   @(4,r1),r0
        cmp/eq  #2,r0
        bf      dd_ret
        mov.l   dk_gfx,r3
        mov.l   @r3,r0
        mov.l   dk_magic,r1
        cmp/eq  r1,r0
        bf      dd_ret
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   dk_lp,r1            ! remember the list origin here (bicon_hook draws with it)
        mov.l   @(4,r1),r0
        mov.l   dk_org,r2
        mov.l   r0,@r2
        mov.l   @(8,r1),r0
        mov.l   r0,@(4,r2)
        mov.l   dk_in,r1            ! P1 newly pressed (+0x10): button 4 = 0x80
        mov.l   @(16,r1),r0
        tst     #0x80,r0
        bt      1f
        mov.l   dk_b,r1
        mov.l   @r1,r0
        xor     #1,r0
        mov.l   r0,@r1
1:      mov.l   dk_lbase,r1         ! walk the frame's list
        mov.l   @r1,r8
        mov     #0,r3               ! game bar pieces hidden (none: not in a game, draw nothing)
        mov.l   dk_mask,r0
        and     r0,r8
        mov.l   dk_ram,r0
        or      r0,r8               ! list start (RAM address)
        mov.l   dk_lp,r1
        mov.l   @r1,r9
        mov.l   dk_mask,r0
        and     r0,r9
        mov.l   dk_ram,r0
        or      r0,r9               ! list end
        mov.l   dk_lp,r1
        mov.l   @(4,r1),r10
        shlr16  r10
        exts.w  r10,r10             ! origin x (native x of game "up" 0)
        mov.w   dk_off,r11
        add     r10,r11             ! off screen (well inside the 13-bit coordinate range)
dd_l:   cmp/hs  r9,r8
        bt      dd_draw
        mov.l   @r8,r0
        cmp/eq  #-1,r0
        bt      dd_draw
        shlr16  r0
        shlr8   r0
        shlr2   r0
        shlr2   r0
        cmp/eq  #1,r0
        bt      dd_d
        cmp/eq  #2,r0
        bt      dd_u
        bra     dd_l
        add     #4,r8
dd_u:   mov.w   @(12,r8),r0
        mov.w   dk_1fff,r1
        and     r1,r0
        add     #1,r0
        mov     r0,r2
        mov.w   @(14,r8),r0
        mov.w   dk_fff,r1
        and     r1,r0
        add     #1,r0
        mul.l   r2,r0
        sts     macl,r0
        add     r0,r0
        add     #16,r0
        bra     dd_l
        add     r0,r8
dd_d:   mov.w   @(6,r8),r0          ! HUD sheet row (y < 256)
        mov.w   dk_fff,r1
        and     r1,r0
        mov.w   dk_256,r1
        cmp/hs  r1,r0
        bt      dd_n
        mov.w   @(4,r8),r0          ! columns 2560-2815
        mov.w   dk_1fff,r1
        and     r1,r0
        mov.w   dk_2560,r1
        cmp/hs  r1,r0
        bf      dd_n
        mov.w   dk_2816,r1
        cmp/hs  r1,r0
        bt      dd_n
        mov.w   @(8,r8),r0          ! near the bottom of the screen (game up -128 .. 63)
        sub     r10,r0
        mov     #64,r1
        cmp/ge  r1,r0
        bt      dd_n
        mov     #-128,r1
        cmp/ge  r1,r0
        bf      dd_n
        mov     r11,r0
        mov.w   r0,@(8,r8)          ! move it off screen
        add     #1,r3
dd_n:   bra     dd_l
        add     #20,r8
dd_draw:
        mov.l   dk_play,r1          ! game +0x64: 1 once the bar is in play (not on select / intro screens)
        mov.l   @r1,r0
        tst     r0,r0
        bt      dd_none
        mov.l   dk_vx,r4            ! the bar
        mov.l   dk_vy,r5
        mov     #16,r1
        mov.l   dk_240l,r2
        mov     #-1,r6              ! game up -1 (where the bomb bar was)
        mov     #0,r7               ! game x 0
        mov.l   dk_spr,r0
        jsr     @r0
        nop
        mov.l   dk_p1,r1            ! hyper stocked or running: MAXIMUM scrolls right to left behind the words
        mov.w   dk_2e4,r0
        mov.l   @(r0,r1),r0
        cmp/pl  r0
        bt      9f
        mov.w   dk_2e0,r0
        mov.l   @(r0,r1),r0
        tst     r0,r0
        bt      3f
9:
        mov.l   dk_sc,r1
        mov.l   @r1,r0
        add     #1,r0
        mov     #95,r2
        cmp/ge  r2,r0
        bf      4f
        mov     #0,r0
4:      mov.l   r0,@r1
        mov.l   dk_vx,r4
        add     #32,r4
        mov.l   dk_vy,r5
        add     r0,r5               ! window start in the strip
        mov     #16,r1
        mov     #96,r2
        mov     #-1,r6
        mov     #8,r7               ! over both cells (game x 8-103)
        mov.l   dk_spr,r0
        jsr     @r0
        nop
3:      mov.l   dk_b,r1             ! boxes and words: 4 sprites from dk_tab (NORMAL / BOOST selected)
        mov.l   @r1,r8
        mova    dk_tab,r0
        mov     r0,r9
        tst     r8,r8
        bt      7f
        add     #24,r9
7:      mov     #2,r10              ! the two boxes (NORMAL / BOOST are written by bicon_hook)
8:      mov.l   dk_vx,r4
        add     #16,r4
        mov.w   @r9+,r5             ! atlas row
        mov.l   dk_vy,r0
        add     r0,r5
        mov.w   @r9+,r2             ! height (game x span)
        mov.w   @r9+,r7             ! game x
        mov     #16,r1
        mov     #-1,r6
        mov.l   dk_spr,r0
        jsr     @r0
        nop
        dt      r10
        bf      8b
dd_none:
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
dd_ret: rts
        nop
        .align 2
dk_vars:  .long v_mode
dk_240l:  .long 240

dk_cntl:  .long 48 * 240 / 2     ! atlas longs
dk_gfx:   .long DFK_GFX
dk_magic: .long 0x44464B42       ! 'DFKB'
dk_vx:    .long DFK_VX
dk_vy:    .long DFK_VY
dk_upl:   .long 0x0C1D17C0       ! game: upload header
dk_spr:   .long bd_spr
dk_lp:    .long 0x0C1D1460       ! list write pointer (+4 origin)
dk_lbase: .long 0x0C1D1454
dk_mask:  .long 0x00FFFFFF
dk_ram:   .long 0x0C000000
dk_in:    .long 0x0C1DCD6C
dk_b:     .long dk_boost
dk_uc:    .long dk_ucnt
dk_org:   .long dk_orgs
dk_play:  .long 0x0C5F7E8C
dk_cache: .long dk_atlas
dk_p1:    .long 0x0C5F9970
dk_sc:    .long dk_scroll
dk_off:   .word 2000
dk_1fff:  .word 0x1FFF
dk_fff:   .word 0x0FFF
dk_256:   .word 256
dk_2560:  .word 2560
dk_2816:  .word 2816
dk_2e4:   .word 0x2E4
dk_2e0:   .word 0x2E0
        .align 2
dk_boost: .long 0                 ! 0 = NORMAL, 1 = BOOST
dk_ucnt:  .long 0                 ! 1 = atlas copied to dk_atlas (title_hook clears it)
dk_hgate: .long 0                 ! bar_draw: health bars wanted this frame
dk_bcopy: .long 0                 ! 1 = the boxes are copied to dk_boxes
dk_gauge: .long 0                 ! BOOST gauge fill (pixels << 8)
dk_said:  .long 0                 ! 1 = HYPER SYSTEM READY was said for the waiting stock
dk_hcopy: .long 0                 ! 1 = the DFK atlas is in dk_atlas (dfk_hud)
dk_mult:  .long 0                 ! bomb multiplier (0 = none, else 2-99)
dk_hwas:  .long 0                 ! in a hyper last frame (hn_frame)
dk_hnext: .long 0                 ! meter banked during the hyper
dk_hcnt:  .long 0                 ! its tick countdown (read as dk_hwas + 8)
dk_rkid:  .long 0, 0              ! rank digit sprites (tens, ones) noted by rkd_hook
dk_rkbuf: .long 0                 ! the rank text
dk_rdyok: .long 0                 ! 1 = ready_hook let the voice play (the banner may show)
dk_sadok: .long 1                 ! 1 = the last hyper item added a stock (its notification shows)
dk_lblpos: .long 50 << 16, 278 << 16 ! the HYPER Lv label's position (HUD shake)
dk_hlast: .long 0                 ! the hyper stock last frame (HYPER turning gold)
dk_frmok: .long 0                 ! dk_frm filled
dk_filok: .long 0                 ! dk_fill filled
dk_lblok: .long 0                 ! dk_lbl filled
dk_icy:   .long 0                 ! INSERT COIN's last draw height (16.16), 0 = not yet
dk_icfc:  .long 0                 ! the frame it was last drawn (read as dk_icy + 4)
dk_lstage: .long 0               ! the stage graze was last counted in
dk_graze: .long 0                 ! bullets / enemies grazed (shown under the 烈怒 bar)
dk_gbuf:  .long 0, 0, 0, 0, 0     ! its text ("GRAZE " + up to 9 digits)
dk_gaup:  .long 270               ! gauge height this frame (ga_boss)
dk_earn:  .long 0                 ! bombs earned from pickups (Power Mode)
dk_lastbl: .long 0                ! lives << 8 | bombs seen last frame
sf_zero:  .space 128                ! zero bullet pattern for the streams
dk_orgs:  .long 0, 0              ! list origin seen by dfk_draw
dk_scroll: .long 0                ! MAXIMUM scroll position (0-94)
        .align 2
dk_tab:                             ! atlas row, height, game x: NORMAL selected, then BOOST selected
        .word 58, 58, 1,    116, 50, 59,   0, 0, 0,     0, 0, 0
        .word 0, 58, 1,     166, 50, 59,   0, 0, 0,     0, 0, 0
        .align 2
        .align 2
dk_atlas: .space 48 * 240 * 2      ! RAM copy of the DFK atlas pixels
dk_boxes: .space 16 * 216 * 2      ! RAM copy of the boxes
dk_frm:   .space 32 * 128 * 2      ! the DFK gauge frame block (32 x 128), copied from u4 once
_end:
