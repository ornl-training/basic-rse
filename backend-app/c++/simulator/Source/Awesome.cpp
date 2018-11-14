#ifndef __AWS_MAIN_CPP
#define __AWS_MAIN_CPP

#include "Awesome.hpp"

#include <iostream> // for debugging purposes

using namespace AWSM;

// TODO: will put here the extern "C" function to be called from another program

extern "C" int awsSolvePDE(){
    return 5; // just a test, have to put at least one symbol to generate an actual
}

extern "C" void bullsEye(int N, double diffusivity, double spread, double *state){

    PDESolver<double, int> Solver;

    Solver.setDescription(N, N,
                            type_dirichlet, [&](double) -> double{ return 0.0; },
                            type_dirichlet, [&](double) -> double{ return 0.0; },
                            type_dirichlet, [&](double) -> double{ return 0.0; },
                            type_dirichlet, [&](double) -> double{ return 0.0; },
                            [&](double x, double y) -> double{ return exp(-spread * ((x - 0.5)*(x - 0.5) + (y - 0.5)*(y - 0.5))); },
                            diffusivity, diffusivity);

    Solver.solveSteadyState(1.E-6, 2000);
    Solver.getState(state);
}

#endif
