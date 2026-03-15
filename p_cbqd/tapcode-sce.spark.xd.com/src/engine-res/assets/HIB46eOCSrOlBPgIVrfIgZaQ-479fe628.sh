#ifdef SPOT_LIGHT_3DLUT //锥光3DLUT
#define VOLUMETRIC_WORK_GROUP 32
#else
#define VOLUMETRIC_WORK_GROUP 128
#endif

#define MAX_LUT_INTENSITY 1.0

#define LOG_BLACK_POINT 0.00390625 // exp2(-8);

#ifdef COMPILECS
uniform hvec4 u_ScatteringAndG;
uniform hvec4 u_Extinction;

hfloat HGPhase(hfloat cosTheta, hfloat g)
{
    hfloat g2 = g * g;
    return (1.0 - g2) / (4.0 * M_PI * pow(1 + g2 - 2 * g * cosTheta, 1.5));
}

hvec3 ScatterStep(hvec3 accumulateL, hvec3 accumulateTr, hvec3 intensity, hfloat stepLength, out hvec3 transmittance)
{
    stepLength = max(stepLength, 1e-4);
    //我们单位要除100
    hvec3 stepTransmittance = exp(-stepLength * 0.01 * u_Extinction);

    hvec3 sliceIntegral = intensity;// * (1.0 - stepTransmittance);
    accumulateL += sliceIntegral * accumulateTr * u_ScatteringAndG.xyz * (stepLength * 0.01);
    accumulateTr = accumulateTr  * stepTransmittance;
    transmittance = accumulateTr;
    return accumulateL;
}

#endif

//O1 + tD1 intersect O2 + sD2, return t
hfloat LineIntersectLine(hvec3 O1, hvec3 D1, hvec3 O2, hvec3 D2)
{
    hvec3 D1xD2 = cross(D1, D2);
    hvec3 O21xD2 = cross(O2 - O1, D2);
    return dot(O21xD2, D1xD2) / dot(D1xD2, D1xD2);
}

float Random3DTo1D(vec3 value,float a,vec3 b)
{
	vec3 smallValue = sin(value);
	float  random = dot(smallValue, b);
	random = frac(sin(random) * a);
	return random;
}

hfloat DepthFallOff(hvec3 minPos, hvec3 maxPos, hvec4 depthVec, hfloat linearDepth, hfloat strength)
{    
    hfloat minDepth = dot(minPos, depthVec.xyz) + depthVec.w;
    hfloat maxDepth = dot(maxPos, depthVec.xyz) + depthVec.w;

    hfloat linearfalloff = clamp((linearDepth - minDepth) / (maxDepth - minDepth), 0.0, 1.0);
    //让近处的权重更大，让阴影的权重更大
    return pow(linearfalloff, strength);
}