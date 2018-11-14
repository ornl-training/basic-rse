#ifndef __AWS_MAIN_HPP
#define __AWS_MAIN_HPP

//!
//! \file Awesome.hpp
//! \brief AWESOME Main Header File
//! \author Miroslav Stoyanov
//! \copyright ???
//!
//! The main header that includes all components of the AWESOME library.
//!

#include "awsSparseLinearAlgebra.hpp"

#include "awsOperatorConstructor.hpp"

//! \brief All components of the AWESOME library are encapsulated within the \b AWSM namespace included in the \b Awesome.hpp header.
namespace AWSM{

//! \defgroup AwesomePDESolver PDE Solver
//!
//! \par AWESOME Partial Differential Equation Solver
//! A class that encapsulates the information associated with a partial differential equation.

//! \brief A class that encapsulates the information associated with a partial differential equation.
//! \ingroup AwesomePDESolver

//! The \b PDESolver class holds information about the boundary conditions, mesh density, and the discretized operator
//! and forcing terms. The encapsulation is a convenient way to keep synchronization between the different aspects of
//! the problem and to ensure that consistent information is passed between the stages:
//! - Discretize the problem using \b setDescription() which calls \b discretizeDiffusionOperator().
//! - Find the state, i.e., solve the steady state problem using \b solveSteadyState() which calls \b solveCGILU().
//! - Retrieve the final state using \b getState() which uses stored data from the Dirichlet boundary conditions.
//!
template<typename typeFP, typename typeIdx = int>
class PDESolver{
public:
    //! \brief Constructor, sets the basic grid parameters.
    PDESolver() : nx(0), ny(0){}
    //! \brief Destructor, clear all used memory.
    ~PDESolver(){}

//! \brief Set the current equation to the diffusion equation described in \b discretizeDiffusionOperator().

//! Sets the current problem to the discretized diffusion operator and initializes the unknown state to zero.
//! The internal data structures of the \b PDESolver() are updated accordingly, which includes:
//! - reset the boundary values and erase any previously computed states
//! - call \b discretizeDiffusionOperator() and set the new operator and forcing terms
//! - initialize the unknown state to zero
//! - save the values of the nodes at the Dirichlet boundary to later use in
    void setDescription(typeIdx num_x, typeIdx num_y,
                        BoundaryType left_boundary_type,   std::function<typeFP(typeFP y)> left_boundary_value,
                        BoundaryType right_boundary_type,  std::function<typeFP(typeFP y)> right_boundary_value,
                        BoundaryType top_boundary_type,    std::function<typeFP(typeFP x)> top_boundary_value,
                        BoundaryType bottom_boundary_type, std::function<typeFP(typeFP x)> bottom_boundary_value,
                        std::function<typeFP(typeFP x, typeFP y)> forcing,
                        typeFP diffusivity_x, typeFP diffusivity_y){

        nx = num_x;
        ny = num_y;

        left   = left_boundary_type;
        right  = right_boundary_type;
        top    = top_boundary_type;
        bottom = bottom_boundary_type;

        resetStates();

        std::valarray<typeIdx> pntr, indx;
        std::valarray<typeFP> vals;

        discretizeDiffusionOperator<typeFP, typeIdx>(nx, ny, left, left_boundary_value, right, right_boundary_value,
                                                     top, top_boundary_value, bottom, bottom_boundary_value,
                                                     forcing, diffusivity_x, diffusivity_y, pntr, indx, vals, rhs);

        ops = std::unique_ptr<SparseMatrix<typeFP, typeIdx>>(new SparseMatrix<typeFP, typeIdx>(pntr, indx, vals));

        dof_state.resize(rhs.size(), 0.0);

        saveBoundaryState<typeFP, typeIdx>(nx, ny, left, left_boundary_value, right, right_boundary_value,
                                           top, top_boundary_value, bottom, bottom_boundary_value,
                                           left_bs, right_bs, top_bs, bottom_bs);
    }

//! \brief Solve the steady-state problem, i.e., set the current state to the one satisfying the Poisson PDE (time dependent problems are not implemented yet)

//! Solve the final state of the PDE using the Conjugate-Gradient method with Incomplete LU factorization.
//! - \b tolerance is the desired numerical tolerance for the solver
//! - \b max_iterations is the maximum allows number of iterations
//! - \b return the actual number of CG iterations, if the returned value matches \b max_iterations then it is possible that \b tolerance is not satisfied
    unsigned int solveSteadyState(typeFP tolerance, unsigned int max_iterations = std::numeric_limits<unsigned int>::max()){
        return ops->solveCG(tolerance, max_iterations, rhs, dof_state);
    }

//! \brief Combines the degrees of freedom and the saved Dirichlet boundary values into a single \b state of size \b num_x times \b num_y

//! Generate a complete state by combining the degrees of freedom and the saved Dirichlet boundary values.
//! - \b state must have length at least \b num_x times \b num_y, with the \b num_ corresponding to the last call to \b setDescription()
//! - The first batch of \b num_x entries will be overwritten with the solution at the bottom boundary (taken from either the degrees of freedom or the Dirichlet values).
//! - The second set of \b num_x entries corresponds to the second layer and so on, there are total of \b num_y layers.
//! - On each layer, the first entry corresponds to the left boundary and the last entry sits on the right boundary.
    void getState(typeFP *state){
        // degrees of freedom in x and y directions
        typeIdx dofx_start = ((left == type_dirichlet) ? 1 : 0);
        typeIdx dofx_end   = nx - ((right == type_dirichlet) ? 1 : 0);
        typeIdx dofy_start = ((bottom == type_dirichlet) ? 1 : 0);
        typeIdx dofy_end   = ny - ((top == type_dirichlet) ? 1 : 0);
        size_t c = 0; // count nodes, first count the degrees of freedom

        // set the degrees of freedom
        for(typeIdx i = dofy_start; i < dofy_end; i++)
            for(typeIdx j = dofx_start; j < dofx_end; j++)
                state[(size_t)(i * nx + j)] = dof_state[c++];

        // apply the saved Dirichlet boundary state
        c = 0; // count the boundary nodes
        for(auto v : bottom_bs) state[c++] = v;

        c = (size_t)((ny - 1) * nx);
        for(auto v : top_bs) state[c++] = v;

        c = 0;
        for(auto v : left_bs){ state[c] = v; c += (size_t) nx; }

        c = (size_t) (nx - 1);
        for(auto v : right_bs){ state[c] = v; c += (size_t) nx; }
    }

//! \brief Resize \b state to \b num_x times \b num_y and call \b getState()
    void getState(std::valarray<typeFP> &state){
        state.resize((size_t) (nx * ny));
        getState(std::begin(state));
    }

protected:
//! \brief Clear all stored vectors releasing all used memory.
    void resetStates(){
        rhs       = std::valarray<typeFP>();
        dof_state = std::valarray<typeFP>();
        left_bs   = std::valarray<typeFP>();
        right_bs  = std::valarray<typeFP>();
        top_bs    = std::valarray<typeFP>();
        bottom_bs = std::valarray<typeFP>();
    }

private:
    typeIdx nx, ny;
    BoundaryType left, right, top, bottom;

    std::unique_ptr<SparseMatrix<typeFP, typeIdx>> ops;
    std::valarray<typeFP> rhs;
    std::valarray<typeFP> dof_state;

    std::valarray<typeFP> left_bs, right_bs, top_bs, bottom_bs;
};

}

#endif
