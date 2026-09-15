# Internal CMake integration for the STC ISP actions.
# User-editable connection and hardware settings live in Misc/stcgal.toml.

find_program(
    UV_EXECUTABLE
    NAMES uv uv.exe
    HINTS "D:/Code/uv"
    DOC "Path to the uv executable"
)

if(NOT UV_EXECUTABLE)
    message(STATUS "uv was not found; STC flash targets are disabled")
    return()
endif()

set(STCGAL_CONFIG "${CMAKE_SOURCE_DIR}/Misc/stcgal.toml")
set(STCGAL_RUNNER "${CMAKE_SOURCE_DIR}/tools/stcgal_runner.py")

set(stcgal_runner_command
    "${UV_EXECUTABLE}" run --script "${STCGAL_RUNNER}"
    --config "${STCGAL_CONFIG}"
)

add_custom_target(stc-config-check
    COMMAND ${stcgal_runner_command} check
    COMMENT "检查 Misc/stcgal.toml"
    USES_TERMINAL
    VERBATIM
)

add_custom_target(stc-info
    COMMAND ${stcgal_runner_command} info
    COMMENT "读取 STC 芯片信息和当前硬件选项（只读）"
    USES_TERMINAL
    VERBATIM
)

add_custom_target(flash
    COMMAND ${stcgal_runner_command} flash
        --image "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
    DEPENDS ${CMAKE_PROJECT_NAME}
    COMMENT "下载 ${CMAKE_PROJECT_NAME}（保留芯片当前硬件选项）"
    USES_TERMINAL
    VERBATIM
)

add_custom_target(flash-with-options
    COMMAND ${stcgal_runner_command} flash-with-options
        --image "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
    DEPENDS ${CMAKE_PROJECT_NAME}
    COMMENT "下载 ${CMAKE_PROJECT_NAME}（覆盖芯片硬件选项）"
    USES_TERMINAL
    VERBATIM
)
