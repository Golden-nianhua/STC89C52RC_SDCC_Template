cmake_minimum_required(VERSION 3.21)

set(CMAKE_PROJECT_NAME STC89C52RC_SDCC_Template)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Keep ordinary CLion CMake profiles usable in addition to the presets.
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND NOT DEFINED CMAKE_SYSTEM_NAME)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/sdcc-mcs51-toolchain.cmake")
endif()

project(${CMAKE_PROJECT_NAME} LANGUAGES C ASM)

if(NOT CMAKE_C_COMPILER_ID STREQUAL "SDCC")
    message(FATAL_ERROR "This project must be configured with SDCC")
endif()

set(STC_CODE_SIZE 8192 CACHE STRING "On-chip program memory size in bytes")
set(STC_IRAM_SIZE 256 CACHE STRING "Internal data RAM size in bytes")
set(STC_XRAM_SIZE 256 CACHE STRING "On-chip extended RAM size in bytes")

add_executable(${CMAKE_PROJECT_NAME})

target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    Core/Src/main.c
    Core/Src/delay.asm
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    Core/Inc
    Drivers/Inc
    Hardware/Inc
)

set(SDCC_MCS51_ABI_OPTIONS
    -mmcs51
    --model-small
    --stack-auto
    --int-long-reent
)

target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:C>:${SDCC_MCS51_ABI_OPTIONS}>
    $<$<COMPILE_LANGUAGE:C>:--std-c11>
    $<$<AND:$<COMPILE_LANGUAGE:C>,$<CONFIG:Debug>>:--debug>
    $<$<AND:$<COMPILE_LANGUAGE:C>,$<CONFIG:Release>>:--opt-code-size>
)

target_link_options(${CMAKE_PROJECT_NAME} PRIVATE
    ${SDCC_MCS51_ABI_OPTIONS}
    "SHELL:--code-size ${STC_CODE_SIZE}"
    "SHELL:--iram-size ${STC_IRAM_SIZE}"
    "SHELL:--xram-size ${STC_XRAM_SIZE}"
    $<$<CONFIG:Debug>:--debug>
    $<$<CONFIG:Release>:--opt-code-size>
)

set(firmware_ihx "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>")
set(firmware_hex "$<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>/$<TARGET_FILE_BASE_NAME:${CMAKE_PROJECT_NAME}>.hex")
set(firmware_bin "$<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>/$<TARGET_FILE_BASE_NAME:${CMAKE_PROJECT_NAME}>.bin")

add_custom_command(
    TARGET ${CMAKE_PROJECT_NAME}
    POST_BUILD
    COMMAND "${CMAKE_COMMAND}"
        "-DPACKIHX=${SDCC_PACKIHX}"
        "-DINPUT=${firmware_ihx}"
        "-DOUTPUT=${firmware_hex}"
        -P "${CMAKE_SOURCE_DIR}/cmake/packihx.cmake"
    COMMAND "${SDCC_MAKEBIN}" -p "${firmware_ihx}" "${firmware_bin}"
    COMMENT "Generating HEX and BIN images"
    VERBATIM
)

set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES
    ADDITIONAL_CLEAN_FILES
        "${CMAKE_PROJECT_NAME}.bin;${CMAKE_PROJECT_NAME}.hex;${CMAKE_PROJECT_NAME}.lk;${CMAKE_PROJECT_NAME}.map;${CMAKE_PROJECT_NAME}.mem"
)

include(cmake/stcgal-targets.cmake)
