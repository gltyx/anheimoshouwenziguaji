#define ANIMATION_FPS 30.0
#define ANIMATION_INTERVAL (1.0 / ANIMATION_FPS)
#define POSITION_RANGE 500.0
#define QUSTERNION_RANGE 2.0
#define SCALE_RANGE 100.0
#define BONE_OFFSET_MATRIX_RANGE 500.0
#define UNSIGNED_INT_ZIP_FACTOR 1000.0
#define BONE_TRANSFORM_MATRIX_RANGE 500.0
#define MAX_DEPTH 15.0

hfloat RGBAToFloat(hvec4 v)
{
    v *= 255.0;
    hfloat a1 = 16777216.0;
    hfloat a2 = 65536.0;
    hfloat a3 = 256.0;
    hfloat a4 = 4294967296.0;
    hfloat r = (v.a * a1) + (v.b * a2) + (v.g * a3) + (v.r);
    r /= a4;
    return r;
}

// a * 256 * 256 * 256 + b * 256 * 256 + g * 256 + r = f * 256 * 256 * 256 * 256
// a + b / 256 + g / 256 / 256 + r / 256 / 256 / 256  = f * 256
hvec4 floatToRGBA(hfloat f)
{
    // return vec4(f);
    hfloat a = floor(f * 256.0);
    hfloat left = fract(f * 256.0);
    hfloat b = floor(left * 256.0);
    left = fract(left * 256.0);
    hfloat g = floor(left * 256.0);
    left = fract(left * 256.0);
    hfloat r = floor(left * 256.0);
    return vec4(r, g, b, a) / 255.0;
}

bool IsEqual(hfloat a, hfloat b)
{
    return abs(a - b) < 0.01;
}

bool IsVec4Equal(hvec4 a, hvec4 b)
{
    return IsEqual(a[0], b[0]) && IsEqual(a[1], b[1]) && IsEqual(a[2], b[2]) && IsEqual(a[3], b[3]);
}

bool IsMatEqual(hmat4 a, hmat4 b)
{
    return IsVec4Equal(a[0], b[0]) && IsVec4Equal(a[1], b[1]) && IsVec4Equal(a[2], b[2]) && IsVec4Equal(a[3], b[3]);
}

hfloat ExpandFloat(hfloat v, hfloat range)
{
    return v * range * 2.0 - range;
}

hvec3 ExpandVec3(hvec3 v, hfloat range)
{
    return v * range * 2.0 - range;
}

hvec4 ExpandVec4(hvec4 v, hfloat range)
{
    return v * range * 2.0 - range;
}

hmat4 ExpandMat4(hmat4 v, hfloat range)
{
    hmat4 r = v * range * 2.0 - range;
    return mat4(r[0], r[1], r[2], vec4(0.0, 0.0, 0.0, 1.0));
}

hfloat ZipFloat(hfloat v, hfloat range)
{
    return (v + range) / (range * 2.0);
}

hmat4 ZipMat4(hmat4 v, hfloat range)
{
    hmat4 r = (v + range) / (range * 2.0);
    return mat4(r[0], r[1], r[2], vec4(0.0, 0.0, 0.0, 1.0));
}

hfloat ReadFloat(sampler2D t, hfloat texSize, hfloat row, hfloat col)
{
    hfloat y = (row + 0.5) / texSize;
    hfloat x = (col + 0.5) / texSize;
    hvec4 rgba = texture2DLod(t, vec2(x, y),0.0);
    hfloat value = RGBAToFloat(rgba);
    return value;
}

hvec3 ReadVec3(sampler2D tex, hfloat texSize, hfloat row, hfloat col)
{
    hfloat v1 = ReadFloat(tex, texSize, row, col);
    hfloat v2 = ReadFloat(tex, texSize, row, col + 1.0);
    hfloat v3 = ReadFloat(tex, texSize, row, col + 2.0);
    return vec3(v1, v2, v3);
}

hvec4 ReadVec4(sampler2D tex, hfloat texSize, hfloat row, hfloat col)
{
    hfloat v1 = ReadFloat(tex, texSize, row, col);
    hfloat v2 = ReadFloat(tex, texSize, row, col + 1.0);
    hfloat v3 = ReadFloat(tex, texSize, row, col + 2.0);
    hfloat v4 = ReadFloat(tex, texSize, row, col + 3.0);
    return vec4(v1, v2, v3, v4);
}

hmat4 ReadMat4(sampler2D tex, hfloat texSize, hfloat row, hfloat col)
{
    hvec4 v1 = ReadVec4(tex, texSize, row, col);
    col += 4.0;
    hvec4 v2 = ReadVec4(tex, texSize, row, col);
    col += 4.0;
    hvec4 v3 = ReadVec4(tex, texSize, row, col);
    col += 4.0;
    return mat4(v1, v2, v3, vec4(0.0, 0.0, 0.0, 1.0));
}

hmat4 GetTransformMat(hvec3 position, hvec4 rotation, hvec3 scale)
{
    hmat4 positionMat = mat4(
        1.0, 0.0, 0.0, position[0],
        0.0, 1.0, 0.0, position[1],
        0.0, 0.0, 1.0, position[2],
        0.0, 0.0, 0.0, 1.0
    );
    hmat4 rotationMat = Q_toMatrix(rotation);
    hmat4 scaleMat = mat4(
        scale[0], 0.0, 0.0, 0.0,
        0.0, scale[1], 0.0, 0.0,
        0.0, 0.0, scale[2], 0.0,
        0.0, 0.0, 0.0, 1.0
    );
    hmat4 localMat = scaleMat * rotationMat * positionMat;
    return localMat;
}