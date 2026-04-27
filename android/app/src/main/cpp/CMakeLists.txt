cmake_minimum_required(VERSION 3.22.1)
project(openal_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(OPENAL_SOFT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../openal-soft)

if(EXISTS ${OPENAL_SOFT_DIR}/CMakeLists.txt)
    set(ALSOFT_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(ALSOFT_UTILS OFF CACHE BOOL "" FORCE)
    set(ALSOFT_TESTS OFF CACHE BOOL "" FORCE)
    set(ALSOFT_CONFIG OFF CACHE BOOL "" FORCE)
    set(ALSOFT_REQUIRE_OPENSL ON CACHE BOOL "" FORCE)

    add_subdirectory(${OPENAL_SOFT_DIR} ${CMAKE_CURRENT_BINARY_DIR}/openal-soft)

    add_library(openal_bridge SHARED openal_bridge.cpp)

    target_include_directories(openal_bridge PRIVATE
        ${OPENAL_SOFT_DIR}/include
    )

    target_link_libraries(openal_bridge
        OpenAL
        log
    )
else()
    message(WARNING "OpenAL Soft not found at ${OPENAL_SOFT_DIR}; building openal_bridge stub.")
    add_library(openal_bridge SHARED openal_bridge_stub.cpp)
    target_link_libraries(openal_bridge log)
endif()
