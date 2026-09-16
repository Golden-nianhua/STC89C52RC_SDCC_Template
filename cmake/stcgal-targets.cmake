# STC ISP 集成。连接、自动冷启动和硬件选项均在 Misc/stcgal.toml 中配置。

find_program(
    UV_EXECUTABLE
    NAMES uv uv.exe
    HINTS "D:/Code/uv"
    DOC "Path to the uv executable"
)

set(STCGAL_CONFIG "${CMAKE_SOURCE_DIR}/Misc/stcgal.toml")
set(STCGAL_RUNNER "${CMAKE_SOURCE_DIR}/tools/stcgal_runner.py")
set(STCGAL_CLION_RUN_CONFIG_DIR "${CMAKE_SOURCE_DIR}/.idea/runConfigurations")

if(UV_EXECUTABLE)
    set(stcgal_runner_command
        "${UV_EXECUTABLE}" run --script "${STCGAL_RUNNER}"
        --config "${STCGAL_CONFIG}"
    )

    add_custom_target(stc-config-check
        COMMAND ${stcgal_runner_command} check
        COMMENT "检查本机 STC 下载配置"
        USES_TERMINAL
        VERBATIM
    )

    add_custom_target(stc-info
        COMMAND ${stcgal_runner_command} info
        COMMENT "读取 STC 芯片信息和当前硬件选项"
        USES_TERMINAL
        VERBATIM
    )

    add_custom_target(flash
        COMMAND ${stcgal_runner_command} flash
            --image "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
        DEPENDS ${CMAKE_PROJECT_NAME}
        COMMENT "下载 ${CMAKE_PROJECT_NAME}，保留芯片当前硬件选项"
        USES_TERMINAL
        VERBATIM
    )

    add_custom_target(flash-with-options
        COMMAND ${stcgal_runner_command} flash-with-options
            --image "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
        DEPENDS ${CMAKE_PROJECT_NAME}
        COMMENT "下载 ${CMAKE_PROJECT_NAME}，并写入配置的硬件选项"
        USES_TERMINAL
        VERBATIM
    )

    set_target_properties(
        stc-config-check
        stc-info
        flash
        flash-with-options
        PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}"
    )
else()
    message(STATUS "uv was not found; STC flash targets are disabled")
endif()

# 为主固件和两个烧录目标补充同名的 CLion“运行”行为，不新增 CMake 目标。
if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea")
    file(MAKE_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}")

    set(CLION_TARGET_FOLDER "${CMAKE_PROJECT_NAME}")
    set(CLION_CMAKE_EXECUTABLE "${CMAKE_COMMAND}")
    set(CLION_CMAKE_PROFILE "STC89C52RC-Debug")
    set(expected_run_configs)

    set(clion_run_targets "${CMAKE_PROJECT_NAME}")
    if(UV_EXECUTABLE)
        list(APPEND clion_run_targets flash flash-with-options)
    endif()

    foreach(CLION_RUN_TARGET IN LISTS clion_run_targets)
        set(clion_run_config
            "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_${CLION_RUN_TARGET}.xml"
        )
        configure_file(
            "${CMAKE_SOURCE_DIR}/cmake/clion-custom-target-run.xml.in"
            "${clion_run_config}"
            @ONLY
            NEWLINE_STYLE CRLF
        )
        list(APPEND expected_run_configs "${clion_run_config}")
    endforeach()

    # 删除由本脚本生成、但已经不再对应当前目标的旧运行配置。
    file(GLOB existing_run_configs
        "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_*.xml"
    )
    foreach(existing_run_config IN LISTS existing_run_configs)
        if(NOT existing_run_config IN_LIST expected_run_configs)
            file(REMOVE "${existing_run_config}")
        endif()
    endforeach()
endif()
