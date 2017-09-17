
//
// Fragment shader, Tiled Directional Flow
//
// (c) 2010 frans van hoesel, university of groningen
//
//
// this shader creates animated water by transforming normalmaps
// the scaling and rotation of the normalmaps is done per tile
// and is constant per tile. Each tile can have its own parameters
// for rotation, scaling, and speed of translation
// To hide the seams between the tiles, all seams have another tile
// centered over the seam. The opacity of the tiles decreases towards the
// edge of the tiles, so the edge isn't visible at all.
// Basically, all points have four tiles (A,B,C and D), mixed together
// (although at the edges the contribution of a tile to this mix is 
// reduced to zero).
// The mixing of the tiles each with different parameters gives a nice
// animated look to the water. It is no longer just sliding in one direction, but
// appears to move more like real water. 

// The resulting sum of normalmaps, is used to calculate the refraction of the clouds 
// in a cube map and can also be used for other nice effects. In this example the 
// colormap of the material under water is distorted to fake some kind of refraction
// (for this example the water is a bit too transparent, but it shows this refraction
// better) 

// A flowmap determines in the red and green channel the normalized direction of the
// flow and in the blue channel wavelength.
// The alpha channel is used for the transparency of the water. Near the edge, the 
// water becomes less deep and more transparent. Also near the edge, the waves tend
// to be smaller, so the same alpha channel also scales the height of the waves.
// Currently the wavelength is in its own channel (blue), but could be premultiplied
// to the red and green channels. This makes this channel available for changing the 
// speed of the waves per tile.


// Further improvements
// Besides the obvious improvements mentioned in the code (such as premultiplying
// the direction of the waves with the scale, or moving the texscale multiplication
// to the texture coordinates), one could get rid of tiling in this code and pass it 
// tiled geometry. This way the whole lookup of the flowmap (which is constant over 
// each tile) could be moved to the vertexshader, removing the the construction of 
// the flow rotation matrix. As this is done 4 times per pixel, it might give a big 
// performance boost (one does need to pass on 4 constant matrices to the fragment
// shader, which will cost you a bit of performance).
// 
//////////////////////////////////////////////////////////////////////////////////
//                     This software is Creditware:
//
// you can do whatever you want with this shader except claiming rights 
// you may sell it, but you cannot prevent others from selling it, giving it away 
// or use it as they please.
// 
// Having said that, it would be nice if you gave me some credit for it, when you
// use it.
//
//                     Frans van Hoesel, (c) 2010
//////////////////////////////////////////////////////////////////////////////////


// movie at youtube: http://www.youtube.com/watch?v=TeSuNYvXAiA?hd=1 (in Germany this is blocked by youtube)
// making of at http://www.youtube.com/watch?v=wdcvPegJ1lw&hd=1 (works even in Germany)

// Thanks to Bart Campman, Pjotr Svetachov and Martijn Kragtwijk for their help.

Shader "TiledDirectionalFlow/Water" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FlowMap ("Flow", 2D) = "red" {}
		_WaterNormalMap("Water normal", 2D) = "blue" {}
		_SkyBox("SkyBox", CUBE) = "" {}
		_FlowSpeed("Flow speed", float) = 1.0
		_FlowTileScale("Flow tile scale", float) = 35.0
		_NormalTileScale("Normal tile scale", float) = 10.0
	}
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Lambert
		#pragma target 3.0

		sampler2D _MainTex, _FlowMap, _WaterNormalMap;
		samplerCUBE _SkyBox;
		float _FlowSpeed, _FlowTileScale, _NormalTileScale;

		struct Input 
		{
			float2 uv_MainTex;
			float2 uv_FlowMap;
			float2 uv_WaterNormalMap;
			float3 viewDir;
		};

		void surf (Input IN, inout SurfaceOutput o) 
		{
		
			// texScale determines the amount of tiles generated.
			float texScale = _FlowTileScale;
			// texScale2 determines the repeat of the water texture (the normalmap) itself
			float texScale2 = _NormalTileScale;
			float myangle;
			float transp;
			float3 myNormal;
			
			float2 mytexFlowCoord = IN.uv_FlowMap * texScale;
			// ff is the factor that blends the tiles.
			float2 ff =  abs(2.0*(frac(mytexFlowCoord)) - 1.0) -0.5; 	  
			// take a third power, to make the area with more or less equal contribution
			// of more tile bigger
			ff = 0.5-4.0*ff*ff*ff;
			// ffscale is a scaling factor that compensates for the effect that
			// adding normal vectors together tends to get them closer to the average normal
			// which is a visible effect. For more or less random waves, this factor
			// compensates for it 
			float2 ffscale = sqrt(ff*ff + (1-ff)*(1-ff));
			float2 Tcoord = IN.uv_WaterNormalMap  * texScale2;
			
			// offset makes the water move
			float2 _offset = float2(_Time.x * _FlowSpeed,0);
			
			// I scale the texFlowCoord and floor the value to create the tiling
		    // This could have be replace by an extremely lo-res texture lookup
		    // using NEAREST pixel.
		    float3 flow = tex2D(_FlowMap, floor(mytexFlowCoord)/ texScale).rgb;
		    
		    // flowdir is supposed to go from -1 to 1 and the line below
		    // used to be sample.xy * 2.0 - 1.0, but saves a multiply by
		    // moving this factor two to the sample.b
		    float2 flowdir = flow.xy -0.5;    
		   
		    // sample.b is used for the inverse length of the wave
		    // could be premultiplied in sample.xy, but this is easier for editing flowtexture
		    flowdir *= flow.b;
		    
		    // build the rotation matrix that scales and rotates the complete tile
		    float2x2 rotmat = float2x2(flowdir.x, -flowdir.y, flowdir.y ,flowdir.x);
		    
		    // this is the normal for tile A
		    float2 NormalT0 = tex2D(_WaterNormalMap, mul(rotmat, Tcoord) - _offset).rg;
		    
		    // for the next tile (B) I shift by half the tile size in the x-direction
		    flow = tex2D( _FlowMap, floor((mytexFlowCoord + float2(0.5,0)))/ texScale ).rgb;
		    
		    flowdir = flow.b * (flow.xy - 0.5);
		    rotmat = float2x2(flowdir.x, -flowdir.y, flowdir.y ,flowdir.x);
			// and the normal for tile B...
			// multiply the offset by some number close to 1 to give it a different speed
			// The result is that after blending the water starts to animate and look
			// realistic, instead of just sliding in some direction.
			// This is also why I took the third power of ff above, so the area where the
			// water animates is as big as possible
			// adding a small arbitrary constant isn't really needed, but helps to show
			// a bit less tiling in the beginning of the program. After a few seconds, the
			// tiling cannot be seen anymore so this constant could be removed.
			// For the quick demo I leave them in. In a simulation that keeps running for
			// some time, you could just as well remove these small constant offsets
			float2 NormalT1 = tex2D(_WaterNormalMap, mul(rotmat, Tcoord) - _offset*1.06+0.62).rg ; 
			
			// blend them together using the ff factor
			// use ff.x because this tile is shifted in the x-direction 
			float2 NormalTAB = ff.x * NormalT0 + (1.0-ff.x) * NormalT1;
			
			// the scaling of NormalTab and NormalTCD is moved to a single scale of
			// NormalT later in the program, which is mathematically identical to
			// NormalTAB = (NormalTAB - 0.5) / ffscale.x + 0.5;
			
			// tile C is shifted in the y-direction 
			flow = tex2D( _FlowMap, floor((mytexFlowCoord + float2(0.0,0.5)))/ texScale ).rgb;
			
			flowdir = flow.b * (flow.xy - 0.5);
			rotmat = float2x2(flowdir.x, -flowdir.y, flowdir.y ,flowdir.x);	      
			NormalT0 = tex2D(_WaterNormalMap, mul(rotmat, Tcoord) - _offset*1.33+0.27).rg;
			
			// tile D is shifted in both x- and y-direction
			flow = tex2D( _FlowMap, floor((mytexFlowCoord + float2(0.5,0.5)))/ texScale ).rgb;
			
			flowdir = flow.b * (flow.xy - 0.5);
			rotmat = float2x2(flowdir.x, -flowdir.y, flowdir.y ,flowdir.x);
			NormalT1 = tex2D(_WaterNormalMap, mul(rotmat, Tcoord) - _offset*1.24).rg ;
		
			float2 NormalTCD = ff.x * NormalT0 + (1.0-ff.x) * NormalT1;
			// NormalTCD = (NormalTCD - 0.5) / ffscale.x + 0.5;
			
			// now blend the two values together
			float2 NormalT = ff.y * NormalTAB + (1.0-ff.y) * NormalTCD;
			
			// this line below used to be here for scaling the result
			//NormalT = (NormalT - 0.5) / ffscale.y + 0.5;
			
			// below the new, direct scaling of NormalT
			NormalT = (NormalT - 0.5) / (ffscale.y * ffscale.x);
			// scaling by 0.3 is arbritrary, and could be done by just
			// changing the values in the normal map
			// without this factor, the waves look very strong
			NormalT *= 0.3; 
			
			// to make the water more transparent 
			transp = tex2D( _FlowMap, IN.uv_FlowMap ).a;
			// and scale the normals with the transparency
			NormalT *= transp*transp;
			
			// assume normal of plane is 0,0,1 and produce the normalized sum of adding NormalT to it
    		myNormal = float3(NormalT,sqrt(1-NormalT.x*NormalT.x - NormalT.y*NormalT.y));
			
			float3 reflectDir = reflect(IN.viewDir, myNormal);
			float3 envColor = texCUBE(_SkyBox, reflectDir).rgb;

			// very ugly version of fresnel effect
			// but it gives a nice transparent water, but not too transparent
			myangle = dot(myNormal,normalize(IN.viewDir));
			myangle = 0.95-0.6*myangle*myangle;
			
			// blend in the color of the plane below the water	
			
			// add in a little distortion of the colormap for the effect of a refracted
			// view of the image below the surface. 
			// (this isn't really tested, just a last minute addition
			// and perhaps should be coded differently
			
			// the correct way, would be to use the refract routine, use the alpha channel for depth of 
			// the water (and make the water disappear when depth = 0), add some watercolor to the colormap
			// depending on the depth, and use the calculated refractdir and the depth to find the right
			// pixel in the colormap.... who knows, something for the next version
			float4 base = tex2D(_MainTex, IN.uv_MainTex + myNormal.xy/texScale2*0.03*transp);
			
			base = float4(lerp(base.rgb,envColor,myangle*transp),1.0 );
			
			// note that smaller waves appear to move slower than bigger waves
			// one could use the tiles and give each tile a different speed if that
			// is what you want 

			o.Albedo = base.rgb;
			o.Alpha = base.a;
			
			
			
			
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
