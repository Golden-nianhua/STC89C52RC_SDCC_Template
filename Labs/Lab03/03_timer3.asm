; Lab03-03：使用 Timer2 实现 0～200 秒的三按键秒表。
; 汇编器：SDCC 工具链中的 SDAS8051。
; 按键：P1.0、P1.1、P1.2 分别连接按键 1、2、3，低电平表示按下。
; 功能：按键 1 启动，按键 2 停止，按键 3 清零；到达 200 秒后自动停止。
; 显示：第 1～3 位显示三位秒数，第 4～7 位熄灭，第 8 位显示最近的按键编号。
; 时钟：12 MHz 晶振、6T 模式，Timer2 每 25 ms 自动重装，累计 40 次为 1 秒。
; -----------------------------------------------------------------------------
        .module  lab03_03_timer3     ; 声明当前汇编模块名称。
; -----------------------------------------------------------------------------
KEY1      =      0x90               ; P1.0 位地址：启动按键。
KEY2      =      0x91               ; P1.1 位地址：停止按键。
KEY3      =      0x92               ; P1.2 位地址：清零按键。

LedOut0   =      0x71               ; 第 1 位显示缓存：秒数百位。
LedOut1   =      0x72               ; 第 2 位显示缓存：秒数十位。
LedOut2   =      0x73               ; 第 3 位显示缓存：秒数个位。
LedOut3   =      0x74               ; 第 4 位显示缓存：熄灭。
LedOut4   =      0x75               ; 第 5 位显示缓存：熄灭。
LedOut5   =      0x76               ; 第 6 位显示缓存：熄灭。
LedOut6   =      0x77               ; 第 7 位显示缓存：熄灭。
LedOut7   =      0x78               ; 第 8 位显示缓存：按键编号。

TickValue =      0x79               ; 25 ms 节拍计数器，范围 0～39。
TimeValue =      0x7A               ; 秒表时间，范围 0～200 秒。
KeyValue  =      0x7B               ; 最近一次确认的按键编号。
KeySample =      0x7C               ; 上一次采样得到的候选按键。
KeyStable =      0x7D               ; 已确认的稳定按键状态，0 表示已松开。

DISPLAY_BLANK =  0x10               ; 段码表中熄灭图案的索引。
; -----------------------------------------------------------------------------
        .area     PSEG (PAG,XDATA)  ; 声明分页外部 RAM 段，本实验不使用。
        .area     XSEG (XDATA)      ; 声明外部 RAM 段，本实验不使用。
; -----------------------------------------------------------------------------
        .area     HOME (ABS, CODE)  ; 绝对地址代码段，用于放置中断向量和程序代码。
        .org      0x0000            ; 8051 复位向量。
        ljmp      main              ; 复位后跳转到主程序。

        .org      0x002B            ; Timer2 中断向量。
        ljmp      timer2_isr        ; 跳转到完整的 Timer2 中断程序。

        .org      0x0030            ; 从中断向量区之后开始放置程序代码。
timer2_isr:                         ; Timer2 每隔 25 ms 进入一次。
        push      acc               ; 保存主程序的累加器现场。
        clr       tf2               ; Timer2 不会自动清除 TF2，必须由软件清除。
        inc       TickValue         ; 25 ms 节拍计数器加 1。
        mov       a, TickValue      ; 读取当前节拍数。
        cjne      a, #40, timer2_exit ; 未满 40 次时直接退出中断。
        mov       TickValue, #0     ; 满 1 秒后重新累计 25 ms 节拍。
        inc       TimeValue         ; 秒表时间加 1 秒。
        mov       a, TimeValue      ; 检查是否已到最大计时值。
        cjne      a, #200, timer2_exit ; 未达到 200 秒则继续计时。
        clr       tr2               ; 到达 200 秒后停止 Timer2，保持显示 200。
timer2_exit:
        pop       acc               ; 恢复主程序的累加器现场。
        reti                        ; 从中断返回。
; -----------------------------------------------------------------------------
main:                               ; 主程序入口。
        mov       sp, #0x2F         ; 将栈底移到 0x30，避开寄存器区和显示缓存区。
        setb      KEY1              ; P3.0 写 1，释放为准双向输入端口。
        setb      KEY2              ; P3.1 写 1，释放为准双向输入端口。
        setb      KEY3              ; P3.2 写 1，释放为准双向输入端口。

        mov       TickValue, #0     ; 初始化 25 ms 节拍计数器。
        mov       TimeValue, #0     ; 秒表从 000 秒开始。
        mov       KeyValue, #0      ; 尚未按键时，第 8 位显示 0。
        mov       KeySample, #0     ; 初始化候选按键状态为松开。
        mov       KeyStable, #0     ; 初始化稳定按键状态为松开。

        mov       t2con, #0x00      ; 自动重装、内部时钟、关闭外部触发并停止 Timer2。
        mov       rcap2l, #0xB0     ; 自动重装值低 8 位。
        mov       rcap2h, #0x3C     ; 自动重装值高 8 位。
        mov       tl2, #0xB0        ; 首次计数初值低 8 位。
        mov       th2, #0x3C        ; 首次计数初值高 8 位。
        clr       tf2               ; 启动中断前清除溢出标志。
        setb      et2               ; 允许 Timer2 中断，但暂不启动计时。
        setb      ea                ; 开启总中断。

main_loop:                          ; 每约 10 ms 处理一次按键。
        lcall     key_scan          ; 采样并消抖，确认后执行对应按键功能。
        lcall     update_display    ; 将秒数和按键编号写入显示缓存。
        lcall     wait_poll_period  ; 刷新数码管约 10 ms，同时等待下一次按键采样。
        sjmp      main_loop         ; 返回继续轮询。
; -----------------------------------------------------------------------------
key_scan:                           ; 两次连续采样一致才确认新的按键状态。
        lcall     read_key          ; A 返回 0、1、2、3，分别表示松开或对应按键按下。
        cjne      a, KeySample, key_new_sample ; 与上次候选值不同，重新开始确认。
        cjne      a, KeyStable, key_confirmed ; 连续两次相同且状态有变化，确认该状态。
        ret                         ; 状态没有变化，长按不会重复触发。

key_new_sample:
        mov       KeySample, a      ; 保存新的候选值，等待约 10 ms 后再次确认。
        ret                         ; 本次不执行按键动作。

key_confirmed:
        mov       KeyStable, a      ; 记录已经通过消抖确认的稳定状态。
        jz        key_scan_exit     ; 确认松开时只更新状态，不执行功能。
        mov       KeyValue, a       ; 第 8 位显示本次按键编号。
        cjne      a, #1, check_key2_action ; 不是按键 1 则检查按键 2。

        mov       a, TimeValue      ; 到达 200 秒后必须先清零才能再次启动。
        cjne      a, #200, start_stopwatch ; 未到 200 秒则启动或继续计时。
        ret                         ; 已到 200 秒，保持停止状态。
start_stopwatch:
        setb      tr2               ; 启动或继续 Timer2 计时。
        ret                         ; 返回主循环。

check_key2_action:
        cjne      a, #2, clear_stopwatch ; 不是按键 2，则必然是按键 3。
        clr       tr2               ; 按键 2 停止计时，保留当前秒和不足一秒的节拍。
        ret                         ; 返回主循环。

clear_stopwatch:                    ; 按键 3 同时停止计时并将秒表清零。
        clr       ea                ; 暂停中断，保证计时值和 Timer2 初值同步更新。
        clr       tr2               ; 停止 Timer2，清零后保持停止状态。
        mov       TickValue, #0     ; 清除不足一秒的节拍。
        mov       TimeValue, #0     ; 秒表显示恢复为 000。
        mov       tl2, #0xB0        ; 恢复完整 25 ms 周期的低 8 位初值。
        mov       th2, #0x3C        ; 恢复完整 25 ms 周期的高 8 位初值。
        clr       tf2               ; 清除重置期间可能存在的溢出标志。
        setb      ea                ; 恢复总中断。
key_scan_exit:
        ret                         ; 返回主循环。
; -----------------------------------------------------------------------------
read_key:                           ; 按键按下为低，按键 1 的优先级最高。
        jnb       KEY1, read_key1   ; P3.0 为低时返回按键编号 1。
        jnb       KEY2, read_key2   ; P3.1 为低时返回按键编号 2。
        jnb       KEY3, read_key3   ; P3.2 为低时返回按键编号 3。
        mov       a, #0             ; 三个输入均为高，表示按键全部松开。
        ret
read_key1:
        mov       a, #1             ; 返回启动按键编号。
        ret
read_key2:
        mov       a, #2             ; 返回停止按键编号。
        ret
read_key3:
        mov       a, #3             ; 返回清零按键编号。
        ret
; -----------------------------------------------------------------------------
update_display:                     ; 把 0～200 秒拆分成百位、十位和个位。
        mov       a, TimeValue      ; 读取当前秒表时间。
        mov       b, #100           ; 先除以 100。
        div       ab                ; A 为百位，B 为不足 100 的余数。
        mov       LedOut0, a        ; 保存秒数百位。
        mov       a, b              ; 继续处理不足 100 的余数。
        mov       b, #10            ; 再除以 10。
        div       ab                ; A 为十位，B 为个位。
        mov       LedOut1, a        ; 保存秒数十位。
        mov       LedOut2, b        ; 保存秒数个位。

        mov       LedOut3, #DISPLAY_BLANK ; 第 4 位熄灭。
        mov       LedOut4, #DISPLAY_BLANK ; 第 5 位熄灭。
        mov       LedOut5, #DISPLAY_BLANK ; 第 6 位熄灭。
        mov       LedOut6, #DISPLAY_BLANK ; 第 7 位熄灭。
        mov       LedOut7, KeyValue ; 第 8 位显示最近一次确认的按键编号。
        ret                         ; 返回主循环。
; -----------------------------------------------------------------------------
wait_poll_period:                   ; 连续刷新约 5 轮，形成约 10 ms 的按键采样间隔。
        mov       r4, #5            ; 一轮 8 位动态扫描约 2 ms。
wait_poll_loop:
        lcall     display           ; 等待期间持续刷新，避免数码管闪烁或变暗。
        djnz      r4, wait_poll_loop ; 完成约 5 轮后返回进行下一次按键采样。
        ret
; -----------------------------------------------------------------------------
display:                            ; 完整动态扫描 8 位数码管。
        mov       dptr, #segment_table ; DPTR 指向段码表首地址。
        mov       r1, #0            ; 从第 1 位对应的位选编号 0 开始。
        mov       r7, #8            ; 一轮扫描 8 位数码管。
        mov       r0, #LedOut0      ; R0 指向显示缓存首地址。
display_loop:
        mov       a, @r0            ; 读取当前位的段码表索引。
        inc       r0                ; 指向下一位显示缓存。
        movc      a, @a+dptr        ; 从代码区段码表读取段码。
        mov       p0, a             ; 将段码输出到 P0。
        mov       p2, r1            ; 将位选编号输出到 P2。
        inc       r1                ; 准备下一位的位选编号。
        lcall     display_delay     ; 保持当前位短暂点亮。
        mov       p0, #0x00         ; 切换位选前消隐，减少重影。
        djnz      r7, display_loop  ; 未扫描完 8 位则继续。
        ret                         ; 返回等待程序。
; -----------------------------------------------------------------------------
display_delay:                      ; 6T 模式下约 0.25 ms 的单数码管保持时间。
        mov       r5, #0            ; 从 0 开始，DJNZ 共循环 256 次。
display_delay_loop:
        djnz      r5, display_delay_loop ; 未减到 0 时继续等待。
        ret
; -----------------------------------------------------------------------------
segment_table:                      ; 数字 0～F 和熄灭图案的段码表。
        .db       0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F ; 0～9。
        .db       0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x00                     ; A～F、熄灭。
