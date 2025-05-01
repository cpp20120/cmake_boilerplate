macro(add_test_directory source_path)
  get_filename_component(_name ${source_path} NAME)
  set(_binary_dir ${CMAKE_BINARY_DIR}/${source_path})

  file(TO_CMAKE_PATH "${_binary_dir}" _binary_dir)

  add_subdirectory(${PROJECT_SOURCE_DIR}/${source_path} ${_binary_dir})
endmacro()
