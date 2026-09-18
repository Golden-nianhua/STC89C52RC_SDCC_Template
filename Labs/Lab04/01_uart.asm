; Lab04-01：串口接收、回传并用数码管显示接收到的字节。
; 汇编器：SDCC 工具链中的 SDAS8051。
; 串口：12 MHz 晶振、6T 模式、4800 baud、8 位数据、无校验、1 位停止位。
; 显示：第 1～2 位显示十六进制，第 3～5 位熄灭，第 6～8 位显示十进制。
; -----------------------------------------------------------------------------
        .module  lab04_01_uart       ; 声明当前汇编模块名称。
; -----------------------------------------------------------------------------
RxValue  =       0x70               ; 保存最近一次接收到的字节。
LedOut0  =       0x71               ; 十六进制高 4 位。
LedOut1  =       0x72               ; 十六进制低 4 位。
LedOut2  =       0x73               ; 熄灭。
LedOut3  =       0x74               ; 熄灭。
LedOut4  =       0x75               ; 熄灭。
LedOut5  =       0x76               ; 十进制百位。
LedOut6  =       0x77               ; 十进制十位。
LedOut7  =       0x78               ; 十进制个位。

DISPLAY_BLANK =  0x10               ; 段码表中熄灭图案的索引。
; -----------------------------------------------------------------------------
        .area     PSEG (PAG,XDATA)  ; 声明分页外部 RAM 段，本实验不使用。
        .area     XSEG (XDATA)      ; 声明外部 RAM 段，本实验不使用。
; -----------------------------------------------------------------------------
        .area     HOME (ABS, CODE)  ; 绝对地址代码段。
        .org      0x0000            ; 8051 复位向量。
        ljmp      main              ; 复位后跳转到主程序。

        .org      0x0030            ; 从中断向量区之后开始放置主程序。
main:
        mov       sp, #0x2F         ; 将栈底移到 0x30，避开寄存器区和显示缓存区。
        mov       RxValue, #0       ; 初始接收值为 0。
        mov       LedOut0, #0       ; 十六进制初始显示 00。
        mov       LedOut1, #0
        mov       LedOut2, #DISPLAY_BLANK ; 中间三位熄灭。
        mov       LedOut3, #DISPLAY_BLANK
        mov       LedOut4, #DISPLAY_BLANK
        mov       LedOut5, #0       ; 十进制初始显示 000。
        mov       LedOut6, #0
        mov       LedOut7, #0

        mov       scon, #0x50       ; 串口模式 1，8 位 UART，并允许接收。
        mov       tmod, #0x20       ; Timer1 模式 2，8 位自动重装。
        mov       pcon, #0x80       ; SMOD=1，使串口波特率加倍。
        mov       th1, #0xE6        ; 12 MHz、6T、SMOD=1 时约为 4800 baud。
        mov       tl1, #0xE6        ; 设置 Timer1 首次计数初值。
        clr       ri                ; 清除可能残留的接收完成标志。
        clr       ti                ; 清除可能残留的发送完成标志。
        setb      tr1               ; 启动 Timer1 作为串口波特率发生器。

main_loop:
        lcall     display           ; 持续刷新 8 位数码管。
        jnb       ri, main_loop     ; 尚未接收到完整字节时继续刷新。
        mov       a, sbuf           ; 读取 PC 发送的字节。
        clr       ri                ; 清除接收完成标志，准备接收下一字节。
        mov       RxValue, a        ; 保存原始字节，供显示转换和回传使用。

        mov       sbuf, a           ; 将收到的字节原样回传给 PC。
uart_wait_tx:
        jnb       ti, uart_wait_tx  ; 等待发送完成。
        clr       ti                ; 清除发送完成标志。

        mov       a, RxValue        ; 恢复原始字节。
        lcall     format_value      ; 更新十六进制和十进制显示缓存。
        sjmp      main_loop         ; 返回继续接收和显示。
; -----------------------------------------------------------------------------
format_value:                       ; A 中的 0～255 同时转换为十六进制和十进制。
        mov       b, a              ; B 暂存原始字节。
        swap      a                 ; 将原始高 4 位交换到低 4 位。
        anl       a, #0x0F          ; 只保留高 4 位对应的数值。
        mov       LedOut0, a        ; 保存十六进制高位。
        mov       a, b              ; 取回原始字节。
        anl       a, #0x0F          ; 只保留低 4 位。
        mov       LedOut1, a        ; 保存十六进制低位。

        mov       a, b              ; 再次取回原始字节。
        mov       b, #10            ; 第一次除以 10。
        div       ab                ; A 为 0～25，B 为个位。
        mov       LedOut7, b        ; 保存十进制个位。
        mov       b, #10            ; 商再次除以 10。
        div       ab                ; A 为百位，B 为十位。
        mov       LedOut6, b        ; 保存十进制十位。
        mov       LedOut5, a        ; 保存十进制百位。
        ret
; -----------------------------------------------------------------------------
display:                            ; 完整动态扫描 8 位数码管。
        mov       dptr, #segment_table ; DPTR 指向段码表。
        mov       r1, #0            ; 从位选编号 0 开始。
        mov       r7, #8            ; 一轮扫描 8 位。
        mov       r0, #LedOut0      ; R0 指向显示缓存首地址。
display_loop:
        mov       a, @r0            ; 读取当前位的段码表索引。
        inc       r0                ; 指向下一位显示缓存。
        movc      a, @a+dptr        ; 查表取得段码。
        mov       p0, a             ; 段码输出到 P0。
        mov       p2, r1            ; 位选编号输出到 P2。
        inc       r1                ; 准备下一位位选编号。
        lcall     display_delay     ; 保持当前位短暂点亮。
        mov       p0, #0x00         ; 切换位选前消隐，减少重影。
        djnz      r7, display_loop  ; 未扫描完 8 位则继续。
        ret
; -----------------------------------------------------------------------------
display_delay:                      ; 数码管单个位的短延时。
        mov       r5, #0            ; 从 0 开始，DJNZ 共循环 256 次。
display_delay_loop:
        djnz      r5, display_delay_loop
        ret
; -----------------------------------------------------------------------------
segment_table:                      ; 数字 0～F 和熄灭图案的段码表。
        .db       0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F ; 0～9。
        .db       0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x00                     ; A～F、熄灭。
