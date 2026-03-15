#include "varying_scenepass_outsurface.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position _SKINNED _INSTANCED
    $output vWorldPos, vScreenPos
#endif
#ifdef COMPILEPS
    $input vWorldPos, vScreenPos
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

uniform vec4 u_SurfaceColor;

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vScreenPos = GetScreenPos(gl_Position);
}

void PS()
{
    float f = 20.0;
    float t = 9.0 / 10.0;
    float offset = f * 0.5;
    float xx = mod(vWorldPos.x + offset, f);
    float yy = mod(vWorldPos.y + offset, f);
    if (xx <= f * t  && yy <= f * t
      )
    {
        gl_FragColor = u_SurfaceColor;
        gl_FragColor.a *= 0.2;
    }
    else
        gl_FragColor = u_SurfaceColor;

    gl_FragColor.a *= 0.35;
}
