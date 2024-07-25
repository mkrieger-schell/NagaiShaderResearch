# Max Krieger - "Nagai" Shader Research

## Premise
This repository is a public release of shader r&d work I conducted at Schell Games over the course of 2023 and 2024 (under the mentorship of Manuela Malasaña), in an attempt to recreate a particular illustrator's style using the Unity built-in render pipeline.

**Note: this repo is code-only and does not contain any project assets used during development, since they cannot be redistributed under the MIT License.** You can see screenshots of the project in this readme.

### License Information

As marked on the repo, this source has been released under the MIT License.

### Installation

1. Extract the contents of this repo into the root folder of an empty Unity project. Note that **this project runs in the built-in (legacy) renderer pipeline** and is not compatible with the SRP system.

2. To configure the per-object outlining, navigate to **Project Settings -> Graphics -> Built-In Shader Settings**. Set "Depth Normals" to use a custom shader, and use Resources/NagaiDepthNormals.shader there.

3. Create materials using the provided shaders.

4. Attach both included scripts (OutlineCamera.cs and NagaiGlobals.cs) to your scene's Camera and set appropriate Inspector references. (See code comments for more info).

5. Enjoy!

## Intro - From Illustration To Realtime Rendering

To begin this project, I first chose an illustrator whose style I would replicate.

From [Wikipedia](https://en.wikipedia.org/wiki/Hiroshi_Nagai): 

> Hiroshi Nagai (Japanese: 永井博, born December 22, 1947) is a Japanese graphic designer and illustrator, known for his cover designs of city pop albums in the 1980s, which established the recognizable visual aesthetic associated with the loosely defined music genre.

I chose Hiroshi Nagai because I though that his style's consistent set of rules would be a strong candidate for adaptation to a custom surface shader/shading library, and because I personally like the subject matter :)

In particular, I chose this piece, commonly referred to as "Proud Funk", as the basis for a demo scene to build my shaders around. It contains a variety of surfaces, natural and artificial, and lends itself well to a 3D space thanks to clear perspective and largely being divided up via cubes.

<img src="https://i.imgur.com/jmKQbmk.jpeg" width=50% height=50%>

The resulting scene looks like this! Follow along to see how I got there.

<img src="https://i.imgur.com/mEnR3A1.png" width=50% height=50%>

## Shading Model

To start, I set out on a search for a shading model that best replicated Nagai's lighting and shadows. Unity's standard surface shader, even with a custom lighting function, added far too many steps to the shading process (such as BDRF, a fresnel, etc.) that deviated from the style I wanted and could not be disabled, and as such was not suitable.

A standard Lambert vert/frag implementation gave more control, but the shading falloff was too gradual and did not approximate the physicality and textural roughness found in Nagai's illustrations (almost as if all his surfaces were made of fine sandstone).

Thanks to [a blog post by Jordan Stevens](https://www.jordanstevenstechart.com/lighting-models), I found a Unity Shaderlab implementation of the Oren-Nayar shading model that I could use as a starting point. An older but more obscure shading model, Oren-Nayar was designed intentionally to mimic a variety of rough surfaces via calculations much simpler than a modern BDRF.

Lambert shading:
!["Lambert"](https://static.wixstatic.com/media/93f407_557668ae628644938aeec26d0f198112~mv2.png/v1/fill/w_406,h_313,al_c,q_85,usm_0.66_1.00_0.01,enc_auto/93f407_557668ae628644938aeec26d0f198112~mv2.png "Lambert")

Oren-Nayar shading:
!["Oren-Nayar"](https://static.wixstatic.com/media/93f407_91554c8cb64448c49191e1f3a72b08b1~mv2.png/v1/fill/w_406,h_313,al_c,q_85,usm_0.66_1.00_0.01,enc_auto/93f407_91554c8cb64448c49191e1f3a72b08b1~mv2.png "Oren-Nayar")

## Shadows

Oren-Nayar shading was a solid basis; the next area that needed attention were the shadows. Internally, Unity uses a screenspace shadow texture (shadowmap) to store shadows cast from objects and apply them to objects that receive them. Unfortunately for us, this system doesn't lend itself particularly well to Nagai's clean-cut shadows; shadowmaps have a finite resolution, and so one often encounters issues like shadow acne (visible aliasing in the shadows). There are several mitigation methods (bias, increased shadowmap resolution), but none of them are perfect and some have additional cost. Shadowmaps are also very much intended to be used for soft shadows, whose blur helps hide some of these imperfections; since we want our shadows to be harder but want to avoid acne/hard aliasing, we have to compromise.

To best mimic the harsh, long shadows of Nagai's work, inspired by the summer sun, I decided to use a hard "step" cutoff for shadowing slightly below the threshold where acne/aliasing appears. With this method, something is either in shadow, or it isn't. This still has _some_ artifacting and shadow acne (and can cause innacuracies with smaller cast shadows, as you'll see on shadows from a chair next to the picnic table below - still working on mitigating this), but generates a much more convicing "half-toon" shadow.

Let's use a complex naturalistic rock surface as an example.

Before... (notice the rough shadow acne)

<img src="https://i.imgur.com/gabuMov.png" width=50% height=50%>

...and after!

<img src="https://i.imgur.com/ikvBnwh.png" width=50% height=50%>

## Triplanar Mapping

To emphasize Nagai's tactile roughness even more, I apply a noise texture to all surface materials using triplanar mapping, with a simple multiplicative blend.

<img src="https://i.imgur.com/FSKQI9K.png" width=50% height=50%>

## Using (And Abusing) The Specular Component for Toon Highlights

In other Nagai pieces featuring cars, their bumpers often have a shiny chrome highlight. To recreate this, I added a slightly modified Blinn-Phong highlight on top of the Oren-Nayar shading, which can be ramped up or down like normal shininess in a surface shader. I added some additional range/choke controls, however, because of the following scenario.

Note in the base Proud Funk illustration how Nagai shades his palm trees - along the surface of their bark, there are small highlights in the form of paint daubs where the sun is hitting the bark, in a sort of stylized self-shadowing! This technique proved hard to visually recreate with a normal map alone, but I was able to recreate the effect by using a step cutoff similar to the shadows - except this time, applying it to the specular highlight component, along with a high choke value to blow it out. I then factor in the normal maps when calculating the highlight. While blowing out the specular to insane intensity is sort of abusing it, it does result in an effect accurate to the style of the illustration.

<img src="https://i.imgur.com/hMk2Duu.png" width=50% height=50%>

There's much more room for improvement with the specular highlight implementation in general (I'm not entirely satisfied with the crude Blinn-Phong method, but I want to avoid full BDRF territory if I can); however, I considered this one good enough to show!

## Per-Material Color Outlines Using Custom Depthnormals And Shader Replacement

Disclaimer: This technique relies upon a bit of built-in pipeline trickery that I have yet to attempt in URP.

If you're unfamiliar, depthnormals are a technique of storing both depth and normal information per-pixel in a single screenspace texture, rather than two. This is done via compressing the data, and does sacrifice resolution in the process, particularly depth. This makes a depthnormals texture a poor fit for, for example, an opaque water effect or screenspace fog - the low resolution of the depth value will cause visible banding. This depth value is good enough, however, for an outline effect.

Unity's depthnormals pass in built-in is done via shader replacement, meaning that a custom shader can be written and used in its stead. Essentially, what this means is that every material that is included in the depthnormals pass will call an appropriate block of shader code within that custom depthnormals shader. It will call the block with a matching RenderType tag - that code defines how it will write its fragment to the internal depthnormals render texture.

Since we know this, we can include identical Shaderlab variables mapped to Inspector-facing Material Properties inside the depthnormals shader block for each RenderTag! This means that not only can our depthnormals shader take in values from the material set in the Inspector, it can do so on a per-material basis! Materials we don't want to outline can even be excluded without causing draw order issues - we can have our cake and eat it too.

Sound confusing? Peek at the code and you'll see what I mean. :)

Here's a look at the raw outlines that I generate using this method - the actual outlining algorithm is a simplified Roberts Cross, used for cost-efficiency. The blending back onto the camera's rendertarget is a simple subtractive blend - it generates a colored outline based on what is below it.

<img src="https://i.imgur.com/x7ct3it.png" width=50% height=50%>

Here's the final product!

<img src="https://i.imgur.com/XW1JO6h.png" width=50% height=50%>

Rather than doing all of this via the Unity Built-In PostProcessing V2 stack, I blit it to the camera's rendertarget myself using CommandBuffers and temporary RenderTextures (hence the need for OutlineCamera.cs). I found this saved significantly on performance overhead (~1.25ms).

## Conclusion

These are the core building blocks that I used to construct the Nagai art style real-time in Unity! There are more specific tricks - the sparkles on the water, the wine glass, etc. - that you can take a look at by diving into the codebase for yourself. I hope this helps folks who are looking into getting into stylized Unity rendering - despite its reputation for simplicity, Unity does sneak in a lot of things under the surface that can make achieving your specific look hard!

If you want to learn more on the topic, I highly recommend [Catlike Coding](https://catlikecoding.com/unity/tutorials/); it's the gold standard of the Unity built-in renderer for a reason, and their SRP tutorials are improving all the time.

If you have questions about the code in this repo, you can reach me at my personal email via maxkrieger.contact@gmail.com.
