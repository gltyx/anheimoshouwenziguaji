#ifdef BGFX_SHADER

#include "varying_scenepass.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position _NORMAL _TEXCOORD0 _COLOR0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED
    #ifdef PERPIXEL
        $output vTexCoord _VTANGENT, vNormal, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR
    #else
        $output vTexCoord _VTANGENT, vNormal, vWorldPos, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR
    #endif
#endif
#ifdef COMPILEPS
    #ifdef PERPIXEL
        $input vTexCoord _VTANGENT, vNormal, vWorldPos _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR
    #else
        $input vTexCoord _VTANGENT, vNormal, vWorldPos, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR
    #endif
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "transform.sh"

#else
#include "Uniforms.glsl"
#endif  // BGFX_SHADER

void VS()
{    
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
}

void PS()
{
    gl_FragColor = vec4(1, 1, 1, 1);
}
