# STC89C52RC SDCC template

CLion/CMake template for the STC89C52RC using SDCC's MCS-51 backend.

## Configure and build

The default toolchain location is `D:/Code/c-env/SDCC/SDCC-4.6.0`. Override
the `SDCC_ROOT` CMake cache variable when SDCC is installed elsewhere.

```powershell
cmake --preset STC89C52RC-Debug
cmake --build build/Debug
```

Release builds use `STC89C52RC-Release` and `build/Release`. A successful build
produces `.ihx`, `.hex`, `.bin`, `.map`, and `.mem` files.

CLion discovers the two configure presets as CMake profiles. The project-level
custom compiler definition in `Misc/custom-compiler-sdcc-mcs51.yaml` supplies
SDCC 4.6.0 MCS-51 built-ins and syntax shims for code insight.

## Flash with stcgal

Install the pinned programmer once:

```powershell
D:\Code\uv\uv.exe tool install stcgal==1.10
```

Edit `Misc/stcgal.toml` to select the serial port, baud rates, protocol, and
documented STC89 hardware options. Validate it without opening the serial port:

```powershell
cmake --build build/Debug --target stc-config-check
cmake --build build/Debug --target stc-info
cmake --build build/Debug --target flash
```

`stc-info` is read-only: it reports the detected model, oscillator frequency,
BSL version, and current hardware options without erasing or programming.
The `flash` target programs the current `.ihx` file and preserves the option
byte already stored in the MCU. The separate `flash-with-options` target writes
every option in the TOML file and should be used only after reviewing them.
Power-cycle the target when stcgal prints `Waiting for MCU, please cycle power`.

## Keil C51

The register and interrupt declarations also support Keil C51. Create an
STC89C52RC project in uVision, add the required `Core/Src` and `Drivers/Src`
files, and add `Drivers/Inc` to the C51 include paths. Do not add
`Core/Src/delay.asm`; it uses SDCC's ASxxxx syntax. C source can use the
portable macros from `compiler.h` with either compiler.
