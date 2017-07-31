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
#include <functional>

namespace cpu
{
    template<typename To, typename Ti, af_op_t op>
    struct UnOp
    {
        std::function<To(Ti)> func = [](Ti val) -> To {
            return To(val);
        };
    };

namespace TNJ
{

    template<typename To, typename Ti, af_op_t op>
    class UnaryNode  : public TNode<To>
    {

    protected:
        std::function<To(Ti)> m_func;
        TNode<Ti> *m_child;

    public:
        UnaryNode(Node_ptr child) :
            TNode<To>(0, child->getHeight() + 1, {child}),
            m_func(UnOp<To, Ti, op>().func),
            m_child(reinterpret_cast<TNode<Ti> *>(child.get()))
        {
        }

        void calc(int x, int y, int z, int w, int lim)
        {
            Ti *in_ptr = &(m_child->m_val.front());
            To *out_ptr = &(this->m_val.front());
            for(int i = 0; i < lim; i++) {
                out_ptr[i] = m_func(in_ptr[i]);
            }
        }

        void calc(int idx, int lim)
        {
            Ti *in_ptr = &(m_child->m_val.front());
            To *out_ptr = &(this->m_val.front());
            for(int i = 0; i < lim; i++) {
                out_ptr[i] = m_func(in_ptr[i]);
            }
        }
    };

}

}
