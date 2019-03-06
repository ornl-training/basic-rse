
add_executable(AWESOME_sla_tests linear_algebra_tests.cpp)
set_target_properties(AWESOME_sla_tests PROPERTIES OUTPUT_NAME "linear_algebra_tests")

target_link_libraries(AWESOME_sla_tests AWESOME_libawesome)
target_include_directories(AWESOME_sla_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_test(AwesomeSparseLinearAlgebra linear_algebra_tests)


add_executable(AWESOME_pde_tests pde_tests.cpp)
set_target_properties(AWESOME_pde_tests PROPERTIES OUTPUT_NAME "pde_tests")

target_link_libraries(AWESOME_pde_tests AWESOME_libawesome)
target_include_directories(AWESOME_pde_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_test(AwesomePDE pde_tests)

if (AWESOME_ENABLE_GCOV)
	if(CMAKE_COMPILER_IS_GNUCXX)
	    list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
	    include(CodeCoverage)
	    APPEND_COVERAGE_COMPILER_FLAGS()
    	SETUP_TARGET_FOR_COVERAGE_GCOVR_HTML(NAME ${PROJECT_NAME}_coverage 
    	                                     EXECUTABLE ctest
    	                                     DEPENDENCIES AWESOME_sla_tests 
    	                                                  AWESOME_pde_tests)
	else()
		message(FATAL_ERROR 
		        "-DAWESOME_ENABLE_GCOV=ON requires GNU compilers, exiting")
	endif()
endif()

