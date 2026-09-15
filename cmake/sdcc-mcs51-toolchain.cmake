set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR mcs51)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/Modules")

set(
    SDCC_ROOT
    "D:/Code/c-env/SDCC/SDCC-4.6.0"
    CACHE PATH
    "SDCC installation directory"
)

if(NOT IS_DIRECTORY "${SDCC_ROOT}/bin")
    message(FATAL_ERROR "SDCC_ROOT does not contain a bin directory: ${SDCC_ROOT}")
endif()

function(sdcc_require_tool variable executable)
    if(CMAKE_HOST_WIN32)
        set(host_executable_suffix ".exe")
    else()
        set(host_executable_suffix "")
    endif()
    set(tool_path "${SDCC_ROOT}/bin/${executable}${host_executable_suffix}")
    if(NOT EXISTS "${tool_path}")
        message(FATAL_ERROR "Required SDCC tool was not found: ${tool_path}")
    endif()
    set(${variable} "${tool_path}" CACHE FILEPATH "Path to ${executable}" FORCE)
endfunction()

sdcc_require_tool(CMAKE_C_COMPILER sdcc)
sdcc_require_tool(CMAKE_ASM_COMPILER sdas8051)
sdcc_require_tool(CMAKE_AR sdar)
sdcc_require_tool(CMAKE_RANLIB sdranlib)
sdcc_require_tool(CMAKE_NM sdnm)
sdcc_require_tool(CMAKE_OBJCOPY sdobjcopy)
sdcc_require_tool(SDCC_PACKIHX packihx)
sdcc_require_tool(SDCC_MAKEBIN makebin)

# SDCC invokes helper programs such as cc1 by name.
string(FIND "$ENV{PATH}" "${SDCC_ROOT}/bin;" sdcc_bin_position)
if(NOT sdcc_bin_position EQUAL 0)
    set(ENV{PATH} "${SDCC_ROOT}/bin;$ENV{PATH}")
endif()

set(sdcc_launcher "${CMAKE_COMMAND};-E;env;PATH=${SDCC_ROOT}/bin")
set(
    CMAKE_C_COMPILER_LAUNCHER
    "${sdcc_launcher}"
    CACHE STRING
    "Environment launcher required by the Windows SDCC preprocessor"
    FORCE
)
set(
    CMAKE_C_LINKER_LAUNCHER
    "${sdcc_launcher}"
    CACHE STRING
    "Environment launcher for the SDCC linker driver"
    FORCE
)

# CMake supports SDCC C natively. Identify the standalone ASxxxx assembler so
# CMake can load its small compiler module.
set(CMAKE_ASM_COMPILER_ID SDAS8051)
