#version 460 core

// 果冻拉伸（jelly stretch）fragment shader。
// 对应飞牛 flutter_assets/shaders/stretch_effect.frag（此处为可读 GLSL 重写，
// 行为一致：沿拖拽轴把已越界的纹理坐标向拉伸边缘非线性压缩）。
//
// uniform:
//   u_overscroll_y / u_overscroll_x : 归一化越界量（越界像素 / 视口边长），带符号
//   u_max_stretch_intensity         : 拉伸强度系数（0..1），作用于越界量
//   u_interpolation_strength        : 边缘压缩的内插强度（0..1）

#include <flutter/runtime/effect_uniforms.glsl>

uniform sampler2D u_texture;
uniform float u_overscroll_y;
uniform float u_overscroll_x;
uniform float u_max_stretch_intensity;
uniform float u_interpolation_strength;

out vec4 frag_color;

// 把拖拽轴上的归一化坐标 t 按越界量 o 压缩：越靠近拖拽对侧压得越狠，
// 在拖拽边缘一侧保持连续（参考实现逐段分支的化简版本）。
float warpAxis(float t, float o, float s) {
  float k = 1.0 / (1.0 + abs(o));
  if (o > 0.0) {
    float d = 1.0 - t;
    if (t <= 1.0) {
      return k - d / (1.0 + o * mix(1.0, d, s));
    }
    return (k - 1.0) + t;
  } else if (o < 0.0) {
    if (t >= 0.0) {
      return 1.0 - (k - t / (1.0 + (-o) * mix(1.0, t, s)));
    }
    return (1.0 - k) + t;
  }
  return t;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  float oy = u_overscroll_y * u_max_stretch_intensity;
  float ox = u_overscroll_x * u_max_stretch_intensity;
  // 与参考实现一致：纵向越界优先，横向仅在纵向为零时生效。
  float o = (u_overscroll_y != 0.0) ? oy : ox;
  vec2 m = uv;
  if (u_overscroll_y != 0.0) {
    m.y = warpAxis(uv.y, o, u_interpolation_strength);
  } else {
    m.x = warpAxis(uv.x, o, u_interpolation_strength);
  }
  // Flutter 上采样器纹理 Y 轴与屏幕坐标相反。
  frag_color = texture(u_texture, vec2(m.x, 1.0 - m.y));
}
