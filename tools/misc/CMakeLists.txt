project(misc_scripts)

add_custom_target(misc_scripts ALL COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/profile.py ${CMAKE_BINARY_DIR}/bin)
