#include "ReShade.fxh"

uniform int Look < ui_category="DLSS 5 Look"; ui_type="combo"; ui_label="Appearance"; ui_items="Faithful\0Natural\0Cinematic\0Cinematic Strong\0"; > = 2;
uniform float Mix < ui_category="DLSS 5 Look"; ui_type="slider"; ui_label="Effect mix"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 1.0;
uniform float MaterialDetail < ui_category="Reconstruction"; ui_type="slider"; ui_label="Material detail"; ui_min=0.0; ui_max=2.0; ui_step=0.01; > = 1.15;
uniform float ShapeDefinition < ui_category="Reconstruction"; ui_type="slider"; ui_label="Shape definition"; ui_min=0.0; ui_max=2.0; ui_step=0.01; > = 1.20;
uniform float LocalLighting < ui_category="Reconstruction"; ui_type="slider"; ui_label="Local lighting"; ui_min=0.0; ui_max=2.0; ui_step=0.01; > = 1.15;
uniform float SkinDetail < ui_category="Skin and hair"; ui_type="slider"; ui_label="Skin microstructure"; ui_min=0.0; ui_max=2.0; ui_step=0.01; > = 1.10;
uniform float SkinSoftness < ui_category="Skin and hair"; ui_type="slider"; ui_label="Skin highlight softness"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.48;
uniform bool DetectSkin < ui_category="Skin and hair"; ui_label="Automatic skin mask"; > = true;
uniform float SpecularControl < ui_category="Light and colour"; ui_type="slider"; ui_label="Plastic/specular reduction"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.58;
uniform float HighlightRollOff < ui_category="Light and colour"; ui_type="slider"; ui_label="Highlight roll-off"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.42;
uniform float ColourSeparation < ui_category="Light and colour"; ui_type="slider"; ui_label="Material colour separation"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.28;
uniform float ShadowDepth < ui_category="Light and colour"; ui_type="slider"; ui_label="Contact-shadow impression"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.24;
uniform float AntiHalo < ui_category="Safety"; ui_type="slider"; ui_label="Edge/halo protection"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.78;
uniform float FlatAreaProtection < ui_category="Safety"; ui_type="slider"; ui_label="Flat/noisy area protection"; ui_min=0.0; ui_max=1.0; ui_step=0.01; > = 0.62;
uniform int Inspect < ui_category="Debug"; ui_type="combo"; ui_label="Inspect"; ui_items="Final image\0Skin mask\0Material residual\0Local lighting\0"; > = 0;

float Y(float3 c){return dot(c,float3(.2126,.7152,.0722));}
float Skin(float3 c,float y){float cb=(c.b-y)*.539,cr=(c.r-y)*.635;return saturate(smoothstep(.012,.055,cr)*(1-smoothstep(.19,.30,cr))*(1-smoothstep(.025,.145,cb))*smoothstep(.05,.17,y)*(1-smoothstep(.86,1,y)));}

texture DL5Base {Width=BUFFER_WIDTH;Height=BUFFER_HEIGHT;Format=R16F;}; sampler sDL5Base {Texture=DL5Base;MinFilter=LINEAR;MagFilter=LINEAR;};
texture DL5Fine {Width=BUFFER_WIDTH;Height=BUFFER_HEIGHT;Format=RG16F;}; sampler sDL5Fine {Texture=DL5Fine;MinFilter=LINEAR;MagFilter=LINEAR;};

float PSBase(float4 pos:SV_Position,float2 uv:TEXCOORD):SV_Target
{
 float2 p=BUFFER_PIXEL_SIZE;float yc=Y(tex2D(ReShade::BackBuffer,uv).rgb),sum=0,ws=0;
 [unroll]for(int j=-2;j<=2;j++)[unroll]for(int i=-2;i<=2;i++){float yy=Y(tex2D(ReShade::BackBuffer,uv+float2(i,j)*p).rgb);float spatial=1.0/(1.0+abs(i)+abs(j));float range=exp(-abs(yy-yc)*18.0);float w=spatial*range;sum+=yy*w;ws+=w;}return sum/ws;
}
float2 PSDecompose(float4 pos:SV_Position,float2 uv:TEXCOORD):SV_Target
{
 float2 p=BUFFER_PIXEL_SIZE;float y=Y(tex2D(ReShade::BackBuffer,uv).rgb),b=tex2D(sDL5Base,uv).r;
 float cross=(Y(tex2D(ReShade::BackBuffer,uv+float2(1,0)*p).rgb)+Y(tex2D(ReShade::BackBuffer,uv+float2(-1,0)*p).rgb)+Y(tex2D(ReShade::BackBuffer,uv+float2(0,1)*p).rgb)+Y(tex2D(ReShade::BackBuffer,uv+float2(0,-1)*p).rgb)+4*y)/8;
 return float2(y-cross,cross-b);
}
float4 PSCompose(float4 pos:SV_Position,float2 uv:TEXCOORD):SV_Target
{
 float2 p=BUFFER_PIXEL_SIZE;float3 src=tex2D(ReShade::BackBuffer,uv).rgb;float y=Y(src),base=tex2D(sDL5Base,uv).r;float2 d=tex2D(sDL5Fine,uv).rg;
 float yn=Y(tex2D(ReShade::BackBuffer,uv+float2(0,-1)*p).rgb),ys=Y(tex2D(ReShade::BackBuffer,uv+float2(0,1)*p).rgb),ye=Y(tex2D(ReShade::BackBuffer,uv+float2(1,0)*p).rgb),yw=Y(tex2D(ReShade::BackBuffer,uv+float2(-1,0)*p).rgb);
 float lo=min(y,min(min(yn,ys),min(ye,yw))),hi=max(y,max(max(yn,ys),max(ye,yw))),range=max(hi-lo,.0001),skin=DetectSkin?Skin(src,y):0;
 float cinematic=Look>=2?1:0,strong=Look==3?1:0,natural=Look==1?1:0;
 float fineGain=MaterialDetail*(natural>0.5?.68:1.0)*(1+.25*cinematic+.22*strong);float shapeGain=ShapeDefinition*(natural>0.5?.72:1.0)*(1+.30*cinematic+.25*strong);
 float gate=lerp(1,smoothstep(.005,.035,range),FlatAreaProtection);float skinGain=lerp(1,.55+.62*SkinDetail,skin);
 float residual=(d.x*fineGain*skinGain+d.y*shapeGain)*gate;
 float local=(y-base)*LocalLighting*(.20+.12*cinematic+.08*strong)*(1-HighlightRollOff*smoothstep(.72,.98,y));
 float limit=lerp(.10,.018,AntiHalo)+range*lerp(.30,.10,AntiHalo);residual=clamp(residual+local,-limit,limit);
 float ny=y+residual;
 float spec=saturate((y-base-.018)*12)*smoothstep(.35,.92,y);ny-=spec*SpecularControl*(.010+.018*cinematic)*lerp(1,SkinSoftness,skin);
 float oc=saturate((base-y-.012)*10)*smoothstep(.08,.72,y);ny-=oc*ShadowDepth*(.008+.010*cinematic);
 float shoulder=ny/(1+ny*(.035+.045*cinematic+.025*strong)*HighlightRollOff);ny=lerp(ny,shoulder,.40+.25*cinematic);
 float mid=1-abs(saturate(ny)*2-1);ny+=(ny-.5)*(.025+.065*cinematic+.035*strong-.012*natural)*mid;ny=clamp(ny,lerp(0,lo-.012,AntiHalo),lerp(1,hi+.012,AntiHalo));
 float3 outc=src*((ny+1e-5)/(y+1e-5));float chroma=1+ColourSeparation*(.045+.045*cinematic)*(1-.55*skin);outc=lerp(ny.xxx,outc,chroma);outc=saturate(outc);
 outc=lerp(src,outc,Mix);
 if(Inspect==1)return float4(skin.xxx,1);if(Inspect==2)return float4((.5+residual*5).xxx,1);if(Inspect==3)return float4((.5+local*8).xxx,1);return float4(outc,1);
}
technique DLSS5_Look <ui_label="DLSS 5 Appearance Reconstruction v3";ui_tooltip="Multi-scale spatial material and lighting approximation. No temporal history.";>
{
 pass BuildGuidedBase {VertexShader=PostProcessVS;PixelShader=PSBase;RenderTarget=DL5Base;}
 pass DecomposeMaterial {VertexShader=PostProcessVS;PixelShader=PSDecompose;RenderTarget=DL5Fine;}
 pass ReconstructAppearance {VertexShader=PostProcessVS;PixelShader=PSCompose;}
}
