# STC ISP 集成。连接和硬件选项由用户在 Misc/stcgal.toml 中配置。

find_program(
    UV_EXECUTABLE
    NAMES uv uv.exe
    HINTS "D:/Code/uv"
    DOC "Path to the uv executable"
)

if(NOT UV_EXECUTABLE)
    message(STATUS "uv was not found; STC flash targets are disabled")
    function(stcgal_add_clion_experiment_configurations run_name firmware_target)
    endfunction()
    function(stcgal_add_clion_tool_configuration run_name build_target target_folder run_executable run_parameters)
    endfunction()
    function(stcgal_cleanup_clion_run_configurations)
    endfunction()
    return()
endif()

set(STCGAL_CONFIG "${CMAKE_SOURCE_DIR}/Misc/stcgal.toml")
set(STCGAL_RUNNER "${CMAKE_SOURCE_DIR}/tools/stcgal_runner.py")
set(STCGAL_CLION_RUN_CONFIG_DIR "${CMAKE_SOURCE_DIR}/.idea/runConfigurations")
set(STCGAL_CLION_RUN_CONFIG_LOCK "${CMAKE_SOURCE_DIR}/.idea/STC89_Auto_RunConfigs.lock")
set(stcgal_runner_command
    "${UV_EXECUTABLE}" run --script "${STCGAL_RUNNER}"
    --config "${STCGAL_CONFIG}"
)

# CLion 会并行配置 Debug 和 Release。两个 CMake 进程若同时写入同一份
# .idea/runConfigurations XML，Windows 会因 configure_file 的临时文件被占用而失败。
# 该锁持续到当前 CMake 进程结束，覆盖全部 XML 的生成和过期文件清理。
if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea")
    file(
        LOCK "${STCGAL_CLION_RUN_CONFIG_LOCK}"
        GUARD PROCESS
        TIMEOUT 60
        RESULT_VARIABLE STCGAL_CLION_RUN_CONFIG_LOCK_RESULT
    )
    if(NOT STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
        message(WARNING
            "Cannot lock CLion run configuration generation: "
            "${STCGAL_CLION_RUN_CONFIG_LOCK_RESULT}"
        )
    endif()
endif()

function(stcgal_add_clion_tool_configuration run_name build_target target_folder run_executable run_parameters)
    if(NOT IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea"
       OR NOT STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
        return()
    endif()

    file(MAKE_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}")
    set(CLION_RUN_TARGET "${run_name}")
    set(CLION_BUILD_TARGET "${build_target}")
    set(CLION_TARGET_FOLDER "${target_folder}")
    set(CLION_RUN_EXECUTABLE "${run_executable}")
    set(CLION_RUN_PARAMETERS "${run_parameters}")
    set(clion_custom_run_config
        "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_${CLION_RUN_TARGET}.xml"
    )
    configure_file(
        "${CMAKE_SOURCE_DIR}/cmake/clion-tool-run.xml.in"
        "${clion_custom_run_config}"
        @ONLY
        NEWLINE_STYLE CRLF
    )
    set_property(
        GLOBAL APPEND PROPERTY STCGAL_CLION_RUN_CONFIGS "${clion_custom_run_config}"
    )
endfunction()

add_custom_target(stc_config_check_build
    COMMAND ${stcgal_runner_command} check
    COMMENT "Validating the local STC configuration"
    VERBATIM
)

add_custom_target(stc_info_build
    COMMAND ${stcgal_runner_command} info
    COMMENT "Reading STC device information and hardware options"
    VERBATIM
)

# 三个工具的共享配置使用用户可见的简洁名称；底层 CMake target 使用 build 后缀，
# 供共享配置的“构建”按钮调用。共享配置本身不设置运行前构建任务。
stcgal_add_clion_tool_configuration(
    stc_config_check
    stc_config_check_build
    "tools"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; check"
)
stcgal_add_clion_tool_configuration(
    stc_info
    stc_info_build
    "tools"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; info"
)

# 三个配置都显式生成为共享配置，避免 CLion 在重新导入工程后漏掉无后缀配置。
# 无后缀配置只构建固件；另外两个配置在构建成功后执行对应的烧录操作。
function(stcgal_add_clion_experiment_configurations run_name firmware_target)
    if(NOT IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea"
       OR NOT STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
        return()
    endif()

    file(MAKE_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}")

    set(CLION_TARGET_FOLDER "${run_name}")
    set(CLION_BUILD_TARGET "${firmware_target}")
    foreach(suffix IN ITEMS firmware flash flash_with_options)
        if(suffix STREQUAL "firmware")
            set(CLION_RUN_TARGET "${run_name}")
            set(CLION_RUN_EXECUTABLE "${CMAKE_COMMAND}")
            set(CLION_RUN_PARAMETERS "-E true")
        elseif(suffix STREQUAL "flash")
            set(CLION_RUN_TARGET "${run_name}_flash")
            set(CLION_RUN_EXECUTABLE "${UV_EXECUTABLE}")
            set(CLION_RUN_PARAMETERS
                "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; flash --image &quot;$CMakeCurrentProductFile$&quot;"
            )
        else()
            set(CLION_RUN_TARGET "${run_name}_flash_with_options")
            set(CLION_RUN_EXECUTABLE "${UV_EXECUTABLE}")
            set(CLION_RUN_PARAMETERS
                "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; flash-with-options --image &quot;$CMakeCurrentProductFile$&quot;"
            )
        endif()
        set(clion_custom_run_config
            "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_${CLION_RUN_TARGET}.xml"
        )
        configure_file(
            "${CMAKE_SOURCE_DIR}/cmake/clion-custom-target-run.xml.in"
            "${clion_custom_run_config}"
            @ONLY
            NEWLINE_STYLE CRLF
        )
        set_property(
            GLOBAL APPEND PROPERTY STCGAL_CLION_RUN_CONFIGS "${clion_custom_run_config}"
        )
    endforeach()
endfunction()

function(stcgal_cleanup_clion_run_configurations)
    if(NOT IS_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}"
       OR NOT STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
        return()
    endif()

    get_property(expected_configs GLOBAL PROPERTY STCGAL_CLION_RUN_CONFIGS)
    file(GLOB existing_configs "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_*.xml")
    foreach(existing_config IN LISTS existing_configs)
        if(NOT existing_config IN_LIST expected_configs)
            file(REMOVE "${existing_config}")
        endif()
    endforeach()
endfunction()
