# STC ISP 集成。连接、自动冷启动和硬件选项均在 Misc/stcgal.toml 中配置。

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
set(STCGAL_CLION_RUN_CONFIG_DIR "${CMAKE_SOURCE_DIR}/.idea/runConfigurations")
set(STCGAL_CLION_RUN_CONFIG_LOCK "${CMAKE_SOURCE_DIR}/.idea/STC89_Auto_RunConfigs.lock")
set(stcgal_runner_command
    "${UV_EXECUTABLE}" run --script "${STCGAL_RUNNER}"
    --config "${STCGAL_CONFIG}"
)

# CLion 会并行配置 Debug 和 Release。两个 CMake 进程若同时写入同一份
# .idea/runConfigurations XML，Windows 会因 configure_file 的临时文件被占用而失败。
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

function(stcgal_add_clion_configuration
         run_name build_target target_folder run_executable run_parameters build_before_run)
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
    set(clion_run_config
        "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_${CLION_RUN_TARGET}.xml"
    )
    if(build_before_run)
        set(clion_run_template "${CMAKE_SOURCE_DIR}/cmake/clion-custom-target-run.xml.in")
    else()
        set(clion_run_template "${CMAKE_SOURCE_DIR}/cmake/clion-tool-run.xml.in")
    endif()
    configure_file(
        "${clion_run_template}"
        "${clion_run_config}"
        @ONLY
        NEWLINE_STYLE CRLF
    )
    set_property(GLOBAL APPEND PROPERTY STCGAL_CLION_RUN_CONFIGS "${clion_run_config}")
endfunction()

# 工具配置点击“运行”时直接执行；点击“构建”时执行对应的底层 CMake target。
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
set_target_properties(stc_config_check_build stc_info_build PROPERTIES FOLDER "tools")

stcgal_add_clion_configuration(
    stc_config_check stc_config_check_build "tools"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; check"
    FALSE
)
stcgal_add_clion_configuration(
    stc_info stc_info_build "tools"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; info"
    FALSE
)

# 固件的三个共享配置与课程工程保持一致：普通配置只构建，另外两个构建后烧录。
stcgal_add_clion_configuration(
    "${CMAKE_PROJECT_NAME}" "${CMAKE_PROJECT_NAME}" "App"
    "${CMAKE_COMMAND}" "-E true" TRUE
)
stcgal_add_clion_configuration(
    "${CMAKE_PROJECT_NAME}_flash" "${CMAKE_PROJECT_NAME}" "App"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; flash --image &quot;$CMakeCurrentProductFile$&quot;"
    TRUE
)
stcgal_add_clion_configuration(
    "${CMAKE_PROJECT_NAME}_flash_with_options" "${CMAKE_PROJECT_NAME}" "App"
    "${UV_EXECUTABLE}"
    "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; flash-with-options --image &quot;$CMakeCurrentProductFile$&quot;"
    TRUE
)

# 删除已改名或已移除的自动生成配置。
if(IS_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}"
   AND STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
    get_property(expected_run_configs GLOBAL PROPERTY STCGAL_CLION_RUN_CONFIGS)
    file(GLOB existing_run_configs "${STCGAL_CLION_RUN_CONFIG_DIR}/STC89_Auto_*.xml")
    foreach(existing_run_config IN LISTS existing_run_configs)
        if(NOT existing_run_config IN_LIST expected_run_configs)
            file(REMOVE "${existing_run_config}")
        endif()
    endforeach()
endif()
