#include "varying_cs.def.sc"
#include <Common/bgfx_compute.sh>
#include "constants.sh"

#ifndef TEXTURE2D_CUBE
SAMPLERCUBE(s_Tex0, 0);
#else
SAMPLER2D(s_Tex0, 0);
#endif
BUFFER_WR(CoeffsBuffer, float, 1);

#define CubeResource s_Tex0

uniform vec4 u_NumSample;

#define reversebits(x) bitfieldReverse(x)

//
// Attributed to:
// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// Holger Dammertz.
// 
vec2 Hammersley(int i, int N) 
{
    float ri = reversebits(i) * 2.3283064365386963e-10f;
    return vec2(float(i) / float(N), ri);
}

//
// Sphere Point Picking:
// https://mathworld.wolfram.com/SpherePointPicking.html
//
vec4 UniformSampleSphere(vec2 E)
{
	// float Phi = 2.0 * M_PI * E.x;
	// float CosTheta = 1.0 - 2.0 * E.y;
	// float SinTheta = sqrt(1 - CosTheta * CosTheta);
    float Phi = E.y * 2.0 * M_PI;
    float CosTheta = 1.0 - E.x;
    float SinTheta = sqrt(1.0 - CosTheta * CosTheta);

	vec3 H;
	H.x = SinTheta * cos(Phi);
	H.y = SinTheta * sin(Phi);
	H.z = CosTheta;

	float PDF = 1.0 / (4 * M_PI);

	return vec4(H, PDF);
}

vec4 TexSpherical(vec3 dir, float lod)
{
#ifndef TEXTURE2D_CUBE
    return textureCubeLod(CubeResource, dir, lod);
#else
    float n = length(dir.xz);
    vec2 pos = vec2( (n>0.0000001) ? dir.x / n : 0.0, dir.y);
    pos = acos(pos)*M_INV_PI;
    pos.x = (dir.z > 0.0) ? pos.x*0.5 : 1.0-(pos.x*0.5);
    pos.x = 1.0-pos.x;
    vec4 color = texture2DLod(CubeResource, pos, lod); // anisotropic sampler
    return color;
#endif
}

#define Init vec3(0.0, 0.0, 0.0)

NUM_THREADS(1, 1, 1)
void main()
{
    int numSample = int(u_NumSample.x);

    // float weight = 4.0f * M_PI;
	// float factor = weight / float(numSample);
    float factor = 1.0 / u_NumSample.x;
	
	vec3 coeffs[9];
    for (int i = 0; i < 9; ++i)
    {
        coeffs[i] = Init;
    }

    for (int i = 0; i < numSample; i++)
    {
		vec2 E = Hammersley(i, numSample);
		
		vec3 normal = UniformSampleSphere(E).xyz; // normal
        normal = normalize(normal);
        // 转换到Z轴朝上的坐标系
        // normal = vec3(normal.x, normal.z, normal.y);

        vec3 color = TexSpherical(normal, 0.0).rgb;
        #ifdef TEXTURE2D_CUBE
            color = pow(color, 2.2);
        #endif

        float Y00     = 0.282095;
        float Y11     = 0.488603 * normal.x;
        float Y10     = 0.488603 * normal.z;
        float Y1_1    = 0.488603 * normal.y;
        float Y21     = 1.092548 * normal.x*normal.z;
        float Y2_1    = 1.092548 * normal.y*normal.z;
        float Y2_2    = 1.092548 * normal.y*normal.x;
        float Y20     = 0.946176 * normal.z * normal.z - 0.315392;
        float Y22     = 0.546274 * (normal.x*normal.x - normal.y*normal.y);

        vec3 L00   = color * Y00;
        vec3 L11   = color * Y11;
        vec3 L10   = color * Y10;
        vec3 L1_1  = color * Y1_1;
        vec3 L21   = color * Y21;
        vec3 L2_1  = color * Y2_1;
        vec3 L2_2  = color * Y2_2;
        vec3 L20   = color * Y20;
        vec3 L22   = color * Y22;

        coeffs[0] += L00;
        coeffs[1] += L11;
        coeffs[2] += L10;
        coeffs[3] += L1_1;
        coeffs[4] += L21;
        coeffs[5] += L2_1;
        coeffs[6] += L2_2;
        coeffs[7] += L20;
        coeffs[8] += L22;

        // float h[9] = { Y00, Y11, Y10, Y1_1, Y21, Y2_1, Y2_2, Y20, Y22 };
        // for (int j = 0; j < 9; ++j)
        // {
        //     coeffs[j] += h[j] * color;
        // }
    }
    
    for (int i = 0; i < 9; ++i)
    {
        coeffs[i] *= factor;
    }

    for (int i = 0; i < 9; ++i)
    {
        CoeffsBuffer[i] = coeffs[i].r;
        CoeffsBuffer[i + 9] = coeffs[i].g;
        CoeffsBuffer[i + 18] = coeffs[i].b;
    }
}
