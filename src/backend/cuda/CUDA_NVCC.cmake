IF(UNIX)
  # GCC 6.0 and above default to g++14, enabling c++11 features by default
  # Enabling c++11 with nvcc 7.5 + gcc 6.x doesn't seem to work
  # Only solution for now is to force use c++03 for gcc 6.x
  IF("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "6.0.0")
    SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler -std=c++98")
  ENDIF()

  SET(CUDA_NVCC_FLAGS ${CUDA_NVCC_FLAGS} -Xcompiler -fvisibility=hidden)
  IF(${WITH_COVERAGE})
    SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler -fprofile-arcs -Xcompiler -ftest-coverage -Xlinker -fprofile-arcs -Xlinker -ftest-coverage")
  ENDIF(${WITH_COVERAGE})
ENDIF()

SET(CUDA_GENERATE_PTX_DEFAULT "-arch sm_20")
MACRO(SET_COMPUTE VERSION)
    SET(CUDA_GENERATE_CODE_${VERSION} "-gencode arch=compute_${VERSION},code=sm_${VERSION}")
    SET(CUDA_GENERATE_CODE ${CUDA_GENERATE_CODE} ${CUDA_GENERATE_CODE_${VERSION}})
    LIST(APPEND COMPUTE_VERSIONS "${VERSION}")
    ADD_DEFINITIONS(-DCUDA_COMPUTE_${VERSION})
    MESSAGE(STATUS "Setting Compute ${VERSION} to ON")
ENDMACRO(SET_COMPUTE)

IF(${COMPUTE_COUNT} EQUAL 1)
    SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} ${CUDA_GENERATE_CODE}")
ELSE()
    SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} ${CUDA_GENERATE_PTX_DEFAULT}")
ENDIF()

MACRO(GENERATE_PTX ${ptx_sources})
  CUDA_COMPILE_PTX(ptx_files ${ptx_sources})
  FOREACH(ptx_src_file ${ptx_sources})

    GET_FILENAME_COMPONENT(_name "${ptx_src_file}" NAME_WE)

    SET(_gen_file_name
      "${CMAKE_BINARY_DIR}/src/backend/cuda/cuda_compile_ptx_generated_${_name}.cu.ptx")
    SET(_out_file_name
      "${CMAKE_BINARY_DIR}/src/backend/cuda/${_name}.ptx")

    ADD_CUSTOM_COMMAND(
      OUTPUT "${_out_file_name}"
      DEPENDS "${_gen_file_name}"
      COMMAND ${CMAKE_COMMAND} -E copy "${_gen_file_name}" "${_out_file_name}")

    LIST(APPEND cuda_ptx "${_out_file_name}")
  ENDFOREACH()
ENDMACRO()

IF("${APPLE}")
    ADD_DEFINITIONS(-D__STRICT_ANSI__)
    IF(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
        IF(${CUDA_VERSION_MAJOR} VERSION_LESS 7)
            SET(STD_LIB_BINDING "-stdlib=libstdc++")
        ELSE(${CUDA_VERSION_MAJOR} VERSION_LESS 7)
            SET(STD_LIB_BINDING "-stdlib=libc++")
        ENDIF()

        ADD_DEFINITIONS("${STD_LIB_BINDING}")
        SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${STD_LIB_BINDING}")
        SET(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${STD_LIB_BINDING}")
        SET(CUDA_HOST_COMPILER "/usr/bin/clang++")
    ENDIF()
ENDIF()


## Copied from FindCUDA.cmake
## The target_link_library needs to link with the cuda libraries using
## PRIVATE
macro(MY_CUDA_ADD_LIBRARY_IMPL cuda_target)

  CUDA_ADD_CUDA_INCLUDE_ONCE()

  # Separate the sources from the options
  CUDA_GET_SOURCES_AND_OPTIONS(_sources _cmake_options _options ${ARGN})
  CUDA_BUILD_SHARED_LIBRARY(_cuda_shared_flag ${ARGN})
  # Create custom commands and targets for each file.
  CUDA_WRAP_SRCS( ${cuda_target} OBJ _generated_files ${_sources}
    ${_cmake_options} ${_cuda_shared_flag}
    OPTIONS ${_options} )

  # Compute the file name of the intermedate link file used for separable
  # compilation.
  CUDA_COMPUTE_SEPARABLE_COMPILATION_OBJECT_FILE_NAME(link_file ${cuda_target} "${${cuda_target}_SEPARABLE_COMPILATION_OBJECTS}")

  # Add the library.
  add_library(${cuda_target} ${_cmake_options}
    ${_generated_files}
    ${_sources}
    ${link_file}
    )

  # Add a link phase for the separable compilation if it has been enabled.  If
  # it has been enabled then the ${cuda_target}_SEPARABLE_COMPILATION_OBJECTS
  # variable will have been defined.
  CUDA_LINK_SEPARABLE_COMPILATION_OBJECTS("${link_file}" ${cuda_target} "${_options}" "${${cuda_target}_SEPARABLE_COMPILATION_OBJECTS}")

  target_link_libraries(${cuda_target}
      PRIVATE ${CUDA_LIBRARIES}
    )

  # We need to set the linker language based on what the expected generated file
  # would be. CUDA_C_OR_CXX is computed based on CUDA_HOST_COMPILATION_CPP.
  set_target_properties(${cuda_target}
    PROPERTIES
    LINKER_LANGUAGE ${CUDA_C_OR_CXX}
    )

endmacro()

macro(MY_CUDA_ADD_LIBRARY cuda_target)
  MY_CUDA_ADD_LIBRARY_IMPL(cuda_target ${ARGN} OPTIONS ${CUDA_GENERATE_CODE})
endmacro()
