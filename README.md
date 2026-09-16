# STC89C52RC 课程实验

这是基于 CLion、CMake、SDCC 4.6 和 stcgal 的 STC89C52RC 课程实验工程。
每套子实验只使用一个源码文件，CMake 会自动发现源码并创建独立的编译、固件和下载目标。

## 源码组织

```text
Labs/
  Lab01/    汇编实验
  Lab02/    汇编实验
  Lab03/    汇编实验
  Lab04/    汇编实验
  Lab05/    C 实验
  Lab06/    C 实验
  Lab07/    C 实验
  Lab08/    C 实验
Include/    C 实验共用的寄存器和编译器兼容头文件
Misc/       CLion 编译器定义和 STC 下载配置
```

源码直接放在对应实验目录下，不再为子实验建立额外目录。文件名使用 ASCII 的
`序号_功能` 格式，例如：

```text
Labs/Lab01/01_led.asm       -> lab01_01_led
Labs/Lab05/02_uart.c        -> lab05_02_uart
```

Lab01 至 Lab04 只接受 `.asm`，使用 SDAS8051 语法；Lab05 至 Lab08 只接受 `.c`。
新增、删除或重命名源码后，CMake 会自动重新生成，无需修改 `CMakeLists.txt`。
每套源码的编译目标和两个下载目标会自动归入同名文件夹，无需在 CLion 中手工整理。

## 配置与编译

默认 SDCC 路径为 `D:/Code/c-env/SDCC/SDCC-4.6.0`。其他安装位置可通过
`SDCC_ROOT` CMake 缓存变量覆盖。

```powershell
cmake --preset STC89-Debug
cmake --build build/Debug --target lab01_01_led
```

编译所有已有实验：

```powershell
cmake --build build/Debug --target coursework_all
```

固件统一生成到 `build/Debug/firmware`，每个目标包含 `.ihx`、`.hex`、`.bin`、
`.map` 和 `.mem` 等文件。CLion 的 CMake 工具窗口中也会显示相同的目标。
每次实际重新链接固件后，构建末尾会按 GNU ld `--print-memory-usage` 的表格风格输出
CODE、静态 IRAM、XRAM 的使用量、配置容量、占用率，以及固件文件大小。

## 下载程序

首次使用时创建本机配置：

```powershell
Copy-Item Misc/stcgal.example.toml Misc/stcgal.toml
```

修改 `Misc/stcgal.toml` 中的串口和硬件选项。该文件已被 Git 忽略，当前电脑的
串口号不会影响其他使用者。

本课程板使用 `DTR`、`RTS`、PNP 三极管和 PMOS 组成自动下载电路。实测切换 RTS
时 DTR 保持无效高电平，RTS 有效（低电平）时断电。将 `auto_power_cycle` 设为
`true`、`reset_pin` 设为 `"rts"` 后，下载前会自动断电约 250 ms 再重新上电。
`keep_dtr_inactive = true` 会在 RTS 脉冲前明确释放 DTR，保证满足板载 PNP 的断电条件。

```powershell
# 检查本机配置
cmake --build build/Debug --target stc_config_check

# 读取芯片信息
cmake --build build/Debug --target stc_info

# 编译并下载指定实验，保留芯片当前硬件选项
cmake --build build/Debug --target lab01_01_led_flash

# 编译并下载，同时写入 stcgal.toml 中的硬件选项
cmake --build build/Debug --target lab01_01_led_flash_with_options
```

未启用自动冷启动时，出现 `Waiting for MCU, please cycle power` 后再手动断电上电。

### 在 CLion 中运行并烧录

CMake 会为每套实验已有的三个目标补充同名运行配置，不会新增第四个目标：

- `<目标名>`：点击运行时只编译固件，不烧录。
- `<目标名>_flash`：点击运行时执行现有普通烧录目标。
- `<目标名>_flash_with_options`：点击运行时执行现有烧录目标并写入硬件选项。

新增实验源码并重新加载 CMake 后，这三个目标的运行配置会自动同步。STC89 的串口 ISP
不支持在线调试，因此“调试”按钮不能用于源码级调试。

## 单文件约束

汇编源码必须在同一个 `.asm` 文件中包含复位入口、所需中断向量和全部实验逻辑。
SDCC 链接所需的空 `PSEG`、`XSEG` 段也在该文件中声明。

C 实验可以包含 `stc89.h`，但每套实验的函数和逻辑仍全部写在自己的 `.c` 文件中。
`Include` 仅提供寄存器定义及 SDCC/Keil C51 语法兼容，不包含实验实现。

## Keil C51

Lab05 至 Lab08 的同一个 `.c` 文件可以加入 Keil C51 工程，只需把 `Include` 加入
C51 Include Paths。`compiler.h` 和 `stc89.h` 会按编译器选择相应的寄存器、位变量、
中断和存储空间语法。Lab01 至 Lab04 使用 SDAS8051 汇编语法，不直接兼容 Keil A51。
