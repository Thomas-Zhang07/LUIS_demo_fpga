# DEPRECATED — do not use (historical backup)

This directory (`other_fpga_code/fpga_code_bak`) is a **historical backup** of an
earlier `fpga_code` tree. It is **not** the verified firmware for either board.
Do not build it, flash it, or use it as the starting point for new work.

**Use instead:**

- **Primary board:** `E:\LUIS\IPP\fpga\primary`
  (GitHub: `Thomas-Zhang07/sonic_surface_directional_speaker_fpga_primary`, `main`)
- **Secondary board:** `E:\LUIS\IPP\fpga\secondary`
  (GitHub: `Thomas-Zhang07/sonic_surface_directional_speaker_fpga_secondary`, `main`)
- **Old secondary source, reference only:** `E:\LUIS\IPP\fpga\reference\secondary-original`

## Most likely reason it failed on the board

This tree is a **hybrid of two board roles**:

- **Top level:** primary (`MISC_D` output, primary pin map, no `MISC_A` sync input).
- **`Distribute`:** secondary `PHASE_CORRECTION` table **and** secondary board-select polarity.

It therefore matches neither board:

- On a **primary** board, the secondary correction table gives every wire the
  wrong phase (many channels shift by 8 bins = 180°), so the beam is scrambled.
- On a **secondary** board, the top level never accepts the `MISC_A` 40 kHz
  sync, so its carrier is not phase-locked to the primary.
- The primary host enables the board with `0xC0`, but this tree treats `0xC0`
  as **disable** (`0xC1` enables). Since `0xFE` is accepted only while
  `s_boardEnable = '1'`, a host that sends `0xC0` first gets no frame at all.

The UART is **not** the cause: the BDF overrides `g_CLKS_PER_BIT` to `133`,
which is 5.12 MHz / 38.4 kBaud, matching the host. The failure is the board-role
and correction-table mix, plus stale project settings that can prevent a clean
rebuild (see below).

## Why this tree is wrong / unsafe to use

1. **Primary/secondary configuration mismatch.**
   - The top level is the **primary** variant (`MISC_D` output), but
     `src/Distribute.vhd` has the **secondary** `PHASE_CORRECTION` table active
     (first values `8, 8, 0, 0, 0, 8, ...`); the primary table is commented out.
   - The board-select polarity is also the **secondary** polarity:
     `0xC0` disables and `0xC1` enables. The primary board expects
     `0xC0` enable / `0xC1` disable.
   - Result: a primary board built from this tree gets the wrong per-channel
     phase correction and the wrong enable/disable behavior.

2. **Stale project settings that are not part of this design.**
   - Partition assignments for `DoubleBufferManualSwitch` and
     `acousticLevitation`.
   - SignalTap enabled with `output_files/stp2.stp`.
   - EDA/VHDL testbench assignments for `src/testPhaseLine.vhd`
     (`PhaseLinetemp`).
   - `CDF_FILE Chain2.cdf`, a stale/missing file.
   These produce warnings/errors and make the build non-reproducible.

3. **Stale/confusing PLL metadata.**
   - `src/Masterclock.vhd` uses 128/1250 (5.12 MHz from 50 MHz), but its embedded
     wizard retrieval info still says `EFF_OUTPUT_FREQ_VALUE0 = 10.240000`.
   - The root `Masterclock.qip` is 0 bytes (the qsf references the valid
     `src/Masterclock.qip`), which is easy to get wrong.

4. **Superseded feature set.**
   - This tree predates the per-channel duty amplitude weighting (high-nibble
     amplitude code, centred variable-width pulses) and the verified
     5.12 MHz / 16-phase / 38.4 kBaud configuration.
   - `DutyLine.vhd` is only an unused prototype, not wired into the array.
   - The `QuadrupleBuffer_epcs16.jic` and other `board*_*.jic` images in this
     directory are old; do not flash them.

## What to do

- Primary board: use `fpga/primary` and its `QuadrupleBuffer_primary.jic`.
- Secondary board: use `fpga/secondary` after the role changes; the old
  10.24 MHz secondary source is kept at `fpga/reference/secondary-original`
  for reference only.
- Keep this directory only for inspecting old history. The working tree may
  contain local edits and large build artifacts; it is not a buildable,
  validated project.
