foreach(required_variable PACKIHX INPUT OUTPUT)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "${required_variable} is required")
    endif()
endforeach()

execute_process(
    COMMAND "${PACKIHX}" "${INPUT}"
    OUTPUT_FILE "${OUTPUT}"
    RESULT_VARIABLE packihx_result
)

if(NOT packihx_result EQUAL 0)
    file(REMOVE "${OUTPUT}")
    message(FATAL_ERROR "packihx failed with exit code ${packihx_result}")
endif()
