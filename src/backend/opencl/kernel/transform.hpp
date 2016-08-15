/*******************************************************
 * Copyright (c) 2014, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

#pragma once
#include <kernel_headers/transform_interp.hpp>
#include <kernel_headers/transform.hpp>
#include <program.hpp>
#include <traits.hpp>
#include <string>
#include <mutex>
#include <map>
#include <dispatch.hpp>
#include <Param.hpp>
#include <debug_opencl.hpp>
#include <type_util.hpp>
#include <math.hpp>
#include "config.hpp"

using cl::Buffer;
using cl::Program;
using cl::Kernel;
using cl::KernelFunctor;
using cl::EnqueueArgs;
using cl::NDRange;
using std::string;

namespace opencl
{
    namespace kernel
    {
        static const int TX = 16;
        static const int TY = 16;
        // Used for batching images
        static const int TI = 4;

        using std::conditional;
        using std::is_same;
        template<typename T>
        using wtype_t = typename conditional<is_same<T, double>::value, double, float>::type;

        template<typename T>
        using vtype_t = typename conditional<is_complex<T>::value,
                                             T, wtype_t<T>
                                            >::type;


        template<typename T, bool isInverse, bool isPerspective, af_interp_type method>
        void transform(Param out, const Param in, const Param tf)
        {
            try {
                static std::once_flag compileFlags[DeviceManager::MAX_DEVICES];
                static std::map<int, Program*>   transformProgs;
                static std::map<int, Kernel *> transformKernels;

                int device = getActiveDeviceId();
                typedef typename dtype_traits<T>::base_type BT;

                std::call_once( compileFlags[device], [device] () {
                    ToNum<T> toNum;
                    std::ostringstream options;
                    options << " -D T="           << dtype_traits<T>::getName()
                            << " -D INVERSE="     << (isInverse ? 1 : 0)
                            << " -D PERSPECTIVE=" << (isPerspective ? 1 : 0)
                            << " -D ZERO="        << toNum(scalar<T>(0));
                    options << " -D VT="          << dtype_traits<vtype_t<T>>::getName();
                    options << " -D WT="          << dtype_traits<wtype_t<BT>>::getName();

                    if((af_dtype) dtype_traits<T>::af_type == c32 ||
                       (af_dtype) dtype_traits<T>::af_type == c64) {
                        options << " -D CPLX=1";
                        options << " -D TB=" << dtype_traits<BT>::getName();
                    } else {
                        options << " -D CPLX=0";
                    }
                    if (std::is_same<T, double>::value ||
                        std::is_same<T, cdouble>::value) {
                        options << " -D USE_DOUBLE";
                    }

                    switch(method) {
                        case AF_INTERP_NEAREST : options << " -D INTERP=NEAREST";
                            break;
                        case AF_INTERP_BILINEAR: options << " -D INTERP=BILINEAR";
                            break;
                        case AF_INTERP_LOWER   : options << " -D INTERP=LOWER";
                            break;
                        default:
                            break;
                    }

                    const char *ker_strs[] = {transform_interp_cl, transform_cl};
                    const int   ker_lens[] = {transform_interp_cl_len, transform_cl_len};
                    Program prog;
                    buildProgram(prog, 2, ker_strs, ker_lens, options.str());
                    transformProgs[device] = new Program(prog);
                    transformKernels[device] = new Kernel(*transformProgs[device], "transform_kernel");
                });

                auto transformOp = KernelFunctor<Buffer, const KParam,
                                         const Buffer, const KParam, const Buffer, const KParam,
                                         const int, const int, const int, const int,
                                         const int, const int, const int>
                                         (*transformKernels[device]);

                const int nImg2 = in.info.dims[2];
                const int nImg3 = in.info.dims[3];
                const int nTfs2 = tf.info.dims[2];
                const int nTfs3 = tf.info.dims[3];

                NDRange local(TX, TY, 1);

                int batchImg2 = 1;
                if(nImg2 != nTfs2)
                    batchImg2 = min(nImg2, TI);

                const int blocksXPerImage = divup(out.info.dims[0], local[0]);
                const int blocksYPerImage = divup(out.info.dims[1], local[1]);

                int global_x = local[0]
                             * blocksXPerImage
                             * (nImg2 / batchImg2);
                int global_y = local[1]
                             * blocksYPerImage
                             * nImg3;
                int global_z = local[2]
                             * max((nTfs2 / nImg2), 1)
                             * max((nTfs3 / nImg3), 1);

                NDRange global(global_x, global_y, global_z);

                transformOp(EnqueueArgs(getQueue(), global, local),
                            *out.data, out.info, *in.data, in.info, *tf.data, tf.info,
                            nImg2, nImg3, nTfs2, nTfs3, batchImg2,
                            blocksXPerImage, blocksYPerImage);

                CL_DEBUG_FINISH(getQueue());
            } catch (cl::Error err) {
                CL_TO_AF_ERROR(err);
                throw;
            }
        }
    }
}
