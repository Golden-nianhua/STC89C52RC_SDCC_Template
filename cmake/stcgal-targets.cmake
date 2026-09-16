# STC ISP 集成。连接和硬件选项由用户在 Misc/stcgal.toml 中配置。

find_program(
    UV_EXECUTABLE
    NAMES uv uv.exe
    HINTS "D:/Code/uv"
    DOC "Path to the uv executable"
)

if(NOT UV_EXECUTABLE)
    message(STATUS "uv was not found; STC flash targets are disabled")
    function(stcgal_add_flash_targets firmware_target target_folder)
    endfunction()
    function(stcgal_add_clion_run_configuration firmware_target target_folder)
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

add_custom_target(stc_config_check
    COMMAND ${stcgal_runner_command} check
    COMMENT "Validating the local STC configuration"
    VERBATIM
)

add_custom_target(stc_info
    COMMAND ${stcgal_runner_command} info
    COMMENT "Reading STC device information and hardware options"
    VERBATIM
)

function(stcgal_add_flash_targets firmware_target target_folder)
    add_custom_target("${firmware_target}_flash"
        COMMAND ${stcgal_runner_command} flash
            --image "$<TARGET_FILE:${firmware_target}>"
        DEPENDS "${firmware_target}"
        COMMENT "Flashing ${firmware_target} while preserving hardware options"
        VERBATIM
    )

    add_custom_target("${firmware_target}_flash_with_options"
        COMMAND ${stcgal_runner_command} flash-with-options
            --image "$<TARGET_FILE:${firmware_target}>"
        DEPENDS "${firmware_target}"
        COMMENT "Flashing ${firmware_target} and applying configured hardware options"
        VERBATIM
    )

    set_target_properties(
        "${firmware_target}_flash"
        "${firmware_target}_flash_with_options"
        PROPERTIES FOLDER "${target_folder}"
    )
endfunction()

# 为现有三个 CMake 目标补充同名的 CLion“运行”行为，不新增可见目标。
function(stcgal_add_clion_run_configuration firmware_target target_folder)
    if(NOT IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.idea"
       OR NOT STCGAL_CLION_RUN_CONFIG_LOCK_RESULT STREQUAL "0")
        return()
    endif()

    file(MAKE_DIRECTORY "${STCGAL_CLION_RUN_CONFIG_DIR}")

    set(CLION_TARGET_FOLDER "${target_folder}")
    set(CLION_BUILD_TARGET "${firmware_target}")
    foreach(suffix IN ITEMS firmware flash flash_with_options)
        if(suffix STREQUAL "firmware")
            set(CLION_RUN_TARGET "${firmware_target}")
            set(CLION_RUN_EXECUTABLE "${CMAKE_COMMAND}")
            set(CLION_RUN_PARAMETERS "-E true")
        else()
            set(CLION_RUN_TARGET "${firmware_target}_${suffix}")
            set(CLION_RUN_EXECUTABLE "${UV_EXECUTABLE}")
            if(suffix STREQUAL "flash")
                set(stcgal_action "flash")
            else()
                set(stcgal_action "flash-with-options")
            endif()
            set(CLION_RUN_PARAMETERS
                "run --script &quot;${STCGAL_RUNNER}&quot; --config &quot;${STCGAL_CONFIG}&quot; ${stcgal_action} --image &quot;$CMakeCurrentProductFile$&quot;"
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
