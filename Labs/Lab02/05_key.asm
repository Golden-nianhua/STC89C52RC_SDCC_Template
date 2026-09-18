; Lab02-05：使用 P2 口的 8 个独立按键控制一位数码管显示 1 至 8。
; 汇编器：SDCC 工具链中的 SDAS8051。
; 按键：P2.0 至 P2.7 分别连接 KEY1 至 KEY8，按下时输入低电平。
; 显示：P0.0 至 P0.7 依次连接 A、B、C、D、E、F、G、DP，共阳数码管。
; 原理：扫描到按键后延时约 10 ms 消抖，将按键编号写入 KEY_VALUE 并查表显示。
; -----------------------------------------------------------------------------
        .module  lab02_05_key       ; 声明当前汇编模块名称，供汇编器和链接器识别。
; -----------------------------------------------------------------------------
SMG_PORT =        0x80              ; P0 特殊功能寄存器地址，用作数码管段选端口。
KEY_PORT =        0xA0              ; P2 特殊功能寄存器地址，用作 8 个独立按键输入。
KEY1 =            0xA0              ; P2.0 的位地址，对应按键 KEY1。
KEY2 =            0xA1              ; P2.1 的位地址，对应按键 KEY2。
KEY3 =            0xA2              ; P2.2 的位地址，对应按键 KEY3。
KEY4 =            0xA3              ; P2.3 的位地址，对应按键 KEY4。
KEY5 =            0xA4              ; P2.4 的位地址，对应按键 KEY5。
KEY6 =            0xA5              ; P2.5 的位地址，对应按键 KEY6。
KEY7 =            0xA6              ; P2.6 的位地址，对应按键 KEY7。
KEY8 =            0xA7              ; P2.7 的位地址，对应按键 KEY8。
KEY_VALUE =       0x70              ; 内部 RAM 0x70：保存当前需要显示的按键编号。
KEY_UNPRESSED =   0x00              ; 没有按键记录时显示数字 0。
KEY1_PRESSED =    0x01              ; KEY1 按下后保存并显示数字 1。
KEY2_PRESSED =    0x02              ; KEY2 按下后保存并显示数字 2。
KEY3_PRESSED =    0x03              ; KEY3 按下后保存并显示数字 3。
KEY4_PRESSED =    0x04              ; KEY4 按下后保存并显示数字 4。
KEY5_PRESSED =    0x05              ; KEY5 按下后保存并显示数字 5。
KEY6_PRESSED =    0x06              ; KEY6 按下后保存并显示数字 6。
KEY7_PRESSED =    0x07              ; KEY7 按下后保存并显示数字 7。
KEY8_PRESSED =    0x08              ; KEY8 按下后保存并显示数字 8。
; -----------------------------------------------------------------------------
        .area     PSEG (PAG,XDATA)  ; 声明分页外部 RAM 段；本实验不在该段分配数据。
        .area     XSEG (XDATA)      ; 声明外部 RAM 段，满足 SDCC MCS-51 链接布局要求。
; -----------------------------------------------------------------------------
        .area     HOME (ABS, CODE)  ; 声明绝对地址代码段，用于放置复位入口和程序代码。
        .org      0x0000            ; 将下一条指令放在单片机复位向量地址 0x0000。
        ljmp      main              ; 复位后长跳转到位于 0x0030 的主程序入口。
; -----------------------------------------------------------------------------
        .org      0x0030            ; 主程序从 0x0030 开始，避开前面的中断向量区域。
main:                              ; 主程序入口，只在复位后执行一次初始化。
        mov       sp, #0x2F         ; 将栈底移到 0x30，避免压栈占用普通低地址 RAM。
        mov       KEY_PORT, #0xFF   ; 向 P2 写 1，将全部准双向口释放为按键输入状态。
        mov       KEY_VALUE, #KEY_UNPRESSED ; 上电时先让数码管显示数字 0。
        mov       dptr, #segment_code ; DPTR 指向共阳数码管 0 至 F 的段码表。
main_loop:                         ; 主循环持续扫描按键并更新显示。
        lcall     key_scan          ; 扫描 8 个按键；按下后更新 KEY_VALUE。
        mov       a, KEY_VALUE      ; 将需要显示的数字作为段码表索引。
        movc      a, @a+dptr        ; 从代码区读取对应的共阳数码管段码。
        mov       SMG_PORT, a       ; 把段码送到 P0，显示当前按键编号。
        sjmp      main_loop         ; 返回主循环，继续扫描按键。
; -----------------------------------------------------------------------------
key_scan:                          ; 8 个低电平有效独立按键的扫描子程序。
        mov       a, KEY_PORT       ; 读取 P2 上的全部按键电平。
        cpl       a                 ; 逐位取反，使“有按键按下”表现为非零值。
        jnz       key_debounce      ; 至少一个按键按下时进入消抖流程。
        ret                         ; 全部按键松开时保持原显示值并返回。
key_debounce:                      ; 检测到按键后的延时消抖流程。
        mov       r7, #10           ; 执行 10 次约 1 ms 延时，总计约 10 ms。
        lcall     delay_1ms         ; 等待触点抖动结束后再逐个判断按键。
        jb        KEY1, check_key2  ; KEY1 为高表示未按下，继续检查 KEY2。
        mov       KEY_VALUE, #KEY1_PRESSED ; KEY1 为低，记录数字 1。
        ret                         ; 返回主循环并刷新数码管。
check_key2:                        ; 检查 P2.1 上的 KEY2。
        jb        KEY2, check_key3  ; KEY2 为高表示未按下，继续检查 KEY3。
        mov       KEY_VALUE, #KEY2_PRESSED ; KEY2 为低，记录数字 2。
        ret                         ; 返回主循环并刷新数码管。
check_key3:                        ; 检查 P2.2 上的 KEY3。
        jb        KEY3, check_key4  ; KEY3 为高表示未按下，继续检查 KEY4。
        mov       KEY_VALUE, #KEY3_PRESSED ; KEY3 为低，记录数字 3。
        ret                         ; 返回主循环并刷新数码管。
check_key4:                        ; 检查 P2.3 上的 KEY4。
        jb        KEY4, check_key5  ; KEY4 为高表示未按下，继续检查 KEY5。
        mov       KEY_VALUE, #KEY4_PRESSED ; KEY4 为低，记录数字 4。
        ret                         ; 返回主循环并刷新数码管。
check_key5:                        ; 检查 P2.4 上的 KEY5。
        jb        KEY5, check_key6  ; KEY5 为高表示未按下，继续检查 KEY6。
        mov       KEY_VALUE, #KEY5_PRESSED ; KEY5 为低，记录数字 5。
        ret                         ; 返回主循环并刷新数码管。
check_key6:                        ; 检查 P2.5 上的 KEY6。
        jb        KEY6, check_key7  ; KEY6 为高表示未按下，继续检查 KEY7。
        mov       KEY_VALUE, #KEY6_PRESSED ; KEY6 为低，记录数字 6。
        ret                         ; 返回主循环并刷新数码管。
check_key7:                        ; 检查 P2.6 上的 KEY7。
        jb        KEY7, check_key8  ; KEY7 为高表示未按下，继续检查 KEY8。
        mov       KEY_VALUE, #KEY7_PRESSED ; KEY7 为低，记录数字 7。
        ret                         ; 返回主循环并刷新数码管。
check_key8:                        ; 检查 P2.7 上的 KEY8。
        jb        KEY8, no_valid_key ; KEY8 为高表示消抖后已没有按键按下。
        mov       KEY_VALUE, #KEY8_PRESSED ; KEY8 为低，记录数字 8。
no_valid_key:                      ; 消抖后没有有效按键时的公共出口。
        ret                         ; 返回主循环；无有效按键时保持原显示值。
; -----------------------------------------------------------------------------
delay_1ms:                         ; 约 1 ms 延时；R7 由调用者设置为重复次数。
        mov       r6, #249          ; 内层循环执行 249 次。
delay_1ms_loop:                    ; 1 ms 延时的内层循环入口。
        nop                         ; 6T 模式下每条 NOP 约耗时 0.5 us。
        nop                         ; 与循环控制指令共同组成约 4 us 的内层周期。
        nop                         ; 补偿 6T 模式比传统 12T 模式快一倍的差异。
        nop                         ; 保持原程序 R6=249、R7=10 的双层循环结构。
        nop                         ; 六条 NOP 共约 3 us。
        nop                         ; 加上 DJNZ 的约 1 us，每轮合计约 4 us。
        djnz      r6, delay_1ms_loop ; R6 减 1，未到 0 时继续内层循环。
        djnz      r7, delay_1ms     ; R7 减 1，未到 0 时再次执行约 1 ms 延时。
        ret                         ; 所有延时轮次完成，返回按键扫描程序。
; -----------------------------------------------------------------------------
segment_code:                      ; 共阳数码管 0 至 F 的段码表，位序为 DP-G-F-E-D-C-B-A。
        .db       0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8 ; 0 至 7。
        .db       0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E ; 8、9、A 至 F。
