
macro(add_command_line_tool name)
    set(CMAKE_CXX_FLAGS "-O3")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin)
    add_executable(${name} ${ARGN})
endmacro()
