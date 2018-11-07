cmake_minimum_required(VERSION 3.5)

project(AWESOME VERSION 0.1.0 LANGUAGES CXX)

option(AWESOME_ENABLE_TESTING "Build the AWESOME tests" OFF)
option(AWESOME_ENABLE_DOXYGEN "Generate the AWESOME documentation" OFF)

##### setup the AWESOME library #####
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/Source LibAwesome) # target name is AWESOME_libawesome

############ TESTING #########
if (AWESOME_ENABLE_TESTING)
    enable_testing()
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/Testing)
endif()

############ DOXYGEN #########
if (AWESOME_ENABLE_DOXYGEN)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/Doxygen)
endif()

