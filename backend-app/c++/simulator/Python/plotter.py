#!@PYTHON_EXECUTABLE@

from ctypes import c_char_p, c_int, c_double, c_void_p, POINTER, cdll
import matplotlib.pyplot as plt
import numpy as np
import sys

__version__ = "@AWESOME_VERSION_MAJOR@.@AWESOME_VERSION_MINOR@"
__author__ = "Miroslav Stoyanov"

pLibAWESOME = cdll.LoadLibrary("@CMAKE_CURRENT_BINARY_DIR@/../LibAwesome/libawesome.so")

pLibAWESOME.bullsEye.argtypes = [c_int, c_double, c_double, POINTER(c_double)]

def plotBullsEye(iNumPoints, fDiffusivity, fSpread):
    '''
    Plots the Bull's Eye example:
    * **iNumPoints** is the number of points for mesh descritization
    * **fDiffusivity** controls the scale of the deformation, but does not change the profile
    * **fSpread** controls the size of the eye
    '''
    aState = np.empty([iNumPoints * iNumPoints], np.float64)
    pLibAWESOME.bullsEye(iNumPoints, fDiffusivity, fSpread, np.ctypeslib.as_ctypes(aState))

    plt.imshow(aState.reshape([iNumPoints, iNumPoints]), cmap="jet", extent=[-0.05, 1.05, -0.05, 1.05])
    plt.show()


plotBullsEye(50, 1.0, 1.0)
