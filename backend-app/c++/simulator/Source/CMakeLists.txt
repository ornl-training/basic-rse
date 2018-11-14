
add_library(AWESOME_libawesome awsCoreSparseLinearSolvers.hpp
                               awsCoreMatrixOperations.hpp
                               awsSparseLinearAlgebra.hpp
                               awsOperatorConstructor.hpp
                               Awesome.hpp
                               Awesome.cpp)

set_target_properties(AWESOME_libawesome PROPERTIES OUTPUT_NAME "awesome")

set_property(TARGET AWESOME_libawesome PROPERTY CXX_STANDARD 11)
set_property(TARGET AWESOME_libawesome PROPERTY CXX_STANDARD_REQUIRED ON)

target_include_directories(AWESOME_libawesome PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)
target_include_directories(AWESOME_libawesome PUBLIC $<INSTALL_INTERFACE:include>) # not installing yet

install(TARGETS AWESOME_libawesome
        EXPORT  AWESOME-exports
        RUNTIME DESTINATION "bin"
        LIBRARY DESTINATION "lib"
        ARCHIVE DESTINATION "lib")
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/"
        DESTINATION include
        FILES_MATCHING PATTERN "*.hpp")
