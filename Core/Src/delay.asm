        .globl  _delay_500ms

        .area   CSEG (CODE)
; 12 MHz、6T 模式下，Timer2 每 0.5 us 加 1。
; 0x3CB0 到 0xFFFF 共计 50000 次，即 25 ms；累计 20 次得到 500 ms。
_delay_500ms:
        push    0x30                ; 保存内部 RAM 0x30，避免破坏 C 程序现场。
        mov     t2con, #0x00        ; Timer2 自动重装、内部时钟，并先停止计数。
        mov     rcap2l, #0xB0       ; 自动重装值低 8 位。
        mov     rcap2h, #0x3C       ; 自动重装值高 8 位。
        mov     tl2, #0xB0          ; 首次计数初值低 8 位。
        mov     th2, #0x3C          ; 首次计数初值高 8 位。
        clr     tf2                 ; 清除可能残留的溢出标志。
        mov     0x30, #20           ; 20 个 25 ms 周期合计 500 ms。
        setb    tr2                 ; 启动 Timer2。
delay_500ms_wait:
        jnb     tf2, delay_500ms_wait ; 等待下一个 25 ms 周期完成。
        clr     tf2                 ; Timer2 的 TF2 需要由软件清除。
        djnz    0x30, delay_500ms_wait ; 未满 20 次则继续等待。
        clr     tr2                 ; 延时结束后停止 Timer2。
        pop     0x30                ; 恢复内部 RAM 0x30。
        ret
