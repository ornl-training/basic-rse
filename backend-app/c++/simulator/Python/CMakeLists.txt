
if (NOT BUILD_SHARED_LIBS)
    message(FATAL_ERROR "Python stuff requires a shared library")
endif()

find_package(PythonInterp)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/plotter.py" "${CMAKE_CURRENT_BINARY_DIR}/plotter.py")
