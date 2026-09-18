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
set(STCGAL_CLION_RUN_CONFIG_LOCK "${CMAKE_SOURCE_DIR}/.idea/STC89_Auto_RunConfigs.lock")

if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea")
    file(
        LOCK "${STCGAL_CLION_RUN_CONFIG_LOCK}"
        GUARD PROCESS
        TIMEOUT 60
        RESULT_VARIABLE STCGAL_CLION_RUN_CONFIG_LOCK_RESULT
    )
endif()

if(UV_EXECUTABLE)
    set(stcgal_runner_command
        "${UV_EXECUTABLE}" run --script "${STCGAL_RUNNER}"
        --config "${STCGAL_CONFIG}"
    )

    add_custom_target(stc-config-check
        COMMAND ${stcgal_runner_command} check
        COMMENT "Validating the local STC configuration"
        VERBATIM
    )

    add_custom_target(stc-info
        COMMAND ${stcgal_runner_command} info
        COMMENT "Reading STC device information and hardware options"
        VERBATIM
    )

    set_target_properties(
        stc-config-check
        stc-info
        PROPERTIES FOLDER "${CMAKE_PROJECT_NAME}"
    )
else()
    message(STATUS "uv was not found; STC flash targets are disabled")
endif()

# 烧录项只属于 CLion 运行配置，不创建同名 CMake target。
if(UV_EXECUTABLE
   AND IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea"
   AND STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
    file(MAKE_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}")
    set(CLION_TARGET_FOLDER "${CMAKE_PROJECT_NAME}")
    set(CLION_BUILD_TARGET "${CMAKE_PROJECT_NAME}")
    set(CLION_RUN_EXECUTABLE "${UV_EXECUTABLE}")
    set(expected_run_configs)

    foreach(CLION_RUN_TARGET IN ITEMS flash flash-with-options)
        if(CLION_RUN_TARGET STREQUAL "flash")
            set(stcgal_action "flash")
        else()
            set(stcgal_action "flash-with-options")
        endif()
        set(CLION_RUN_PARAMETERS
            "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; ${stcgal_action} --image &quot;$CMakeCurrentProductFile$&quot;"
        )
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

    file(GLOB existing_run_configs
        "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_*.xml"
    )
    foreach(existing_run_config IN LISTS existing_run_configs)
        if(NOT existing_run_config IN_LIST expected_run_configs)
            file(REMOVE "${existing_run_config}")
        endif()
    endforeach()
endif()
