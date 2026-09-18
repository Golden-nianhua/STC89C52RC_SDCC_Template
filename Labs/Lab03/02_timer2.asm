; Lab03-02：使用定时器2自动重装生成实时时钟，显示“时 分 秒”。
; 汇编器：SDCC 工具链中的 SDAS8051。
; 时钟参数：12 MHz 晶振、6T 模式，定时器每 0.5 us 加 1。
; 定时周期：65536 - 0x3CB0 = 50000，50000 * 0.5 us = 25 ms。
; -----------------------------------------------------------------------------
        .module  lab03_02_timer2     ; 声明当前汇编模块名称。
; -----------------------------------------------------------------------------
LedOut0  =       0x71               ; 数码管第 0 位显示缓存（时十位）。
LedOut1  =       0x72               ; 数码管第 1 位显示缓存（时个位）。
LedOut2  =       0x73               ; 数码管第 2 位显示缓存（分隔符）。
LedOut3  =       0x74               ; 数码管第 3 位显示缓存（分十位）。
LedOut4  =       0x75               ; 数码管第 4 位显示缓存（分个位）。
LedOut5  =       0x76               ; 数码管第 5 位显示缓存（分隔符）。
LedOut6  =       0x77               ; 数码管第 6 位显示缓存（秒十位）。
LedOut7  =       0x78               ; 数码管第 7 位显示缓存（秒个位）。
TickValue =      0x79               ; 25 ms 节拍计数器，累计 40 次为 1 秒。
SecValue =       0x7A               ; 秒计数器，范围 0～59。
MinValue =       0x7B               ; 分计数器，范围 0～59。
HourValue =      0x7C               ; 时计数器，范围 0～23。
; -----------------------------------------------------------------------------
        .area     PSEG (PAG,XDATA)  ; 声明分页外部 RAM 段，本实验不使用。
        .area     XSEG (XDATA)      ; 声明外部 RAM 段，本实验不使用。
; -----------------------------------------------------------------------------
        .area     HOME (ABS, CODE)  ; 绝对地址代码段，用于放置中断向量和程序代码。
        .org      0x0000            ; 8051 复位向量。
        ljmp      main              ; 复位后跳转到主程序。

        .org      0x002B            ; 定时器2中断向量。
        ljmp      timer2_isr        ; 跳转到完整的定时器2中断程序。

        .org      0x0030            ; 从中断向量区之后开始放置程序代码。
timer2_isr:                         ; 每隔 25 ms 进入一次。
        push      acc               ; 保存主程序的累加器现场。
        clr       tf2               ; Timer2 不会自动清 TF2，必须由软件清除。
        inc       TickValue         ; 25 ms 节拍计数器加 1。
        mov       a, TickValue      ; 读取当前节拍数。
        cjne      a, #40, timer2_exit ; 40 * 25 ms = 1 s，未满则退出中断。
        mov       TickValue, #0     ; 满 1 秒，节拍计数器清零。
        inc       SecValue          ; 秒数加 1。
        mov       a, SecValue       ; 读取秒数。
        cjne      a, #60, timer2_exit ; 未满 60 秒则退出中断。
        mov       SecValue, #0      ; 满 60 秒，秒数清零。
        inc       MinValue          ; 分钟数加 1。
        mov       a, MinValue       ; 读取分钟数。
        cjne      a, #60, timer2_exit ; 未满 60 分钟则退出中断。
        mov       MinValue, #0      ; 满 60 分钟，分钟数清零。
        inc       HourValue         ; 小时数加 1。
        mov       a, HourValue      ; 读取小时数。
        cjne      a, #24, timer2_exit ; 未满 24 小时则退出中断。
        mov       HourValue, #0     ; 满 24 小时，小时数清零。
timer2_exit:
        pop       acc               ; 恢复主程序的累加器现场。
        reti                        ; 从中断返回。
; -----------------------------------------------------------------------------
main:                               ; 主程序入口。
        mov       sp, #0x2F         ; 将栈底移到 0x30，避开寄存器区和显示缓存区。
        mov       TickValue, #0     ; 初始化 25 ms 节拍计数器。
        mov       SecValue, #0      ; 初始化秒数。
        mov       MinValue, #0      ; 初始化分钟数。
        mov       HourValue, #0     ; 初始化小时数。

        mov       t2con, #0x00      ; 自动重装、内部时钟、关闭外部触发并停止 Timer2。
        mov       rcap2l, #0xB0     ; 设置自动重装值低 8 位。
        mov       rcap2h, #0x3C     ; 设置自动重装值高 8 位。
        mov       tl2, #0xB0        ; 设置首次计数的低 8 位初值。
        mov       th2, #0x3C        ; 设置首次计数的高 8 位初值。
        clr       tf2               ; 启动前清除可能残留的溢出标志。
        setb      et2               ; 允许定时器2中断。
        setb      ea                ; 开启总中断。
        setb      tr2               ; 启动 Timer2；以后溢出时由硬件自动重装。

main_loop:                          ; 主循环持续处理并刷新显示。
        lcall     time_display      ; 将时、分、秒拆分成十进制显示数据。
        lcall     display           ; 动态扫描 8 位数码管。
        sjmp      main_loop         ; 返回主循环继续刷新。
; -----------------------------------------------------------------------------
display:                            ; 数码管动态扫描显示子程序。
        mov       dptr, #segment_table ; DPTR 指向段码表首地址。
        mov       r1, #0            ; R1 从第 0 位开始产生位选编号。
        mov       r7, #8            ; 一轮扫描 8 位数码管。
        mov       r0, #LedOut0      ; R0 指向显示缓存首地址。
display_loop:
        mov       a, @r0            ; 读取当前位的段码表索引。
        inc       r0                ; 指向下一位显示缓存。
        movc      a, @a+dptr        ; 从代码区段码表读取段码。
        mov       p0, a             ; 将段码输出到 P0。
        mov       p2, r1            ; 将当前位选编号输出到 P2。
        inc       r1                ; 准备下一位的位选编号。
        lcall     display_delay     ; 保持当前位短暂点亮。
        mov       p0, #0x00         ; 切换位选前消隐，减少重影。
        djnz      r7, display_loop  ; 未扫描完 8 位则继续。
        ret                         ; 返回主循环。
; -----------------------------------------------------------------------------
display_delay:                      ; 数码管扫描短延时。
        mov       r5, #0            ; 从 0 开始，DJNZ 共循环 256 次。
display_delay_loop:
        djnz      r5, display_delay_loop ; 未减到 0 时继续等待。
        ret                         ; 延时结束。
; -----------------------------------------------------------------------------
time_display:                       ; 将时、分、秒拆分为十位和个位。
        mov       a, HourValue      ; 读取小时数。
        mov       b, #10            ; 除数为 10。
        div       ab                ; A 为十位，B 为个位。
        mov       LedOut0, a        ; 保存小时十位。
        mov       LedOut1, b        ; 保存小时个位。

        mov       a, MinValue       ; 读取分钟数。
        mov       b, #10            ; 除数为 10。
        div       ab                ; A 为十位，B 为个位。
        mov       LedOut3, a        ; 保存分钟十位。
        mov       LedOut4, b        ; 保存分钟个位。

        mov       a, SecValue       ; 读取秒数。
        mov       b, #10            ; 除数为 10。
        div       ab                ; A 为十位，B 为个位。
        mov       LedOut6, a        ; 保存秒十位。
        mov       LedOut7, b        ; 保存秒个位。
        mov       LedOut2, #0x10    ; 第一个分隔位使用段码表索引 0x10。
        mov       LedOut5, #0x10    ; 第二个分隔位使用段码表索引 0x10。
        ret                         ; 返回主循环。
; -----------------------------------------------------------------------------
segment_table:                      ; 共阳数码管段码表，位序为 DP-G-F-E-D-C-B-A。
        .db       0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F ; 0～9。
        .db       0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x00                     ; A～F、熄灭。
