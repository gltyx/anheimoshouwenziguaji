#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh" 

#ifdef FIRST_PASS
SAMPLER2D(u_DiffMap, 0);
IMAGE2D_RW(u_ComputeBlur0, rgba8, 1);
#else
IMAGE2D_RW(u_ComputeBlur0, rgba8, 0);
IMAGE2D_RW(u_ComputeBlur1, rgba8, 1);
#endif

uniform hvec4 u_BlurParams;
uniform hvec4 u_TexSize;
#define cKernelHalf u_BlurParams.x
//kernel size = halfSize * 2 + 1

NUM_THREADS(64, 1, 1)
void main()
{
    uint index = gl_GlobalInvocationID.x;
	uvec2 dim = u_TexSize.xy;
    float scale = 1.0 / (2.0 * cKernelHalf + 1.0);

#ifdef BLUR_VERTICAL
    if (dim.x < index + 1)
        return;
    hvec3 colorSum = imageLoad(u_ComputeBlur0, ivec2(index, 0)).rgb * float(cKernelHalf + 1);
    for (int y = 1; y <= cKernelHalf; ++y )
    {
        colorSum += imageLoad(u_ComputeBlur0, ivec2(index, y)).rgb;
    }
    for (int y = 0; y < dim.y; ++y)
    {
        imageStore(u_ComputeBlur1, ivec2(index, y), vec4(colorSum * scale, 1.0));

        hvec3 left = imageLoad(u_ComputeBlur0, ivec2(index, max(y - cKernelHalf, 0))).rgb;
        hvec3 right = imageLoad(u_ComputeBlur0, ivec2(index, min(y + cKernelHalf + 1, dim.y - 1))).rgb;
        colorSum = colorSum - left + right;
    }
#else // HORIZONTAL
    if (dim.y < index + 1)
        return;
#ifdef FIRST_PASS
    hvec2 uv = hvec2(0.0, float(index)) / dim;
    hvec3 colorSum = texture2DLod(u_DiffMap, uv, 0.0).rgb * float(cKernelHalf + 1);
#else
    hvec3 colorSum = imageLoad(u_ComputeBlur0, ivec2(0, index)).rgb * float(cKernelHalf + 1);
#endif
    for (int x = 1; x <= cKernelHalf; ++x )
    {
#ifdef FIRST_PASS
        uv = hvec2(float(x), float(index)) / dim;
        colorSum += texture2DLod(u_DiffMap, uv, 0.0).rgb;
#else
        colorSum += imageLoad(u_ComputeBlur0, ivec2(x, index)).rgb;
#endif
    }
    for (int x = 0; x < dim.x; ++x)
    {
#ifdef FIRST_PASS
        imageStore(u_ComputeBlur0, ivec2(x, index), vec4(colorSum * scale, 1.0));
#else
        imageStore(u_ComputeBlur1, ivec2(x, index), vec4(colorSum * scale, 1.0));
#endif

#ifdef FIRST_PASS
        uv = hvec2(float(max(x - cKernelHalf - 1, 0)), float(index)) / dim;
        hvec3 left = texture2DLod(u_DiffMap, uv, 0.0).rgb;
        uv = hvec2(float(min(x + cKernelHalf, dim.x - 1)), float(index)) / dim;
        hvec3 right = texture2DLod(u_DiffMap, uv, 0.0).rgb;
#else
        hvec3 left = imageLoad(u_ComputeBlur0, ivec2(max(x - cKernelHalf, 0), index)).rgb;
        hvec3 right = imageLoad(u_ComputeBlur0, ivec2(min(x + cKernelHalf + 1, dim.x - 1), index)).rgb;
#endif
        colorSum = colorSum - left + right;
    }
#endif
}