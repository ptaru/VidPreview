//
//  Glass.metal
//  VidPreviewQuickLook
//
//  Metal shader for slider glass effect
//

#include <SwiftUI/SwiftUI_Metal.h>
#include <metal_stdlib>

using namespace metal;

[[stitchable]] half4 glass(float2 position, SwiftUI::Layer layer,
                           float2 thumbCenter, float radius, float isDragging) {
  if (isDragging < 0.5) {
    return layer.sample(position);
  }

  float dist = distance(position, thumbCenter);
  float outerGlowMask = smoothstep(radius + 1.0, radius, dist);

  if (outerGlowMask <= 0.0) {
    return layer.sample(position);
  }

  float2 normPos = (position - thumbCenter) / radius;
  float d = length(normPos);
  float2 dir = (d > 0.0) ? normalize(normPos) : float2(0, 0);

  // Core Refraction & Chromatic Aberration
  float magnification = pow(min(d, 1.0), 2.0) * 0.35;
  float2 refractedPos = position - dir * (magnification * radius);

  float caMask = smoothstep(0.9, 1.0, d);
  float caAmount = caMask * 6.0;
  float2 caOffset = dir * caAmount;

  half4 rSample = layer.sample(refractedPos + caOffset);
  half4 gSample = layer.sample(refractedPos);
  half4 bSample = layer.sample(refractedPos - caOffset);

  half bgAlpha = (rSample.a + gSample.a + bSample.a) / 3.0;
  half baseGlassAlpha = 0.04;

  // Secondary 3D Volume Gradient
  float z = sqrt(max(0.0, 1.0 - d * d));
  float3 normal = float3(normPos.x, normPos.y, z);
  float3 lightDir = normalize(float3(1.0, 1.0, 0.5));
  float softVolumeLight = max(0.0, dot(normal, lightDir));
  float volumeGlow = pow(softVolumeLight, 2.0) * 0.06;
  float volumeShadow =
      mix(1.0, 0.9, pow(max(0.0, dot(normal, -lightDir)), 2.0));

  // Razor-Thin 1-Pixel Edge Lighting
  float razorEdgeMask = smoothstep(radius - 1.0, radius, dist);
  float lightDirectionalFactor = dot(dir, normalize(float2(1.0, 1.0)));

  // Top-left "Black Light" edge
  float blackLightIntensity = max(0.0, -lightDirectionalFactor) * razorEdgeMask;

  // Bottom-right White Light edge - Extremely transparent
  float whiteLightIntensity =
      max(0.0, lightDirectionalFactor) * razorEdgeMask * 0.08;

  // Edge Reflection (Light Wrap)
  float edgeReflIntensity = smoothstep(radius - 0.8, radius, dist);
  float2 outsideSamplePos = position + dir * 0.8;
  half4 outsideSample = layer.sample(outsideSamplePos);
  half3 edgeColor = outsideSample.rgb * 0.2 * edgeReflIntensity;

  // Composition
  half highlightAlphaContrib = half(volumeGlow * 0.2 + razorEdgeMask * 0.01);
  half totalAlpha = saturate(bgAlpha + baseGlassAlpha + highlightAlphaContrib);

  half3 baseColor = half3(rSample.r, gSample.g, bSample.b) * half(volumeShadow);
  baseColor = mix(baseColor, half3(0.0), blackLightIntensity * 0.3);

  half4 effectColor = half4(baseColor, totalAlpha);
  effectColor.rgb += half3(whiteLightIntensity + volumeGlow) + edgeColor;

  // Final Composition
  half4 original = layer.sample(position);
  return mix(original, effectColor, outerGlowMask);
}
