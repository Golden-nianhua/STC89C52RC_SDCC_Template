if(NOT DEFINED NAME OR NOT DEFINED MEM OR NOT DEFINED IHX OR NOT DEFINED HEX OR NOT DEFINED BIN)
    message(FATAL_ERROR "Firmware report requires NAME, MEM, IHX, HEX and BIN")
endif()

foreach(file IN ITEMS "${MEM}" "${IHX}" "${HEX}" "${BIN}")
    if(NOT EXISTS "${file}")
        message(FATAL_ERROR "Firmware report input does not exist: ${file}")
    endif()
endforeach()

file(READ "${MEM}" memory_report)

function(read_memory_row label output_used output_max)
    string(REGEX MATCH "${label}[^\r\n]*" row "${memory_report}")
    if(NOT row)
        set(${output_used} 0 PARENT_SCOPE)
        set(${output_max} 0 PARENT_SCOPE)
        return()
    endif()
    string(REGEX MATCHALL "[0-9]+" values "${row}")
    list(LENGTH values value_count)
    if(value_count LESS 2)
        set(${output_used} 0 PARENT_SCOPE)
        set(${output_max} 0 PARENT_SCOPE)
        return()
    endif()
    math(EXPR used_index "${value_count} - 2")
    math(EXPR max_index "${value_count} - 1")
    list(GET values ${used_index} used)
    list(GET values ${max_index} maximum)
    set(${output_used} "${used}" PARENT_SCOPE)
    set(${output_max} "${maximum}" PARENT_SCOPE)
endfunction()

function(format_size bytes prefer_larger_unit output)
    math(EXPR remainder "${bytes} % 1024")
    if(prefer_larger_unit AND bytes GREATER_EQUAL 1024 AND remainder EQUAL 0)
        math(EXPR kibibytes "${bytes} / 1024")
        set(${output} "${kibibytes} KB" PARENT_SCOPE)
    else()
        set(${output} "${bytes} B" PARENT_SCOPE)
    endif()
endfunction()

function(format_percent used total output)
    if(total EQUAL 0)
        set(${output} "0.00%" PARENT_SCOPE)
        return()
    endif()
    math(EXPR percent_x100 "(${used} * 10000 + ${total} / 2) / ${total}")
    math(EXPR percent_integer "${percent_x100} / 100")
    math(EXPR percent_fraction "${percent_x100} % 100")
    if(percent_fraction LESS 10)
        set(percent_fraction_padded "0${percent_fraction}")
    else()
        set(percent_fraction_padded "${percent_fraction}")
    endif()
    set(${output} "${percent_integer}.${percent_fraction_padded}%" PARENT_SCOPE)
endfunction()

function(pad_left value width output)
    string(LENGTH "${value}" value_length)
    math(EXPR padding_length "${width} - ${value_length}")
    if(padding_length GREATER 0)
        string(REPEAT " " ${padding_length} padding)
    else()
        set(padding "")
    endif()
    set(${output} "${padding}${value}" PARENT_SCOPE)
endfunction()

function(memory_row name used total output)
    format_size(${used} FALSE used_text)
    format_size(${total} TRUE total_text)
    format_percent(${used} ${total} percent_text)
    pad_left("${name}:" 17 name_column)
    pad_left("${used_text}" 12 used_column)
    pad_left("${total_text}" 13 total_column)
    pad_left("${percent_text}" 12 percent_column)
    set(
        ${output}
        "${name_column}${used_column}${total_column}${percent_column}"
        PARENT_SCOPE
    )
endfunction()

# SDCC 的 IRAM 图中 S 表示尚可用于栈的区域，不计入静态占用。
string(REGEX MATCHALL "0x[0-9A-Fa-f]+:[^\r\n]*" iram_rows "${memory_report}")
set(iram_used 0)
foreach(row IN LISTS iram_rows)
    string(REGEX REPLACE "^0x[0-9A-Fa-f]+:" "" cells "${row}")
    string(REPLACE "|" ";" cells "${cells}")
    foreach(cell IN LISTS cells)
        string(STRIP "${cell}" cell)
        if(NOT cell STREQUAL "" AND NOT cell STREQUAL "S")
            math(EXPR iram_used "${iram_used} + 1")
        endif()
    endforeach()
endforeach()

read_memory_row("PAGED EXT\\. RAM" paged_xram_used paged_xram_max)
read_memory_row("EXTERNAL RAM" xram_used xram_max)
read_memory_row("ROM/EPROM/FLASH" code_used code_max)
math(EXPR total_xram_used "${paged_xram_used} + ${xram_used}")

if(DEFINED IRAM_SIZE)
    set(iram_max "${IRAM_SIZE}")
endif()
if(DEFINED XRAM_SIZE)
    set(xram_max "${XRAM_SIZE}")
endif()
if(DEFINED CODE_SIZE)
    set(code_max "${CODE_SIZE}")
endif()

memory_row("CODE" ${code_used} ${code_max} code_row)
memory_row("IRAM" ${iram_used} ${iram_max} iram_row)
memory_row("XRAM" ${total_xram_used} ${xram_max} xram_row)

file(SIZE "${IHX}" ihx_size)
file(SIZE "${HEX}" hex_size)
file(SIZE "${BIN}" bin_size)

# Plain message() writes NOTICE output to stderr. Printing through cmake -E echo
# keeps the complete report on stdout so CLion cannot interleave it with stcgal.
foreach(report_line IN ITEMS
    "Firmware: ${NAME}"
    "Memory region         Used Size  Region Size  %age Used"
    "${code_row}"
    "${iram_row}"
    "${xram_row}"
    "Firmware files: IHX ${ihx_size} B, HEX ${hex_size} B, BIN ${bin_size} B"
)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo "${report_line}")
endforeach()
