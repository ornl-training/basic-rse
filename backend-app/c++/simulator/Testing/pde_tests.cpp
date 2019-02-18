#include <iostream>

#include "awsTestingCommon.hpp"

//!
//! \file pde_tests.cpp
//! \brief AWESOME PDE Testing
//! \author Miroslav Stoyanov
//! \copyright ???
//! \ingroup AwesomeTesting
//! \internal
//!
//! Testing for the AWESOME PDE Solver
//!

using std::cout;
using std::endl;

// Dirichlet boundary
void test_Poisson_exact_homogeneous();
void test_Poisson_approx_homogeneous();
void test_Poisson_exact_boundary();
void test_Poisson_approx_boundary();

// Neumann boundary
void test_Poisson_exact_neum_hom();
void test_Poisson_exact_neum_bound();
void test_Poisson_approx_homogeneous_neumann();
void test_Poisson_approx_neumann_boundary();

int main(void){
//! \internal
//! \brief Execute all tests and returns zero (if no exceptions are encountered)
//! \ingroup AwesomeTesting

    cout << endl << "           AWESOME: PDE Tests" << endl << endl;

    test_Poisson_exact_homogeneous();
    test_Poisson_approx_homogeneous();
    test_Poisson_exact_boundary();
    test_Poisson_approx_boundary();

    test_Poisson_exact_neum_hom();
    test_Poisson_approx_homogeneous_neumann();
    test_Poisson_exact_neum_bound();
    test_Poisson_approx_neumann_boundary();

    cout << endl << "           AWESOME: All Tests Succeeded." << endl << endl;

    return 0;
}

//! \internal
//! \brief Define two norms for error estimation,
//! \ingroup AwesomeTesting
enum NormType{
//! \internal
//! \brief The approximate \f$ L^1 \f$ using the sum of the difference at all nodes and multiplied by the area of a mesh cell
//! \ingroup AwesomeTesting
    norm_l1,
//! \internal
//! \brief The approximate \f$ \ell^\infty \f$ using the maximum difference at all nodes (\b note: this is the natural finite difference norm)
//! \ingroup AwesomeTesting
    norm_linf
};

//! \internal
//! \brief Solve the PDE with \b PDESolver::setDescription() using all but the last parameter, compare the state to the \b solution() using the norm type
//! \ingroup AwesomeTesting
template<typename typeFP, typename typeIdx = int, NormType norm_type = norm_linf>
typeFP computePDEapproximation(typeIdx num_x, typeIdx num_y,
                               BoundaryType left_boundary_type,   std::function<typeFP(typeFP y)> left_boundary_value,
                               BoundaryType right_boundary_type,  std::function<typeFP(typeFP y)> right_boundary_value,
                               BoundaryType top_boundary_type,    std::function<typeFP(typeFP x)> top_boundary_value,
                               BoundaryType bottom_boundary_type, std::function<typeFP(typeFP x)> bottom_boundary_value,
                               std::function<typeFP(typeFP x, typeFP y)> forcing,
                               typeFP diffusivity_x, typeFP diffusivity_y,
                               std::function<typeFP(typeFP x, typeFP y)> solution,
                               typeFP tolerance = 1.E-10, unsigned int max_iterations = 1000){

    PDESolver<typeFP, typeIdx> Solver;
    Solver.setDescription(num_x, num_y, left_boundary_type, left_boundary_value, right_boundary_type, right_boundary_value,
                                        top_boundary_type,  top_boundary_value,  bottom_boundary_type, bottom_boundary_value,
                          forcing, diffusivity_x, diffusivity_y);
    Solver.solveSteadyState(tolerance, max_iterations);

    std::valarray<typeFP> state;
    Solver.getState(state);

    if (norm_type == norm_linf){
        return continuousNormInfty<typeFP, typeIdx>(state, num_x, num_y, solution);
    }else{
        return continuousNorm1<typeFP, typeIdx>(state, num_x, num_y, solution);
    }
}

//! \internal
//! \brief For each isotropic mesh with density in \b trial_meshes, call \b computePDEapproximation() and estimate the deviation of the convergence rate from the \b expected_rate
//! \ingroup AwesomeTesting
template<typename typeFP, typename typeIdx = int>
typeFP computeConvergenceDeviation(std::valarray<typeIdx> trial_meshes,
                                   BoundaryType left_boundary_type,   std::function<typeFP(typeFP y)> left_boundary_value,
                                   BoundaryType right_boundary_type,  std::function<typeFP(typeFP y)> right_boundary_value,
                                   BoundaryType top_boundary_type,    std::function<typeFP(typeFP x)> top_boundary_value,
                                   BoundaryType bottom_boundary_type, std::function<typeFP(typeFP x)> bottom_boundary_value,
                                   std::function<typeFP(typeFP x, typeFP y)> forcing,
                                   typeFP diffusivity_x, typeFP diffusivity_y,
                                   std::function<typeFP(typeFP x, typeFP y)> solution,
                                   typeFP expected_rate,
                                   typeFP tolerance = 1.E-10, unsigned int max_iterations = 1000){

    std::valarray<double> result(0.0, trial_meshes.size());

    for(size_t i=0; i<trial_meshes.size(); i++)
        result[i] = computePDEapproximation<typeFP, typeIdx, norm_l1>(trial_meshes[i], trial_meshes[i],
                            left_boundary_type, left_boundary_value, right_boundary_type, right_boundary_value,
                            top_boundary_type, top_boundary_value, bottom_boundary_type, bottom_boundary_value,
                            forcing, diffusivity_x, diffusivity_y, solution, tolerance, max_iterations);

    return convergenceRateDeviation(result, expected_rate);
}


//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Dirichlet boundary condition and exact (quadratic) solution.
//! \ingroup AwesomeTesting
void test_Poisson_exact_homogeneous(){
//! Solves \f$ - u_{xx} - u_{yy} = -2 (x^2 - x) - 2 (y^2 - y) \f$ with homogeneous boundary conditions and exact solution
//! \f$ u(x,y) = (x^2 - x) (y^2 - y) \f$. The quadratic solution can be approximated to near round-off error with the 5-point stencil,
//! since the 4-th derivative is zero.

    double err = computePDEapproximation<double, int, norm_linf>(5, 5,
                                         type_dirichlet, [&](double) -> double{ return 0.0; },
                                         type_dirichlet, [&](double) -> double{ return 0.0; },
                                         type_dirichlet, [&](double) -> double{ return 0.0; },
                                         type_dirichlet, [&](double) -> double{ return 0.0; },
                                         [&](double x, double y) -> double{ return -2.0 * (x*x - x) - 2.0 * (y*y - y); },
                                         1.0, 1.0,
                                         [&](double x, double y) -> double{ return (x*x - x) * (y*y - y); });

    if (err > 1.E-12) throw std::runtime_error("Failed exact PDE homogeneous Poisson problem");

    reportPDEPass("Dirichlet", "zero", "exact");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Dirichlet boundary condition and approximated (trigonometric) solution.
//! \ingroup AwesomeTesting
void test_Poisson_approx_homogeneous(){
//! Solves \f$ - u_{xx} - u_{yy} = -2 \pi^2 \sin(\pi x) \sin(\pi y) \f$ with homogeneous boundary conditions and solution
//! \f$ u(x,y) = \sin(\pi x) \sin(\pi y) \f$. The solution can only be approximated with the 5-point stencil, the convergence
//! rate should be quadratic. The test performs several simulations with different mesh size, estimates the convergence rate,
//! and raises an exception if the rate deviates from 2 by more than 5%.

    std::valarray<int> trials = {11, 21, 41, 81, 161};

    double err = computeConvergenceDeviation<double, int>(trials,
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                [&](double x, double y) -> double{ return 2.0 * M_PI * M_PI * sin(M_PI * x) * sin(M_PI * y); }, // forcing
                                1.0, 1.0,
                                [&](double x, double y) -> double{ return sin(M_PI * x) * sin(M_PI * y); }, // exact solution
                                2.0); // expected deviation

    if (err > 0.05) throw std::runtime_error("Failed approx PDE homogeneous Poisson problem, convergence rate more then 5% off expected");

    reportPDEPass("Dirichlet", "zero", "approx");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation and boundary forcing condition leading to an exact (linear) solution.
//! \ingroup AwesomeTesting
void test_Poisson_exact_boundary(){
//! Solves \f$ - u_{xx} - u_{yy} = 0 \f$ with inhomogeneous Dirichlet boundary conditions and exact solution
//! \f$ u(x,y) = 1 + x + 0.5 y \f$. The linear solution can be approximated to near round-off error with the 5-point stencil,
//! since the 4-th derivative is zero.

    double err = computePDEapproximation<double, int, norm_linf>(5, 5,
                                            type_dirichlet, [&](double y) -> double{ return 1.0 + 0.5 * y; }, // left
                                            type_dirichlet, [&](double y) -> double{ return 2.0 + 0.5 * y; }, // right
                                            type_dirichlet, [&](double x) -> double{ return 1.5 + x; },       // top
                                            type_dirichlet, [&](double x) -> double{ return 1.0 + x; },       // bottom
                                            [&](double, double) -> double{ return 0.0; },
                                            1.0, 1.0,
                                            [&](double x, double y) -> double{ return 1.0 + x + 0.5 * y; });

    if (err > 1.E-12) throw std::runtime_error("Failed exact PDE inhomogeneous Poisson problem");

    reportPDEPass("Dirichlet", "varying", "exact");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Dirichlet boundary condition and approximated (trigonometric) solution.
//! \ingroup AwesomeTesting
void test_Poisson_approx_boundary(){
//! Solves \f$ - u_{xx} - u_{yy} = -\exp(x) - \exp(2 y) \f$ with inhomogeneous boundary conditions and solution
//! \f$ u(x,y) = 1 + \exp(x) + \exp(2 y) / 4 \f$. The solution can only be approximated with the 5-point stencil, the convergence
//! rate should be quadratic. The test performs several simulations with different mesh size, estimates the convergence rate,
//! and raises an exception if the rate deviates from 2 by more than 5 percent.

    std::valarray<int> trials = {11, 21, 41, 81, 161};

    double err = computeConvergenceDeviation<double, int>(trials,
                                type_dirichlet, [&](double y) -> double{ return 1.0 + 1.0 +      0.25 * exp(2 * y); },   // left
                                type_dirichlet, [&](double y) -> double{ return 1.0 + exp(1.0) + 0.25 * exp(2.0 * y); }, // right
                                type_dirichlet, [&](double x) -> double{ return 1.0 + exp(x) +   0.25 * exp(2.0); },     // top
                                type_dirichlet, [&](double x) -> double{ return 1.0 + exp(x) +   0.25; },                // bottom
                                [&](double x, double y) -> double{ return -exp(x) - exp(2.0 * y); }, // forcing
                                1.0, 1.0, // diffusivity
                                [&](double x, double y) -> double{ return 1.0 + exp(x) + 0.25 * exp(2.0 * y); }, // exact solution
                                2.0); // expected deviation

    if (err > 0.05) throw std::runtime_error("Failed approx PDE inhomogeneous Poisson problem, convergence rate more then 5% off expected");

    reportPDEPass("Dirichlet", "varying", "approx");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Neumann boundary condition and exact (quadratic) solution.
//! \ingroup AwesomeTesting
void test_Poisson_exact_neum_hom(){
//! Solves \f$ - u_{xx} - u_{yy} = -2 \f$ with homogeneous boundary conditions, Dirichlet on top and bottom, Neumann on the left and right,
//! and exact solution \f$ u(x,y) = (y^2 - y) \f$. The quadratic solution can be approximated to near round-off error with the 5-point stencil,
//! since the 4-th derivative is zero.

    double err = computePDEapproximation<double, int, norm_linf>(5, 5,
                                            type_neumann, [&](double) -> double{ return 0.0; },
                                            type_neumann, [&](double) -> double{ return 0.0; },
                                            type_dirichlet, [&](double) -> double{ return 0.0; },
                                            type_dirichlet, [&](double) -> double{ return 0.0; },
                                            [&](double, double) -> double{ return -2.0; },
                                            1.0, 1.0,
                                            [&](double, double y) -> double{ return (y*y - y); });

    if (err > 1.E-12) throw std::runtime_error("Failed exact PDE zero-Neumann Poisson problem");

    reportPDEPass("Neumann", "zero", "exact");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Dirichlet and Neumann boundary condition and approximated (trigonometric) solution.
//! \ingroup AwesomeTesting
void test_Poisson_approx_homogeneous_neumann(){
//! Solves \f$ - u_{xx} - u_{yy} = -2 \pi^2 \sin(\pi x) \cos(\pi y) \f$ with homogeneous boundary conditions and solution
//! \f$ u(x,y) = \sin(\pi x) \cos(\pi y) \f$. The solution can only be approximated with the 5-point stencil, the convergence
//! rate should be quadratic. The test performs several simulations with different mesh size, estimates the convergence rate,
//! and raises an exception if the rate deviates from 2 by more than 5 percent.

    std::valarray<int> trials = {11, 21, 41, 81, 161};

    double err = computeConvergenceDeviation<double, int>(trials,
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                type_dirichlet, [&](double) -> double{ return 0.0; },
                                type_neumann,   [&](double) -> double{ return 0.0; },
                                type_neumann,   [&](double) -> double{ return 0.0; },
                                [&](double x, double y) -> double{ return 2.0 * M_PI * M_PI * sin(M_PI * x) * cos(M_PI * y); }, // forcing
                                1.0, 1.0, // diffusivity
                                [&](double x, double y) -> double{ return sin(M_PI * x) * cos(M_PI * y); }, // exact solution
                                2.0, 1.E-8); // expected deviation and tolerance

    if (err > 0.05) throw std::runtime_error("Failed approx PDE Poisson 0-Neumann, convergence rate more then 5% off expected");

    reportPDEPass("Neumann", "zero", "approx");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation and boundary forcing condition leading to an exact (linear) solution.
//! \ingroup AwesomeTesting
void test_Poisson_exact_neum_bound(){
//! Solves \f$ - u_{xx} - u_{yy} = 0 \f$ with inhomogeneous Neumann boundary conditions on the left, right, and top sides of the domain,
//! and Dirichlet condition at the bottom boundary. The exact solution is \f$ u(x,y) = 1 + 2 x + y \f$. The linear solution can be
//! approximated to near round-off error with the 5-point stencil, since the 4-th derivative is zero.

    double err = computePDEapproximation<double, int, norm_linf>(5, 5,
                                            type_dirichlet, [&](double y) -> double{ return 1.0 + 2.0 * y; },
                                            type_dirichlet, [&](double y) -> double{ return 2.0 + 2.0 * y; },
                                            type_neumann,   [&](double) -> double{ return 2.0; },
                                            type_neumann,   [&](double) -> double{ return 2.0; },
                                            [&](double, double) -> double{ return 0.0; },
                                            1.0, 1.0,
                                            [&](double x, double y) -> double{ return 1.0 + x + 2.0 * y; });

    if (err > 1.E-12) throw std::runtime_error("Failed exact PDE non-0 (Neumann)  Poisson problem");

    reportPDEPass("Neumann", "varying", "exact");
}

//! \internal
//! \brief Test the PDE solver using Poisson equation homogeneous Dirichlet boundary condition and approximated (trigonometric) solution.
//! \ingroup AwesomeTesting
void test_Poisson_approx_neumann_boundary(){
//! Solves \f$ - u_{xx} - u_{yy} = -\exp(x) - \exp(2 y) \f$ with inhomogeneous Neumann boundary conditions and solution
//! \f$ u(x,y) = 1 + \exp(x) + \exp(2 y) / 4 \f$. The solution can only be approximated with the 5-point stencil, the convergence
//! rate should be quadratic. The test performs several simulations with different mesh size, estimates the convergence rate,
//! and raises an exception if the rate deviates from 2 by more than 5 percent.

    std::valarray<int> trials = {21, 41, 81, 161};

    double err = computeConvergenceDeviation<double, int>(trials,
                                type_dirichlet, [&](double y) -> double{ return 1.0 + 1.0      + exp(2 * y); },     // left
                                type_neumann,   [&](double)   -> double{ return       exp(1.0); },                  // right
                                type_neumann,   [&](double)   -> double{ return                  2.0 * exp(2.0); }, // top
                                type_dirichlet, [&](double x) -> double{ return 1.0 + exp(x)   + 1.0; },            // bottom
                                [&](double x, double y) -> double{ return -2.0 * exp(x) - 2.0 * exp(2.0 * y); }, // forcing
                                2.0, 0.5, // diffusivity
                                [&](double x, double y) -> double{ return 1.0 + exp(x) + exp(2.0 * y); }, // exact solution
                                2.0, 1.E-8); // expected deviation and tolerance

    if (err > 0.05) throw std::runtime_error("Failed approx PDE inhomogeneous Poisson problem, convergence rate more then 5% off expected");

    reportPDEPass("Neumann", "varying", "approx");
}
