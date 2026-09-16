cmake_minimum_required(VERSION 3.21)

set(CMAKE_PROJECT_NAME STC89_Coursework)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 兼容直接创建的 CLion CMake 配置；使用预设时由 toolchainFile 加载工具链。
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND NOT DEFINED CMAKE_SYSTEM_NAME)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/sdcc-mcs51-toolchain.cmake")
endif()

project(${CMAKE_PROJECT_NAME} LANGUAGES C ASM)

# 让 CLion 按每套实验自动归类其编译和下载目标。
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

if(NOT CMAKE_C_COMPILER_ID STREQUAL "SDCC")
    message(FATAL_ERROR "This project must be configured with SDCC")
endif()

set(STC_CODE_SIZE 8192 CACHE STRING "On-chip program memory size in bytes")
set(STC_IRAM_SIZE 256 CACHE STRING "Internal data RAM size in bytes")
set(STC_XRAM_SIZE 256 CACHE STRING "On-chip extended RAM size in bytes")

set(SDCC_MCS51_OPTIONS
    -mmcs51
    --model-small
)

include(cmake/stcgal-targets.cmake)

# 新增子实验时只需放入一个源码文件，无需修改 CMakeLists.txt。
file(GLOB_RECURSE LAB_SOURCES CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_SOURCE_DIR}"
    "Labs/Lab*/*.asm"
    "Labs/Lab*/*.c"
)

set(lab_targets)
foreach(source IN LISTS LAB_SOURCES)
    if(NOT source MATCHES "^Labs/Lab(0[1-8])/([^/]+)\\.(asm|c)$")
        message(FATAL_ERROR
            "Invalid experiment source path: ${source}\n"
            "Use Labs/Lab01 through Labs/Lab08 and place source files directly in that directory."
        )
    endif()

    set(lab_number "${CMAKE_MATCH_1}")
    set(source_name "${CMAKE_MATCH_2}")
    set(source_language "${CMAKE_MATCH_3}")

    if(lab_number LESS_EQUAL 4 AND NOT source_language STREQUAL "asm")
        message(FATAL_ERROR "${source}: Lab01-Lab04 must use assembly (.asm)")
    elseif(lab_number GREATER_EQUAL 5 AND NOT source_language STREQUAL "c")
        message(FATAL_ERROR "${source}: Lab05-Lab08 must use C (.c)")
    endif()

    string(TOLOWER "lab${lab_number}_${source_name}" target)
    string(REGEX REPLACE "[^a-z0-9_]+" "_" target "${target}")
    if(TARGET "${target}")
        message(FATAL_ERROR "Duplicate experiment target name: ${target}")
    endif()

    add_executable("${target}" EXCLUDE_FROM_ALL "${source}")
    set_target_properties("${target}" PROPERTIES
        FOLDER "${target}"
        LINKER_LANGUAGE C
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/firmware"
    )

    if(source_language STREQUAL "c")
        target_include_directories("${target}" PRIVATE "${CMAKE_SOURCE_DIR}/Include")
        target_compile_options("${target}" PRIVATE
            ${SDCC_MCS51_OPTIONS}
            --std-c11
            $<$<CONFIG:Debug>:--debug>
            $<$<CONFIG:Release>:--opt-code-size>
        )
        target_link_options("${target}" PRIVATE
            ${SDCC_MCS51_OPTIONS}
            "SHELL:--code-size ${STC_CODE_SIZE}"
            "SHELL:--iram-size ${STC_IRAM_SIZE}"
            "SHELL:--xram-size ${STC_XRAM_SIZE}"
            $<$<CONFIG:Debug>:--debug>
            $<$<CONFIG:Release>:--opt-code-size>
        )
    else()
        # 汇编实验自行提供复位及中断向量，不链接 SDCC 的 C 运行时入口。
        target_link_options("${target}" PRIVATE
            ${SDCC_MCS51_OPTIONS}
            --nostdlib
            "SHELL:--code-size ${STC_CODE_SIZE}"
            "SHELL:--iram-size ${STC_IRAM_SIZE}"
            "SHELL:--xram-size ${STC_XRAM_SIZE}"
        )
    endif()

    set(firmware_ihx "$<TARGET_FILE:${target}>")
    set(firmware_hex "$<TARGET_FILE_DIR:${target}>/$<TARGET_FILE_BASE_NAME:${target}>.hex")
    set(firmware_bin "$<TARGET_FILE_DIR:${target}>/$<TARGET_FILE_BASE_NAME:${target}>.bin")
    set(firmware_mem "$<TARGET_FILE_DIR:${target}>/$<TARGET_FILE_BASE_NAME:${target}>.mem")

    add_custom_command(TARGET "${target}" POST_BUILD
        COMMAND "${CMAKE_COMMAND}"
            "-DPACKIHX=${SDCC_PACKIHX}"
            "-DINPUT=${firmware_ihx}"
            "-DOUTPUT=${firmware_hex}"
            -P "${CMAKE_SOURCE_DIR}/cmake/packihx.cmake"
        COMMAND "${SDCC_MAKEBIN}" -p "${firmware_ihx}" "${firmware_bin}"
        COMMAND "${CMAKE_COMMAND}"
            "-DNAME=${target}"
            "-DMEM=${firmware_mem}"
            "-DIHX=${firmware_ihx}"
            "-DHEX=${firmware_hex}"
            "-DBIN=${firmware_bin}"
            "-DCODE_SIZE=${STC_CODE_SIZE}"
            "-DIRAM_SIZE=${STC_IRAM_SIZE}"
            "-DXRAM_SIZE=${STC_XRAM_SIZE}"
            -P "${CMAKE_SOURCE_DIR}/cmake/firmware-report.cmake"
        COMMENT "Generating HEX and BIN firmware for ${target}"
        VERBATIM
    )

    set_target_properties("${target}" PROPERTIES
        ADDITIONAL_CLEAN_FILES
            "${CMAKE_BINARY_DIR}/firmware/${target}.bin;${CMAKE_BINARY_DIR}/firmware/${target}.hex;${CMAKE_BINARY_DIR}/firmware/${target}.lk;${CMAKE_BINARY_DIR}/firmware/${target}.map;${CMAKE_BINARY_DIR}/firmware/${target}.mem"
    )

    stcgal_add_flash_targets("${target}" "${target}")
    stcgal_add_clion_run_configuration("${target}" "${target}")
    list(APPEND lab_targets "${target}")
endforeach()

stcgal_cleanup_clion_run_configurations()

if(lab_targets)
    add_custom_target(coursework_all DEPENDS ${lab_targets})
    list(JOIN lab_targets ", " lab_target_summary)
    message(STATUS "Coursework targets: ${lab_target_summary}")
else()
    message(WARNING "No experiment sources found under Labs/Lab01 through Labs/Lab08")
endif()
