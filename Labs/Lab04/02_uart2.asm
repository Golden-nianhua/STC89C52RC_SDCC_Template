; Lab04-02：读取 P1 口的 4×4 矩阵键盘，并通过串口发送按键键码。
; 汇编器：SDCC 工具链中的 SDAS8051。
; 串口：12 MHz 晶振、6T 模式、4800 baud、8 位数据、无校验、1 位停止位。
; 输出：按键 0～15 分别发送可直接显示的 ASCII 字符 0～9、A～F。
; -----------------------------------------------------------------------------
        .module  lab04_02_uart2      ; 声明当前汇编模块名称。
; -----------------------------------------------------------------------------
KEY_PORT  =       0x90              ; P1 特殊功能寄存器地址。
RawKey    =       0x70              ; 保存消抖前读取的矩阵键盘特征码。
KeyValue  =       0x71              ; 保存解码后的按键编号 0～15。
KEY_READY =       0x00              ; 位寻址区 00H：1 表示得到一次完整按键事件。
; -----------------------------------------------------------------------------
        .area     PSEG (PAG,XDATA)  ; 声明分页外部 RAM 段，本实验不使用。
        .area     XSEG (XDATA)      ; 声明外部 RAM 段，本实验不使用。
; -----------------------------------------------------------------------------
        .area     HOME (ABS, CODE)  ; 绝对地址代码段。
        .org      0x0000            ; 8051 复位向量。
        ljmp      main              ; 复位后跳转到主程序。

        .org      0x0030            ; 从中断向量区之后开始放置主程序。
main:
        mov       sp, #0x2F         ; 将栈底移到 0x30，避开低地址寄存器区。
        mov       KEY_PORT, #0xFF   ; P1 全部写 1，先释放为准双向输入状态。
        clr       KEY_READY         ; 上电时没有待发送的按键事件。

        mov       scon, #0x50       ; 串口模式 1，8 位 UART，并允许接收。
        mov       tmod, #0x20       ; Timer1 模式 2，8 位自动重装。
        mov       pcon, #0x80       ; SMOD=1，使串口波特率加倍。
        mov       th1, #0xE6        ; 12 MHz、6T、SMOD=1 时约为 4800 baud。
        mov       tl1, #0xE6        ; 设置 Timer1 首次计数初值。
        clr       ti                ; 清除可能残留的发送完成标志。
        setb      tr1               ; 启动 Timer1 作为串口波特率发生器。

main_loop:
        lcall     key_scan          ; 扫描、消抖、解码并等待按键稳定释放。
        jnb       KEY_READY, main_loop ; 没有完整按键事件时继续扫描。
        clr       KEY_READY         ; 消费当前按键事件。
        lcall     key_to_ascii      ; 将 0～15 转换为 ASCII 0～9、A～F。
        lcall     uart_send         ; 把 A 中的字符发送到 PC。
        sjmp      main_loop         ; 返回继续等待下一次按键。
; -----------------------------------------------------------------------------
key_scan:                           ; 按下和释放均使用约 10 ms 延时确认。
        clr       KEY_READY         ; 默认本次扫描没有完整按键事件。
        lcall     read_matrix       ; A=0 表示无按键，否则为矩阵特征码。
        jz        key_scan_exit     ; 没有按键时立即返回。
        mov       RawKey, a         ; 保存第一次读取的特征码。

        mov       r7, #10           ; 等待约 10 ms 后再次读取，以消除按下抖动。
        lcall     delay_1ms
        lcall     read_matrix       ; 第二次读取矩阵特征码。
        jz        key_scan_exit     ; 消抖后已松开，忽略本次输入。
        cjne      a, RawKey, key_scan_exit ; 两次特征码不同，视为抖动或多键输入。

        lcall     decode_key        ; 将稳定特征码转换为按键编号。
        jnc       key_scan_exit     ; C=0 表示不是合法的单键特征码。

key_wait_release:                   ; 等待按键释放，确保长按只发送一次。
        mov       r7, #10           ; 每约 10 ms 检查一次释放状态。
        lcall     delay_1ms
        lcall     read_matrix
        jnz       key_wait_release  ; 仍有按键按下时继续等待。
        setb      KEY_READY         ; 稳定释放后产生一次按键事件。
key_scan_exit:
        mov       KEY_PORT, #0xFF   ; 扫描结束后重新释放 P1 全部引脚。
        ret
; -----------------------------------------------------------------------------
read_matrix:                        ; 返回矩阵特征码；没有按键时返回 0。
        mov       KEY_PORT, #0x0F   ; 高 4 位输出低，低 4 位释放为输入。
        nop                         ; 等待端口电平稳定。
        mov       a, KEY_PORT       ; 读取低 4 位的列状态。
        anl       a, #0x0F          ; 只保留低 4 位。
        cjne      a, #0x0F, matrix_pressed ; 不等于 0x0F 表示至少有键按下。
        mov       a, #0             ; 没有按键时返回 0。
        ret

matrix_pressed:
        mov       b, a              ; 暂存低 4 位列状态。
        mov       KEY_PORT, #0xF0   ; 低 4 位输出低，高 4 位释放为输入。
        nop                         ; 等待端口电平稳定。
        mov       a, KEY_PORT       ; 读取高 4 位的行状态。
        anl       a, #0xF0          ; 只保留高 4 位。
        orl       a, b              ; 合并行列状态，得到完整矩阵特征码。
        ret
; -----------------------------------------------------------------------------
decode_key:                         ; 在 16 项特征码表中查找 A，成功时 C=1。
        mov       RawKey, a         ; 保存待查找的特征码。
        mov       dptr, #key_code_table ; DPTR 指向按键特征码表。
        mov       r7, #0            ; R7 同时作为表索引和按键编号。
decode_key_loop:
        mov       a, r7             ; A 为当前表索引。
        movc      a, @a+dptr        ; 读取对应的特征码。
        cjne      a, RawKey, decode_key_next ; 不匹配则检查下一项。
        mov       KeyValue, r7      ; 匹配成功，保存按键编号 0～15。
        setb      c                 ; 用 C=1 表示解码成功。
        ret
decode_key_next:
        inc       r7                ; 移到下一项。
        cjne      r7, #16, decode_key_loop ; 最多检查 16 个合法按键。
        clr       c                 ; 查表失败，通常表示多键同时按下。
        ret
; -----------------------------------------------------------------------------
key_to_ascii:                       ; 将 KeyValue 转换成可显示的 ASCII 字符。
        mov       a, KeyValue       ; 读取 0～15 的按键编号。
        clr       c                 ; SUBB 前清除借位。
        subb      a, #10            ; 判断按键编号是否小于 10。
        jc        key_ascii_digit   ; 小于 10 时发送字符 0～9。
        add       a, #0x41          ; 10～15 转换为字符 A～F。
        ret
key_ascii_digit:
        mov       a, KeyValue       ; 恢复 0～9 的按键编号。
        add       a, #0x30          ; 转换为字符 0～9。
        ret
; -----------------------------------------------------------------------------
uart_send:                          ; 发送 A 中的一个字节。
        clr       ti                ; 开始发送前清除完成标志。
        mov       sbuf, a           ; 写入发送缓冲区并启动发送。
uart_wait_tx:
        jnb       ti, uart_wait_tx  ; 等待一帧发送完成。
        clr       ti                ; 清除完成标志，准备下次发送。
        ret
; -----------------------------------------------------------------------------
delay_1ms:                          ; 12 MHz、6T 模式下约 1 ms；R7 指定重复次数。
        mov       r6, #249          ; 内层循环执行 249 次。
delay_1ms_loop:
        nop                         ; 六条 NOP 加 DJNZ，每轮约 4 us。
        nop
        nop
        nop
        nop
        nop
        djnz      r6, delay_1ms_loop
        djnz      r7, delay_1ms     ; R7 未减到 0 时继续下一毫秒。
        ret
; -----------------------------------------------------------------------------
key_code_table:                     ; 与 Lab02 矩阵键盘相同的 0～15 特征码顺序。
        .db       0xEE, 0xDE, 0xBE, 0x7E ; 0、1、2、3。
        .db       0xED, 0xDD, 0xBD, 0x7D ; 4、5、6、7。
        .db       0xEB, 0xDB, 0xBB, 0x7B ; 8、9、A、B。
        .db       0xE7, 0xD7, 0xB7, 0x77 ; C、D、E、F。
