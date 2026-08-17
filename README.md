# SN3218-Simulink

A Simulink block for the **SN3218** 18-channel constant-current LED driver on Raspberry Pi.

Drives all 18 channels over I²C with gamma correction, and handles device
initialisation for you. Written for the underlighting on a
[Pimoroni Trilobot](https://shop.pimoroni.com/products/trilobot), but the
SN3218 is a generic part and the block works with any board carrying one.

## Requirements

- MATLAB and Simulink R2026a
- [Simulink Support Package for Raspberry Pi Hardware](https://www.mathworks.com/hardware-support/raspberry-pi-simulink.html)
- I²C enabled on the Pi: `sudo raspi-config nonint do_i2c 0`

## Install

Double-click `releases/sn3218.mltbx`, or from MATLAB:

```matlab
matlab.addons.install("releases/sn3218.mltbx")
```

The block then appears in the Simulink Library Browser under
**Custom Raspberry Pi Blockset**.

## The block

```
        ┌──────────────────┐
 pwm ──▶│      SN3218      │
        │ 18-ch LED driver │
        │     I2C 0x54     │
        └──────────────────┘
```

| | |
|---|---|
| **`pwm`** | `uint8`, 18 elements. Per-channel brightness, 0–255. |
| **`Board`** | Mask parameter. Hardware board, from `Model B Rev1` through `Compute Module 5`. Default `Pi 3 Model B+`. |

`Board` is pushed down onto every inner I²C block by a self-modifiable mask,
because the board setting is a popup and cannot be promoted by expression.

The I²C bus (1) is set on the inner blocks rather than the mask.

## How it works

The SN3218 sits at a fixed address of **0x54** and has no address pins.

| Register | Purpose |
|---|---|
| `0x00` | Shutdown — `0x01` = normal operation, `0x00` = output off |
| `0x01`–`0x12` | PWM duty for channels 1–18 |
| `0x13`–`0x15` | Output enable, 6 bits per register |
| `0x16` | Update — any write latches `0x01`–`0x15` into the outputs |
| `0x17` | Reset — write `0xFF` to restore power-on defaults |

**At initialisation** an Initialize Function subsystem runs three writes, in
order: reset (`0x17` ← `0xFF`), normal operation (`0x00` ← `0x01`), then all
18 outputs enabled (`0x13` ← `[63 63 63]`, auto-incrementing across
`0x13`–`0x15`). These land in the generated `model_initialize()` and never
run again.

**Every step** the block gamma-corrects `pwm`, writes all 18 bytes to `0x01`
in one auto-incrementing transaction, then latches with `0x16` ← `0xFF`.
Block priorities enforce that ordering — the update register must be written
*after* the PWM data, or you latch stale values.

That is two I²C transactions per step, about 21 bytes, roughly 2 ms of bus
time at the Pi's default 100 kHz. Size your sample time accordingly.

### Gamma

The LEDs are perceptually non-linear, so `pwm` passes through a 256-entry
lookup table before it reaches the device:

```matlab
uint8(round(255*((0:255)/255).^2.2))
```

A power law is used rather than the exponential curve common in SN3218
libraries, because it preserves both endpoints: `0` is fully off and `255`
is fully on. An exponential of the form `255^(i/255)` cannot do this —
anything raised to the power 0 is 1, so it either leaves the LEDs faintly
lit at `pwm = 0` or, if the exponent is shifted to fix that, caps full
brightness at 249. The power law also yields 184 distinct output levels
against 124, so fades band noticeably less.

The cost is a dead zone: the lowest 15 input codes all map to 0. That is
inherent to 8-bit-in, 8-bit-out gamma. Raising the exponent to 2.8 (the
other common LED value) deepens the roll-off but costs a further 21 levels
and widens the dead zone to 28 codes.

To bypass correction entirely, right-click the `Gamma` block and choose
**Comment Through**.

## Notes

**Blanking the array** is done by writing zeros to `pwm`. The block leaves
`0x00` in normal operation after init.

**Portability.** The register map and byte packing are target-neutral, but
the five I²C blocks come from `raspberrypiCommlib` and are Pi-specific.
Porting to another target means swapping that layer, not editing the logic.

## Building from source

```matlab
buildtool          % clean, code check, then package to releases/sn3218.mltbx
```

Individual tasks: `buildtool clean`, `buildtool check`, `buildtool archive`.

If you have the packaged toolbox installed *and* the repo open, the
installed copy shadows `tbx/sn3218/sn3218.slx` on the MATLAB path. Uninstall
the add-on while developing.

## License

MIT — see [LICENSE](LICENSE).
