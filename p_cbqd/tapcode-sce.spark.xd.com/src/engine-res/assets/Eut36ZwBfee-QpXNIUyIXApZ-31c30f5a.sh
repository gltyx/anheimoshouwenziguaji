// SSAORasterize uniforms - WebGL compatible version

uniform hvec4 u_ssaoParams[12];

#define u_viewportPixelSize                 u_ssaoParams[0].xy
#define u_halfViewportPixelSize             u_ssaoParams[0].zw
#define u_depthUnpackConsts                 u_ssaoParams[1].xy
#define u_cameraFarClip                     u_ssaoParams[1].z
#define u_ndcToViewMul                      u_ssaoParams[2].xy
#define u_ndcToViewAdd                      u_ssaoParams[2].zw
#define u_effectRadius                      u_ssaoParams[3].x
#define u_effectShadowStrength              u_ssaoParams[3].y
#define u_effectShadowPow                   u_ssaoParams[3].z
#define u_effectShadowClamp                 u_ssaoParams[3].w
#define u_effectFadeOutMul                  u_ssaoParams[4].x
#define u_effectFadeOutAdd                  u_ssaoParams[4].y
#define u_effectHorizonAngleThreshold       u_ssaoParams[4].z
#define u_effectSamplingRadiusNearLimitRec  u_ssaoParams[4].w
#define u_depthPrecisionOffsetMod           u_ssaoParams[5].x
#define u_negRecEffectRadius                u_ssaoParams[5].y
#define u_detailAOStrength                  u_ssaoParams[5].z
#define u_invSharpness                      u_ssaoParams[5].w
#define u_normalsUnpackMul                  u_ssaoParams[6].x
#define u_normalsUnpackAdd                  u_ssaoParams[6].y
#define u_qualityLevel                      u_ssaoParams[6].z
#define u_blurPassIndex                     u_ssaoParams[6].w
#define u_normalsWorldToViewspaceMatrix0    u_ssaoParams[7]
#define u_normalsWorldToViewspaceMatrix1    u_ssaoParams[8]
#define u_normalsWorldToViewspaceMatrix2    u_ssaoParams[9]
#define u_normalsWorldToViewspaceMatrix3    u_ssaoParams[10]
#define u_viewport2xPixelSize               u_ssaoParams[11].xy
#define u_viewport2xPixelSize_x_025         u_ssaoParams[11].zw

// Quality level tap counts
#define SSAO_TAP_COUNT_LOW      3
#define SSAO_TAP_COUNT_MEDIUM   5
#define SSAO_TAP_COUNT_HIGH     12

// Haloing reduction
#define SSAO_HALOING_REDUCTION_AMOUNT 0.6

// Detail AO
#define SSAO_DETAIL_AO_AMOUNT 0.5
