# Linker configuration
if(NOT MSVC)
  find_program(MOLD_PROGRAM mold)
  find_program(LLD_PROGRAM ld.lld)

  if(MOLD_PROGRAM)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")
    message(STATUS "Using mold linker")
  elseif(LLD_PROGRAM)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=lld")
    message(STATUS "Using lld linker")
  else()
    message(STATUS "Using default system linker")
  endif()
endif()

# LTO configuration
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE TRUE)
