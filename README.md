# STC89C52RC SDCC 模板

这是一个面向 CLion 的 STC89C52RC 单固件工程模板，使用 SDCC 的 MCS-51 后端编译，并提供固件转换、空间统计、stcgal 下载和 Keil C51 源码兼容支持。

## 配置和构建

默认 SDCC 路径为 `D:/Code/c-env/SDCC/SDCC-4.6.0`。安装位置不同时，可通过 CMake 缓存变量 `SDCC_ROOT` 覆盖。

```powershell
cmake --preset STC89C52RC-Debug
cmake --build build/Debug
```

Release 构建使用：

```powershell
cmake --preset STC89C52RC-Release
cmake --build build/Release
```

固件统一生成在构建目录的 `firmware` 文件夹中，包括 `.ihx`、`.hex`、`.bin`、`.map` 和 `.mem`。每次构建结束会输出 GNU ld 风格的 CODE、IRAM、XRAM 使用量以及各固件文件大小。

CLion 会自动识别两个 CMake 预设。`Misc/custom-compiler-sdcc-mcs51.yaml` 为代码分析提供 SDCC 4.6.0 MCS-51 的内置宏和语法兼容定义。

## 配置 stcgal

下载工具固定使用 `stcgal==1.10`，由 uv 自动创建隔离环境，无需手动维护 Python 环境。首次使用时复制示例配置：

```powershell
Copy-Item Misc/stcgal.example.toml Misc/stcgal.toml
```

然后修改 `Misc/stcgal.toml` 中的串口、波特率、协议、自动冷启动和硬件选项。本机配置已被 Git 忽略，不会误提交串口号等机器相关信息。

自动冷启动相关配置：

- `auto_power_cycle = true`：烧录和读取信息前由 stcgal 自动控制目标板电源。
- `reset_pin = "rts"`：使用 RTS 控制自动下载电路；也可按硬件改为 `"dtr"`。
- `keep_dtr_inactive = true`：RTS 动作前显式保持 DTR 无效，适用于本模板验证过的 PNP/PMOS 电源控制电路。

`Misc/stcgal.example.toml` 对每个布尔硬件选项均有中文说明，分别解释 `true` 和 `false` 的实际效果。

## 构建、读取与下载

```powershell
cmake --build build/Debug --target stc-config-check
cmake --build build/Debug --target stc-info
cmake --build build/Debug --target flash
cmake --build build/Debug --target flash-with-options
```

- `stc-config-check`：检查 TOML，并显示自动冷启动及硬件选项效果。
- `stc-info`：只读取芯片型号、时钟、BSL 版本和当前硬件选项。
- `flash`：构建并下载程序，保留芯片当前硬件选项。
- `flash-with-options`：构建并下载程序，同时写入 TOML 中配置的硬件选项。

请在确认配置后再使用 `flash-with-options`，因为它会改变芯片硬件选项。

## 在 CLion 中点击运行

CMake 配置时会在 `.idea/runConfigurations` 生成三个本机运行配置，并在 CLion 中归入同一个目标文件夹：

- `STC89C52RC_SDCC_Template`：只构建固件，不烧录。
- `flash`：构建并普通烧录，保留硬件选项。
- `flash-with-options`：构建、烧录并写入硬件选项。

这些配置让 CLion 的“运行”按钮执行对应的 CMake 构建目标；生成文件已被 Git 忽略，不会污染模板仓库。

## Keil C51 兼容

C 源码中的寄存器和中断声明同时兼容 SDCC 与 Keil C51。使用 uVision 时，新建 STC89C52RC 工程，加入需要的 `Core/Src`、`Drivers/Src` 和 `Hardware/Src` 文件，并将对应 `Inc` 目录加入 C51 Include Paths。

不要把 `Core/Src/delay.asm` 加入 Keil 工程，它使用 SDCC ASxxxx 汇编语法。C 源码应通过 `compiler.h` 中的可移植宏声明中断和编译器扩展。
