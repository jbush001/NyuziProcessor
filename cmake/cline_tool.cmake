
macro(add_command_line_tool name)
    set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} "-O3")
    set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} "-O3")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    add_executable(${name} ${ARGN})
endmacro()
