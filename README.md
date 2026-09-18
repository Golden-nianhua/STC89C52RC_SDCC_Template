# STC89C52RC 课程实验

这是基于 CLion、CMake、SDCC 4.6 和 stcgal 的 STC89C52RC 课程实验工程。
每套子实验只使用一个源码文件。CMake 自动创建固件目标，工程另外生成两个 CLion 烧录运行配置。

## 源码组织

```text
Labs/
  Lab01/    第 1 个实验；可放 C 或汇编子实验
  Lab02/    第 2 个实验；可放 C 或汇编子实验
  ...
  Lab08/    第 8 个实验；可放 C 或汇编子实验
Include/    C 实验共用的寄存器和编译器兼容头文件
Misc/       CLion 编译器定义和 STC 下载配置
```

源码直接放在对应实验目录下，不再为子实验建立额外目录。文件名使用 ASCII 的
`序号_功能` 格式，例如：

```text
Labs/Lab01/01_led.asm       -> lab01_01_led
Labs/Lab05/02_uart.c        -> lab05_02_uart
```

所有 Lab 目录都同时接受 `.asm` 和 `.c`：汇编文件使用 SDAS8051 流程，C 文件使用
SDCC C 流程。请勿在同一 Lab 中放置主文件名相同、扩展名不同的两个源码文件。
新增、删除或重命名源码后，CMake 会自动重新生成，无需修改 `CMakeLists.txt`。
每套源码的固件目标和两个烧录运行配置会自动归入同名文件夹，无需在 CLion 中手工整理。

## 命令行使用

默认 SDCC 路径为 `D:/Code/c-env/SDCC/SDCC-4.6.0`。CMake 可通过缓存变量
`SDCC_ROOT` 覆盖该路径，`tools/stc.ps1` 可通过同名环境变量覆盖。

首次下载前创建本机配置：

```powershell
Copy-Item Misc/stcgal.example.toml Misc/stcgal.toml
```

修改 `Misc/stcgal.toml` 中的串口和硬件选项。该文件已被 Git 忽略，当前电脑的
串口号不会影响其他使用者。

本课程板使用 `DTR`、`RTS`、PNP 三极管和 PMOS 组成自动下载电路。实测切换 RTS
时 DTR 保持无效高电平，RTS 有效（低电平）时断电。将 `auto_power_cycle` 设为
`true`、`reset_pin` 设为 `"rts"` 后，下载前会自动断电约 250 ms 再重新上电。
`keep_dtr_inactive = true` 会在 RTS 脉冲前明确释放 DTR，保证满足板载 PNP 的断电条件。

### 手动使用 CMake

这套方式与 CLion 使用相同的编译、链接和固件生成流程。第一次使用或修改 CMake 配置后
先配置预设，随后按 target 名编译：

```powershell
# 生成 Debug 构建目录
cmake --preset STC89-Debug

# 编译单个实验
cmake --build build/Debug --target lab01_01_led

# 编译全部实验
cmake --build build/Debug --target coursework_all_build

# 检查下载配置或读取芯片信息
cmake --build build/Debug --target stc_config_check_build
cmake --build build/Debug --target stc_info_build
```

固件生成到 `build/Debug/firmware`。每次实际重新链接后会输出 CODE、IRAM、XRAM
使用量和固件文件大小。编译完成后可手动调用下载入口：

```powershell
# 保留芯片当前硬件选项
D:/Code/uv/uv.exe run --script tools/stcgal_runner.py `
    --config Misc/stcgal.toml flash `
    --image build/Debug/firmware/lab01_01_led.ihx

# 写入 stcgal.toml 中的硬件选项
D:/Code/uv/uv.exe run --script tools/stcgal_runner.py `
    --config Misc/stcgal.toml flash-with-options `
    --image build/Debug/firmware/lab01_01_led.ihx
```

### 手动使用 SDCC 和 stcgal

这套方式完全跳过 CMake 和 CLion。以下命令在工程根目录执行，产物放在
`build/manual`。

汇编源码需要先用 SDAS8051 生成 `.rel`，再用 SDCC 链接：

```powershell
$sdccRoot = "D:\Code\c-env\SDCC\SDCC-4.6.0"
$output = "build\manual"
$name = "lab01_01_led"
New-Item -ItemType Directory -Force $output | Out-Null

& "$sdccRoot\bin\sdas8051.exe" -ols `
    "$output\$name.rel" "Labs\Lab01\01_led.asm"

& "$sdccRoot\bin\sdcc.exe" -mmcs51 --model-small --nostdlib `
    --code-size 8192 --iram-size 256 --xram-size 256 `
    "$output\$name.rel" -o "$output\$name.ihx"
```

C 源码可直接由 SDCC 编译和链接：

```powershell
$sdccRoot = "D:\Code\c-env\SDCC\SDCC-4.6.0"
$output = "build\manual"
$name = "lab05_01_example"
New-Item -ItemType Directory -Force $output | Out-Null

& "$sdccRoot\bin\sdcc.exe" -mmcs51 --model-small --std-c11 `
    --code-size 8192 --iram-size 256 --xram-size 256 `
    -IInclude "Labs\Lab05\01_example.c" -o "$output\$name.ihx"
```

如需 HEX 和 BIN，再转换已生成的 IHX：

```powershell
& "$sdccRoot\bin\packihx.exe" "$output\$name.ihx" |
    Set-Content -Encoding ascii "$output\$name.hex"
& "$sdccRoot\bin\makebin.exe" -p `
    "$output\$name.ihx" "$output\$name.bin"
```

然后手动调用 stcgal 下载入口。它仍读取 `Misc/stcgal.toml`，因此串口、自动冷启动和
硬件选项的行为与 CLion 一致：

```powershell
D:/Code/uv/uv.exe run --script tools/stcgal_runner.py `
    --config Misc/stcgal.toml flash `
    --image build/manual/lab01_01_led.ihx
```

将 `flash` 换成 `flash-with-options`，可在下载时写入配置文件中的硬件选项。

### 使用 SDCC + stcgal 脚本

`tools/stc.ps1` 是上一套手动流程的最简封装。只需传入 `LabXX\文件名.asm` 或
`LabXX\文件名.c`，脚本会自动选择汇编或 C 流程，产物统一放在 `build/direct`：

```powershell
# 只编译
.\tools\stc.ps1 Lab01\01_led.asm -Build

# 只烧录 build/direct 中已有的固件
.\tools\stc.ps1 Lab01\01_led.asm -Flash

# 先编译再烧录
.\tools\stc.ps1 Lab01\01_led.asm -Build -Flash
```

脚本烧录使用 `Misc/stcgal.toml`，并保留芯片当前硬件选项。如 SDCC 安装在其他目录，
可先设置环境变量，例如 `$env:SDCC_ROOT = "D:\Tools\SDCC"`。

未启用自动冷启动时，出现 `Waiting for MCU, please cycle power` 后再手动断电上电。

### 在 CLion 中运行并烧录

CMake target 由 CLion 自动生成不带后缀的运行配置，工程另外生成两个共享烧录配置；
三者统一放在同名实验文件夹中：

- `<目标名>`：点击“运行”构建固件，不执行烧录。
- `<目标名>_flash`：点击“运行”，先构建固件，再烧录并保留硬件选项。
- `<目标名>_flash_with_options`：点击“运行”，先构建固件，再烧录并写入硬件选项。

烧录配置不出现在 CMake 构建目标列表中，不能通过“构建”执行烧录。新增实验源码并重新加载
CMake 后，一个固件目标和两个烧录配置会自动同步。STC89 的串口 ISP
不支持在线调试，因此“调试”按钮不能用于源码级调试。

`coursework_all`、`stc_config_check` 和 `stc_info` 也是共享运行配置：

- 点击“运行”直接执行对应操作，不先执行 CMake 构建步骤。
- 点击“构建”仍执行对应操作，实验 target 按实验文件夹归类。
- `coursework_all` 的操作本身就是构建全部实验；“不先构建”表示运行前不会再额外重复构建一次。

## 单文件约束

汇编源码必须在同一个 `.asm` 文件中包含复位入口、所需中断向量和全部实验逻辑。
SDCC 链接所需的空 `PSEG`、`XSEG` 段也在该文件中声明。

C 实验可以包含 `stc89.h`，但每套实验的函数和逻辑仍全部写在自己的 `.c` 文件中。
`Include` 仅提供寄存器定义及 SDCC/Keil C51 语法兼容，不包含实验实现。

## Keil C51

任意 Lab 中的同一个 `.c` 文件都可以加入 Keil C51 工程，只需把 `Include` 加入
C51 Include Paths。`compiler.h` 和 `stc89.h` 会按编译器选择相应的寄存器、位变量、
中断和存储空间语法。`.asm` 文件使用 SDAS8051 汇编语法，不直接兼容 Keil A51。
