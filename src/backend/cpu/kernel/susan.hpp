/*******************************************************
 * Copyright (c) 2015, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

#pragma once
#include <Param.hpp>

namespace cpu
{
namespace kernel
{

template<typename T>
void susan_responses(Param<T> output, CParam<T> input,
                     const unsigned idim0, const unsigned idim1,
                     const int radius, const float t, const float g,
                     const unsigned border_len)
{
    T* resp_out = output.get();
    const T* in = input.get();

    const unsigned r = border_len;
    const int rSqrd = radius*radius;

    for (unsigned y = r; y < idim1 - r; ++y) {
        for (unsigned x = r; x < idim0 - r; ++x) {
            const unsigned idx = y * idim0 + x;
            T m_0 = in[idx];
            float nM = 0.0f;

            for (int i=-radius; i<=radius; ++i) {
                for (int j=-radius; j<=radius; ++j) {
                    if (i*i + j*j < rSqrd) {
                        int p = x + i;
                        int q = y + j;
                        T m = in[p + idim0 * q];
                        float exp_pow = std::pow((m - m_0)/t, 6.0);
                        float cM = std::exp(-exp_pow);
                        nM += cM;
                    }
                }
            }

            resp_out[idx] = nM < g ? g - nM : T(0);
        }
    }
}

template<typename T>
void non_maximal(Param<float> xcoords, Param<float> ycoords, Param<float> response,
                 shared_ptr<unsigned> counter, const unsigned idim0, const unsigned idim1,
                 CParam<T> input, const unsigned border_len, const unsigned max_corners)
{
    float* x_out    = xcoords.get();
    float* y_out    = ycoords.get();
    float* resp_out = response.get();
    unsigned* count = counter.get();
    const T* resp_in= input.get();

    // Responses on the border don't have 8-neighbors to compare, discard them
    const unsigned r = border_len + 1;

    for (unsigned y = r; y < idim1 - r; y++) {
        for (unsigned x = r; x < idim0 - r; x++) {
            const T v = resp_in[y * idim0 + x];

            // Find maximum neighborhood response
            T max_v;
            max_v = max(resp_in[(y-1) * idim0 + x-1], resp_in[y * idim0 + x-1]);
            max_v = max(max_v, resp_in[(y+1) * idim0 + x-1]);
            max_v = max(max_v, resp_in[(y-1) * idim0 + x  ]);
            max_v = max(max_v, resp_in[(y+1) * idim0 + x  ]);
            max_v = max(max_v, resp_in[(y-1) * idim0 + x+1]);
            max_v = max(max_v, resp_in[(y)   * idim0 + x+1]);
            max_v = max(max_v, resp_in[(y+1) * idim0 + x+1]);

            // Stores corner to {x,y,resp}_out if it's response is maximum compared
            // to its 8-neighborhood and greater or equal minimum response
            if (v > max_v) {
                const unsigned idx = *count;
                *count += 1;
                if (idx < max_corners) {
                    x_out[idx]    = (float)x;
                    y_out[idx]    = (float)y;
                    resp_out[idx] = (float)v;
                }
            }
        }
    }
}

}
}
