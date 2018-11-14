#ifndef __AWS_OPERATOR_CONSTRUCTOR_HPP
#define __AWS_OPERATOR_CONSTRUCTOR_HPP

#include <valarray>
#include <functional>
#include <memory>

namespace AWSM{
//!
//! \file awsOperatorConstructor.hpp
//! \brief AWESOME Generalized Operator Discretization Schemes
//! \author Miroslav Stoyanov
//! \copyright ???
//! \ingroup AwesomeODS
//!
//! Contains the Templated Iterative Linear Solvers.
//!

//! \defgroup AwesomeODS Operator Discretization Schemes
//!
//! \par AWESOME Operator Discretization Schemes
//! Partial Differential Equations are described by a set of operators corresponding to physical properties (e.g., diffusion),
//! parameters (e.g., diffusivity), boundary conditions, and forcing terms.
//! The AWESOME library provides a set of templates that can take
//! a PDE description and generate a discrete approximation to the problem, expressed in a sparse matrix and a dense
//! right-hand-side vector.
//!
//! \par
//! Currently AWESOME works only with a square domain and only a limited set of linear operators are implemented.
//!
//! \par
//! The array structures are implemented using \b std::valarray
//! data structures, compatible with the AWESOME Sparse Linear Algebra.
//!

//! \brief Types of boundary conditions.
//! \ingroup AwesomeODS
enum BoundaryType{
//! \brief Dirichlet boundary condition directly specifies the value of the solution at the boundary.
//! \ingroup AwesomeODS
    type_dirichlet,
//! \brief Neumann boundary condition specifies the value of the derivative of the solution (ignoring the normal vector).
//! \ingroup AwesomeODS
    type_neumann
};


//! \brief Create a standard 5-stencil discretization of the diffusion operator
//! \ingroup AwesomeODS

//! \par Partial Differential Equation
//! Creates a discretization of \f$ - \mu_x u_{xx} - \mu_y u_{yy} = f(x, y) \f$ on a mesh with \b num_x by \b num_y nodes,
//! each of the 4 walls of the domain is associated with either Dirichlet (specify the solution) or Neumann (specify the derivative)
//! boundary conditions with the prescribed values. Neumann conditions specify the derivative directly, as opposed to the commonly
//! used inner-product between the derivative and the normal vector (i.e., normal flux).
//!
//! \par Discretization with 5-stencil
//! The 5-stencil used here is a scaled superposition of \f$ u(x - \Delta x) - 2 u(x) + u(x + \Delta x) \f$ for both direction,
//! and \f$ \Delta x \f$ represents the distance between two nodes.
//! The scaling term is \f$ \Delta x^{-2} \f$. The stencil cancels all derivative
//! up to order 3, the approximation error is bound by \f$ \max( \Delta x^2, \Delta y^2 ) \f$ multiplied by the maximum of the 4-th
//! derivatives of the solution. The Dirichlet boundary is imposed by removing known nodes from the degrees-of-freedom
//! and placing them on the right-hand-side of the linear equation. The Neumann boundary is imposed via "phantom-nodes",
//! i.e., the nodes on the boundary are unknown (free) and the stencil is computed by assuming that there is an extra
//! layer of nodes just outside of the boundary; the values of the phantom nodes is extrapolated from the value of
//! the corresponding near boundary node resulting in a correction of both the operator and the right-hand-side.
//! Specifically, the central difference is used, e.g., \f$ u(-\Delta x) = u(\Delta x) - 2 \Delta x g(y) \f$ where
//! \f$ g(y) \f$ is the corresponding \b left_boundary_value().
//!
//! \par Input parameters
//! Full list of the input parameters:
//! - \b num_x and \b num_y define the number of points to use in each direction, the total number of degrees of freedom
//!   will have one less layer for every wall with Dirichlet boundary conditions
//! - \b left_boundary_type   and \b left_boundary_value()   specify the boundary conditions on the left wall
//! - \b right_boundary_type  and \b right_boundary_value()  specify the boundary conditions on the right wall
//! - \b top_boundary_type    and \b top_boundary_value()    specify the boundary conditions on the top wall
//! - \b bottom_boundary_type and \b bottom_boundary_value() specify the boundary conditions on the bottom wall
//! - \b NOTE: the Neumann boundary conditions assigns values to the derivative of the solution and
//!    ignore the sign of the normal vector
//! - \b forcing() specifies the right-hand-side of the PDE in the interior of the domain
//! - \b diffusivity_x and \b diffusivity_y specify the \f$ \mu_x, \mu_y \f$ coefficients
//! - \b pntr \b indx and \b vals specify the sparse matrix that approximates the operator
//! - \b rhs is the right-hand-side of the discrete equation which holds information from the forcing term
//!   and the boundary conditions
//! - \b boundary_state is a vector that describes the values of the Dirichlet boundary, can be used in the call to ????
//!
template<typename typeFP, typename typeIdx = int>
void discretizeDiffusionOperator(typeIdx num_x, typeIdx num_y,
                                 BoundaryType left_boundary_type,   std::function<typeFP(typeFP y)> left_boundary_value,
                                 BoundaryType right_boundary_type,  std::function<typeFP(typeFP y)> right_boundary_value,
                                 BoundaryType top_boundary_type,    std::function<typeFP(typeFP x)> top_boundary_value,
                                 BoundaryType bottom_boundary_type, std::function<typeFP(typeFP x)> bottom_boundary_value,
                                 std::function<typeFP(typeFP x, typeFP y)> forcing,
                                 typeFP diffusivity_x, typeFP diffusivity_y,
                                 std::valarray<typeIdx> &pntr, std::valarray<typeIdx> &indx, std::valarray<typeFP> &vals,
                                 std::valarray<typeFP> &rhs){

    // degrees of freedom in x and y directions
    typeIdx dofx = num_x - ((left_boundary_type == type_dirichlet) ? 1 : 0) - ((right_boundary_type == type_dirichlet) ? 1 : 0);
    typeIdx dofy = num_y - ((bottom_boundary_type == type_dirichlet) ? 1 : 0) - ((top_boundary_type == type_dirichlet) ? 1 : 0);

    typeIdx total_dof = dofx * dofy; // total degrees of freedom

    pntr.resize(total_dof + 1);
    rhs.resize(total_dof);
    indx.resize(5 * total_dof - 2 * dofx - 2 * dofy); // each node has 5 entries
    vals.resize(indx.size());

    typeFP nodex, nodey;
    typeFP dx = 1.0 / ((typeFP) (num_x - 1)), dy = 1.0 / ((typeFP) (num_y - 1));
    typeFP coeffx = diffusivity_x / (dx * dx), coeffy = diffusivity_y / (dy * dy);

    // sweep through the nodes left-to-right, then bottom-to-top
    typeIdx c = 0; // index the connectivity, keep count of the processed connectivity indexes
    typeIdx p = 0; // index the pntr, i.e., offsets for the connectivity
    pntr[p] = 0;

    // create a stencil pattern and move it by incrementing all of its entries
    // interior nodes use 5 entries (bottom, left, self, right, top), wall nodes use only 4, corner nodes have only 3
    // the values are the same, since we are using uniform grid and constant coefficients
    // thus we allocate the two arrays with 5 entries, copy the values and copy-increment the indexes
    std::valarray<typeFP> cross_values = {-coeffx, 2.0 * coeffx + 2.0 * coeffy, -coeffx, -coeffy, 0.0, 0.0};
    std::valarray<typeIdx> cross_index = {0, 0, 1, dofx, 0};

    // bottom left node (special case with only 3 neighbors)
    for(size_t k = 1; k<4; k++){
        vals[c] = cross_values[k];
        indx[c++] = cross_index[k]++;
    }

    // keep track of the (x, y) coordinates of the nodes to compute the forcing term
    nodex = (left_boundary_type == type_dirichlet) ? dx : 0.0;
    nodey = (bottom_boundary_type == type_dirichlet) ? dy : 0.0;

    rhs[p] = forcing(nodex, nodey);
    pntr[++p] = c;

    // middle-bottom layer nodes
    for(typeIdx j=1; j<dofx-1; j++){
        for(size_t k = 0; k<4; k++){
            vals[c] = cross_values[k];
            indx[c++] = cross_index[k]++;
        }
        nodex += dx;
        rhs[p] = forcing(nodex, nodey);
        pntr[++p] = c;
    }

    // bottom right node
    for(size_t k = 0; k<2; k++){
        vals[c] = cross_values[k];
        indx[c++] = cross_index[k]; // no need to increment, will update the whole array anyway
    }
    vals[c] = cross_values[3];  // skip right node
    indx[c++] = cross_index[3];

    nodex += dx;
    rhs[p] = forcing(nodex, nodey);
    pntr[++p] = c;

    // middle block of nodes
    for(typeIdx i=1; i<dofy-1; i++){
        // initialize the pattern for this block
        cross_values = {-coeffy, -coeffx, 2.0 * coeffx + 2.0 * coeffy, -coeffx, -coeffy};
        cross_index = {(i-1) * dofx, i * dofx, i * dofx, i * dofx + 1, (i+1) * dofx};

        vals[c] = cross_values[0];
        indx[c++] = cross_index[0]++; // skip the left node
        for(size_t k = 2; k<5; k++){
            vals[c] = cross_values[k];
            indx[c++] = cross_index[k]++;
        }

        nodex = (left_boundary_type == type_dirichlet) ? dx : 0.0;
        nodey += dy;

        rhs[p] = forcing(nodex, nodey);
        pntr[++p] = c;

        // middle layer nodes
        for(typeIdx j=1; j<dofx-1; j++){
            for(size_t k = 0; k<5; k++){
                vals[c] = cross_values[k];
                indx[c++] = cross_index[k]++;
            }

            nodex += dx;
            rhs[p] = forcing(nodex, nodey);
            pntr[++p] = c;
        }

        // right wall node
        for(size_t k = 0; k<3; k++){
            vals[c] = cross_values[k];
            indx[c++] = cross_index[k];
        }
        vals[c] = cross_values[4]; // skip the right node
        indx[c++] = cross_index[4];

        nodex += dx;
        rhs[p] = forcing(nodex, nodey);
        pntr[++p] = c;
    }

    // top wall
    // initialize the pattern for the entire wall (but skip the left neighbors for the corner)
    cross_index = {total_dof - 2 * dofx, total_dof - dofx, total_dof - dofx, total_dof - dofx + 1, 0};

    vals[c] = cross_values[0];
    indx[c++] = cross_index[0]++;
    for(size_t k = 2; k<4; k++){ // skip the left neighbor
        vals[c] = cross_values[k];
        indx[c++] = cross_index[k]++;
    }

    nodex = (left_boundary_type == type_dirichlet) ? dx : 0.0;
    nodey += dy;
    rhs[p] = forcing(nodex, nodey);
    pntr[++p] = c;

    // middle-top layer nodes
    for(typeIdx j=1; j<dofx-1; j++){
        for(size_t k = 0; k<4; k++){
            vals[c] = cross_values[k];
            indx[c++] = cross_index[k]++;
        }

        nodex += dx;
        rhs[p] = forcing(nodex, nodey);
        pntr[++p] = c;
    }

    // top right node
    for(size_t k = 0; k<3; k++){
        vals[c] = cross_values[k];
        indx[c++] = cross_index[k]++;
    }

    nodex += dx;
    rhs[p] = forcing(nodex, nodey);
    pntr[++p] = c;

    // At this point, the operator corresponds to homogeneous Dirichlet boundary;
    // correction need to be added for the non-zero Dirichlet boundary and t
    // the right-hand-side needs to be corrected with the appropriate boundary values.

    // bottom wall
    nodex = (left_boundary_type == type_dirichlet) ? dx : 0.0;
    if (bottom_boundary_type == type_dirichlet){
        for(typeIdx j=0; j<dofx; j++){
            rhs[j] += coeffy * bottom_boundary_value(nodex);
            nodex  += dx;
        }
    }else{
        for(typeIdx j=0; j<dofx; j++){
            vals[pntr[j+1]-1] -= coeffy;
            rhs[j] -= 2.0 * dy * coeffy * bottom_boundary_value(nodex);
            nodex  += dx;
        }
    }

    // top wall
    nodex = (left_boundary_type == type_dirichlet) ? dx : 0.0;
    if (top_boundary_type == type_dirichlet){
        rhs[total_dof - dofx] += coeffy * top_boundary_value(nodex);
        for(typeIdx j=total_dof - dofx + 1; j<total_dof; j++){
            nodex  += dx;
            rhs[j] += coeffy * top_boundary_value(nodex);
        }
    }else{
        for(typeIdx j=total_dof - dofx; j<total_dof; j++){
            vals[pntr[j]] -= coeffy;
            nodex  += dx;
            rhs[j] += 2.0 * dy * coeffy * top_boundary_value(nodex);
        }
    }

    // left wall
    nodey = (bottom_boundary_type == type_dirichlet) ? dy : 0.0;
    if (left_boundary_type == type_dirichlet){
        for(typeIdx i=0; i<total_dof - dofx; i+=dofx){
            rhs[i] += coeffx * left_boundary_value(nodey);
            nodey  += dy;
        }
        rhs[total_dof - dofx] += coeffx * left_boundary_value(nodey);
    }else{
        for(typeIdx i=0; i<total_dof - dofx; i+=dofx){
            vals[pntr[i+1]-2] -= coeffx;
            rhs[i] -= 2.0 * dx * coeffx * left_boundary_value(nodey);
            nodey  += dy;
        }
        rhs[total_dof - dofx]            -= 2.0 * dx * coeffx * left_boundary_value(nodey);
        vals[pntr[total_dof - dofx+1]-1] -= coeffx;
    }

    // right wall
    nodey = (bottom_boundary_type == type_dirichlet) ? dy : 0.0;
    if (right_boundary_type == type_dirichlet){
        rhs[dofx - 1]          += coeffx * right_boundary_value(nodey);
        for(typeIdx i = 2 * dofx - 1; i < total_dof; i+=dofx){
            nodey  += dy;
            rhs[i] += coeffx * right_boundary_value(nodey);
        }
    }else{
        vals[pntr[dofx-1]] -= coeffx;
        rhs[dofx - 1] += 2.0 * dx * coeffx * right_boundary_value(nodey);
        for(typeIdx i = 2 * dofx - 1; i < total_dof; i+=dofx){
            vals[pntr[i]+1] -= coeffx;
            nodey  += dy;
            rhs[i] += 2.0 * dx * coeffx * right_boundary_value(nodey);
        }
    }
}

//! \brief Create arrays with the values of the solution at the Dirichlet boundary.
//! \ingroup AwesomeODS

//! Arrays will have size \b num_x (top and bottom) and \b num_y (left and right) corresponding to the boundary.
//! Neumann boundary will result in an empty boundary array. The saved states can be used later to combine
//! with the solved degrees-of-freedom and construct the solution over the entire domain.
template<typename typeFP, typename typeIdx = int>
void saveBoundaryState(typeIdx num_x, typeIdx num_y,
                         BoundaryType left_boundary_type,   std::function<typeFP(typeFP y)> left_boundary_value,
                         BoundaryType right_boundary_type,  std::function<typeFP(typeFP y)> right_boundary_value,
                         BoundaryType top_boundary_type,    std::function<typeFP(typeFP x)> top_boundary_value,
                         BoundaryType bottom_boundary_type, std::function<typeFP(typeFP x)> bottom_boundary_value,
                         std::valarray<typeFP> &left_bs, std::valarray<typeFP> &right_bs,
                         std::valarray<typeFP> &top_bs, std::valarray<typeFP> &bottom_bs){
    typeFP dx = 1.0 / ((typeFP) (num_x - 1)), dy = 1.0 / ((typeFP) (num_y - 1));
    typeFP nodex = 0.0, nodey = 0.0;

    left_bs.resize((size_t)((left_boundary_type == type_dirichlet) ? num_y : 0));
    for(auto &s : left_bs){ s = left_boundary_value(nodey);  nodey += dy; }

    nodey = 0.0;
    right_bs.resize((size_t)((right_boundary_type == type_dirichlet) ? num_y : 0));
    for(auto &s : right_bs){ s = right_boundary_value(nodey);  nodey += dy; }

    top_bs.resize((size_t)((top_boundary_type == type_dirichlet) ? num_x : 0));
    for(auto &s : top_bs){ s = top_boundary_value(nodex);  nodex += dx; }

    nodex = 0.0;
    bottom_bs.resize((size_t)((bottom_boundary_type == type_dirichlet) ? num_x : 0));
    for(auto &s : bottom_bs){ s = bottom_boundary_value(nodex);  nodex += dx; }
}

}

#endif
