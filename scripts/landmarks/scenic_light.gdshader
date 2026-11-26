shader_type canvas_item;
render_mode unshaded;

// The RGB plate separates sky, open water and foliage in the original painting's own coordinates.
uniform sampler2D landscape_plate : filter_linear, repeat_disable;
uniform bool has_plate = false;
uniform bool painted_season = false;
uniform int season_id = 0;
uniform int phase_id = 1;
uniform int ecology = 0;
uniform float landmark_seed = 0.14;
uniform float art_aspect = 1.7778;
uniform float breeze = 0.0;
uniform vec2 light_pos = vec2(.39,.10);

float grain(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(.1031,.1030,.0973));
	q += dot(q, q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise2(vec2 p) {
	vec2 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(grain(cell),grain(cell+vec2(1,0)),f.x),mix(grain(cell+vec2(0,1)),grain(cell+vec2(1)),f.x),f.y);
}
float brightness(vec3 rgb) { return dot(rgb,vec3(.28,.56,.16)); }
float star(vec2 uv, vec2 grid) {
	vec2 cell=floor(uv*grid); vec2 p=fract(uv*grid)-vec2(.14+.72*grain(cell+landmark_seed*257.0),.15+.7*grain(cell+66.1));
	p.y *= (grid.x/grid.y)/art_aspect;
	float rnd=grain(cell+7.81);
	return (1.0-smoothstep(.008,.045+.025*rnd,length(p)))*smoothstep(.63,.99,rnd);
}
void fragment() {
	vec2 uv=UV;
	vec3 src=texture(TEXTURE,uv).rgb;
	float l=brightness(src);
	vec3 regions=texture(landscape_plate,uv).rgb;
	float sky=has_plate ? regions.r : (1.0-smoothstep(.12,.31,uv.y))*smoothstep(-.12,.04,src.b-src.r+.10);
	float water=has_plate ? regions.g : 0.0;
	float plant=has_plate ? regions.b : 0.0;
	float terrain=1.0-sky;
	float green=plant*terrain;
	float wet=water*terrain;
	float scale_x=art_aspect;
	vec2 to_light=(uv-light_pos)*vec2(scale_x,1.0);
	float dist=length(to_light);
	float sunlight=exp(-dist*dist*4.2);
	float far_air=1.0-smoothstep(.22,.82,uv.y);
	vec2 grain_at=uv*vec2(205.,146.)+landmark_seed*73.;
	float dust=noise2(grain_at);
	float field=noise2(uv*vec2(21.,16.)+landmark_seed*29.);
	vec2 texel=TEXTURE_PIXEL_SIZE;
	float bevel=clamp((l-brightness(texture(TEXTURE,uv+vec2(0.,texel.y*2.5)).rgb))*4.2,0.,1.);
	float red_earth=smoothstep(-.02,.21,src.r-src.b)*terrain*(1.0-wet)*(1.0-green);
	vec3 land=src;
	vec3 sky_ink=src;
	if (season_id==0) {
		land=mix(land,vec3(l*.78+.13,l*.86+.17,l*.66+.13),green*.65);
		land+=vec3(.012,.026,.006)*(terrain-green)*far_air;
		sky_ink=mix(src,vec3(.73,.84,.83),.16);
	} else if (season_id==1) {
		land=mix(vec3(l),src,1.13)*vec3(1.018,1.01,.967);
		land=mix(land,vec3(l*.47+.01,l*.81+.08,l*.57+.02),green*.72);
		sky_ink=mix(src,vec3(.20,.60,.78)+uv.y*.38,.26);
	} else if (season_id==2) {
		land=mix(land,vec3(.47+.53*l,.23+.57*l,.12+.28*l)+vec3(.065,.022,0.)*(field-.45),green*.9);
		land=mix(land,land*vec3(1.09,.99,.84),(.36+.64*red_earth)*terrain);
		sky_ink=mix(src,vec3(.74,.79,.79),.19);
	} else {
		land=mix(src,vec3(l*.89+.045,l*.96+.064,l*1.04+.10),.61);
		land=mix(land,vec3(.24,.235,.22)+l*vec3(.46,.44,.42),green*.83);
		// Broken pale pigment follows upward-facing edges of masonry, ridges and bare ground.
		float frost=(bevel*.70+smoothstep(.40,.84,l)*(.05+.17*dust))*smoothstep(.20,.76,field+.20*dust);
		land=mix(land,vec3(.82,.87,.87),frost*terrain*(1.-wet)*(ecology==5?.65:1.));
		sky_ink=mix(src,vec3(.75,.82,.87),.43);
	}
	if (painted_season) {
		land=mix(src,land,.13);
		sky_ink=mix(src,sky_ink,.24);
	}
	// Mineral strokes retain the contours of the underlying ink in every season.
	if(ecology==0 || ecology==1 || ecology==6 || ecology==7) {
		float strand=.5+.5*sin(uv.y*600.+uv.x*31.+5.*noise2(uv*vec2(17.,8.))+breeze*.34);
		float powder=red_earth*smoothstep(.36,.86,uv.y)*smoothstep(.52,.81,field);
		float strength=season_id==0?.053:(season_id==1?.023:(season_id==2?.085:.042));
		land+=vec3(1.,.78,.54)*(strand-.25)*strength*powder;
	}
	if (wet>.001) {
		float low_wave=sin(uv.y*uv.y*490.+noise2(vec2(uv.x*18.,uv.y*22.))*7.+breeze*.8);
		float broken=noise2(uv*vec2(67.,81.)+vec2(breeze*.11,0.));
		float mark=smoothstep(.66,.98,low_wave)*smoothstep(.46,.74,broken);
		if(season_id==3) land=mix(land,vec3(.53,.74,.77),wet*(.16+.29*mark));
		else land+=wet*mark*vec3(.08,.10,.087);
	}
	// A nearby dark pigment edge casts a short relief shadow away from the light.
	vec2 cast_direction=normalize(to_light+vec2(.00001))/vec2(art_aspect,1.);
	float shadow_length=phase_id==1?.0028:(phase_id==3?.005:.009);
	float facing=l-brightness(texture(TEXTURE,clamp(uv-cast_direction*shadow_length,vec2(0),vec2(1))).rgb);
	land*=1.0-terrain*(1.-.83*wet)*clamp((facing-.065)*.37,0.,.14);
	vec3 result=mix(land,sky_ink,sky);
	float sun_radius=.0165;
	if (phase_id==0) {
		vec3 air=mix(vec3(.45,.63,.68), vec3(1.0,.72,.50), clamp(sunlight*(.64+uv.y*.49)+.15,0.,1.));
		result=mix(result,result*vec3(.94,.89,.88)+vec3(.075,.044,.023)*sunlight,.9);
		result=mix(result,air,sky*(.45+.13*sunlight));
		result+=vec3(.12,.046,.018)*sunlight*terrain*(.4+.6*l);
	} else if (phase_id==1) {
		result+=vec3(.022,.018,.005)*sunlight*(.35+l*.6);
		sun_radius=.012;
	} else if (phase_id==2) {
		vec3 air=mix(vec3(.43,.43,.59),vec3(.98,.57,.37),sunlight*.82+.12);
		result=result*vec3(.95,.79,.77)+vec3(.066,.023,.005)*sunlight;
		result=mix(result,air,sky*.63);
		result+=vec3(.14,.057,.014)*terrain*sunlight*(.35+bevel*.62);
		sun_radius=.022;
	} else {
		vec3 night=mix(vec3(.042,.085,.15), vec3(.27,.405,.475),clamp(l+sunlight*.09,0.,1.));
		vec3 deep_sky=mix(vec3(.065,.135,.24),vec3(.20,.32,.40),clamp(uv.y*1.9+l*.19+sunlight*.20,0.,1.));
		result=mix(night+(land-vec3(brightness(land)))*.34,deep_sky,sky*.89);
		result+=terrain*sunlight*vec3(.025,.045,.052)*(.28+bevel*.72);
		float stars=(star(uv,vec2(62.,35.))+star(uv+vec2(.23,-.16),vec2(37.,21.))*.75)*(.9+.1*sin(breeze*.66+uv.x*193.));
		result+=sky*stars*vec3(.85,.82,.60);
		float rim=(1.0-smoothstep(.018,.0198,dist))*smoothstep(.012,.0145,length(to_light-vec2(.007,-.004)));
		result=mix(result,vec3(.98,.92,.70),sky*rim*.96);
		result+=sky*exp(-dist*55.)*vec3(.085,.09,.075);
	}
	if (phase_id<3) {
		float disc=1.0-smoothstep(sun_radius,sun_radius+.0018,dist);
		float halo=exp(-dist*(phase_id==1?47.:24.));
		result+=sky*halo*vec3(.15,.095,.035);
		result=mix(result,vec3(1.,.935,.72),disc*sky*(phase_id==1?.83:.94));
	}
	// Thin gusts follow bare alluvium, wave glitter stays on water, and small flecks
	// drift beside painted foliage without introducing plants on masonry or rock.
	if (phase_id<3) {
		if ((ecology==0 || ecology==1 || ecology==7) && season_id!=3) {
			vec2 dune=uv*vec2(8.,103.)+vec2(-breeze*.095+landmark_seed*19.,breeze*.014);
			float veil=smoothstep(.78,.93,noise2(dune)+.10*noise2(dune*2.4));
			float edge=terrain*(1.-wet)*(1.-green)*smoothstep(.57,.83,uv.y)*smoothstep(.12,.50,l);
			result=mix(result,vec3(.95,.78,.53),veil*edge*(season_id==0?.092:.051));
		} else if((ecology==3 || ecology==4 || ecology==6 || ecology==5) && season_id!=3) {
			vec2 drift=uv+vec2(breeze*.0024,-breeze*.0014);
			vec2 pitch=vec2(31.,21.);
			vec2 id=floor(drift*pitch);
			vec2 f=fract(drift*pitch)-vec2(.15+.70*grain(id+landmark_seed),.15+.70*grain(id+21.8));
			float flake=(1.-smoothstep(.15,1.,length(f*vec2(8.1,23.))))*smoothstep(.89,.99,grain(id+31.));
			result=mix(result,season_id==2?vec3(.85,.59,.29):vec3(.84,.86,.57),flake*green*.48);
		}
	}
	// Reflected light is confined to the open water of the illuminated side of the scene.
	float gleam=pow(max(0.,1.-abs(uv.x-light_pos.x)*3.6),3.)*smoothstep(.58,.97,sin(uv.y*840.+field*17.+breeze*.8));
	result+=wet*gleam*smoothstep(.23,.68,noise2(uv*vec2(28.,77.)+vec2(breeze*.05,0.)))*(phase_id==3?vec3(.078,.102,.12):vec3(.145,.126,.073));
	COLOR=vec4(clamp(result,vec3(0),vec3(1)),1.);
}
