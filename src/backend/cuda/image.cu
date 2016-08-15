/*******************************************************
 * Copyright (c) 2014, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

// Parts of this code sourced from SnopyDogy
// https://gist.github.com/SnopyDogy/a9a22497a893ec86aa3e

#if defined(WITH_GRAPHICS)

#include <Array.hpp>
#include <image.hpp>
#include <err_cuda.hpp>
#include <debug_cuda.hpp>
#include <interopManager.hpp>

using af::dim4;

namespace cuda
{

template<typename T>
void copy_image(const Array<T> &in, const fg::Image* image)
{
    if(InteropManager::checkGraphicsInteropCapability()) {
        InteropManager& intrpMngr = InteropManager::getInstance();

        cudaGraphicsResource *cudaPBOResource = intrpMngr.getBufferResource(image);

        const T *d_X = in.get();
        // Map resource. Copy data to PBO. Unmap resource.
        size_t num_bytes;
        T* d_pbo = NULL;
        cudaGraphicsMapResources(1, &cudaPBOResource, 0);
        cudaGraphicsResourceGetMappedPointer((void **)&d_pbo, &num_bytes, cudaPBOResource);
        cudaMemcpyAsync(d_pbo, d_X, num_bytes, cudaMemcpyDeviceToDevice,
                        cuda::getStream(cuda::getActiveDeviceId()));
        cudaGraphicsUnmapResources(1, &cudaPBOResource, 0);

        POST_LAUNCH_CHECK();
        CheckGL("After cuda resource copy");
    } else {
        CheckGL("Begin CUDA fallback-resource copy");
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, image->pbo());
        glBufferData(GL_PIXEL_UNPACK_BUFFER, image->size(), 0, GL_STREAM_DRAW);
        GLubyte* ptr = (GLubyte*)glMapBuffer(GL_PIXEL_UNPACK_BUFFER, GL_WRITE_ONLY);
        if (ptr) {
            CUDA_CHECK(cudaMemcpy(ptr, in.get(), image->size(), cudaMemcpyDeviceToHost));
            glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);
        }
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        CheckGL("End CUDA fallback-resource copy");
    }
}

#define INSTANTIATE(T)      \
    template void copy_image<T>(const Array<T> &in, const fg::Image* image);

INSTANTIATE(float)
INSTANTIATE(double)
INSTANTIATE(int)
INSTANTIATE(uint)
INSTANTIATE(uchar)
INSTANTIATE(char)
INSTANTIATE(ushort)
INSTANTIATE(short)

}

#endif
