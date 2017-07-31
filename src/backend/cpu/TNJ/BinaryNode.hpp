/*******************************************************
 * Copyright (c) 2014, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

#pragma once
#include <optypes.hpp>
#include <vector>
#include <math.hpp>
#include "Node.hpp"
#include <algorithm>

namespace cpu
{

    template<typename To, typename Ti, af_op_t op>
    struct BinOp
    {
        To eval(Ti lhs, Ti rhs)
        {
            return scalar<To>(0);
        }
    };

namespace TNJ
{

    template<typename To, typename Ti, af_op_t op>
    class BinaryNode  : public TNode<To>
    {

    protected:
        BinOp<To, Ti, op> m_op;
        TNode<Ti> *m_lhs, *m_rhs;

    public:
        BinaryNode(Node_ptr lhs, Node_ptr rhs) :
            TNode<To>(0, std::max(lhs->getHeight(), rhs->getHeight()) + 1, {lhs, rhs}),
            m_lhs(reinterpret_cast<TNode<Ti> *>(lhs.get())),
            m_rhs(reinterpret_cast<TNode<Ti> *>(rhs.get()))
        {
        }

        void calc(int x, int y, int z, int w)
        {
            std::transform(m_lhs->m_val.begin(), m_lhs->m_val.end(),
                           m_rhs->m_val.begin(), this->m_val.begin(),
                           [this](Ti lval, Ti rval) -> To {
                               return m_op.eval(lval, rval);
                           });
        }

        void calc(int idx)
        {
            std::transform(m_lhs->m_val.begin(), m_lhs->m_val.end(),
                           m_rhs->m_val.begin(), this->m_val.begin(),
                           [this](Ti lval, Ti rval) -> To {
                               return m_op.eval(lval, rval);
                           });
        }
    };

}

}
