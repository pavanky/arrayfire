IF(UNIX)
  IF(${WITH_COVERAGE})
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fprofile-arcs -ftest-coverage -fprofile-arcs -ftest-coverage")
  ENDIF(${WITH_COVERAGE})
ENDIF()

MACRO(SET_COMPUTE VERSION)
    SET(CUDA_GENERATE_CODE_${VERSION} "--cuda-gpu-arch=sm_${VERSION}")
    SET(CUDA_GENERATE_CODE ${CUDA_GENERATE_CODE} ${CUDA_GENERATE_CODE_${VERSION}})
    LIST(APPEND COMPUTE_VERSIONS "${VERSION}")
    ADD_DEFINITIONS(-DCUDA_COMPUTE_${VERSION})
    MESSAGE(STATUS "Setting Compute ${VERSION} to ON")
ENDMACRO(SET_COMPUTE)

SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CUDA_GENERATE_CODE}")
IF(${COMPUTE_COUNT} EQUAL 1)
  SET(CUDA_PTX_SM_VERSION "sm_${COMPUTE_VERSIONS}")
ELSE()
  SET(CUDA_PTX_SM_VERSION "sm_20")
ENDIF()

MACRO(GENERATE_PTX ${ptx_sources})
  FOREACH(ptx_src_file ${ptx_sources})
    GET_FILENAME_COMPONENT(_name "${ptx_src_file}" NAME_WE)

    SET(_gen_file_name
      "${ptx_src_file}")
    SET(_tmp_file_name
      "${CMAKE_BINARY_DIR}/src/backend/cuda/${_name}-${CUDA_PTX_SM_VERSION}.s")
    SET(_out_file_name
      "${CMAKE_BINARY_DIR}/src/backend/cuda/${_name}.ptx")

    ADD_CUSTOM_COMMAND(
      OUTPUT "${_tmp_file_name}"
      DEPENDS "${_gen_file_name}"
      COMMAND "sh ${CMAKE_CURRENT_SOURCE_DIR}/gpucc-ptx.sh ${CMAKE_CXX_COMPILER} ${_gen_file_name} ${CUDA_PTX_SM_VERSION}")

    ADD_CUSTOM_COMMAND(
      OUTPUT "${_out_file_name}"
      DEPENDS "${_tmp_file_name}"
      COMMAND ${CMAKE_COMMAND} -E copy "${_tmp_file_name}" "${_out_file_name}")

    LIST(APPEND cuda_ptx "${_out_file_name}")
  ENDFOREACH()
ENDMACRO()

# ## Copied from FindCUDA.cmake
# ## The target_link_library needs to link with the cuda libraries using
# ## PRIVATE
# macro(MY_CUDA_ADD_LIBRARY cuda_target)
#   MESSAGE(STATUS "------------------" ${cuda_target})
#   MESSAGE(STATUS "------------------" ${ARGN})
#   ADD_LIBRARY("${cuda_target}" ${ARGN})
# endmacro()
