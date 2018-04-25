# Tiled-Directional-Flow

This project is a Unity version of the tiled directional flow project found [here](http://www.rug.nl/society-business/centre-for-information-technology/research/hpcv/publications/watershader/).

The idea behind this project is to provide a method to control the direction water flows based on a flow map. The flow map (also know as a velocity map) is simply a texture with the red and green components representing the flow direction normalized to a range of 0 - 1. The shader then divides space into a series of squares where the waters normal direction is determined by the flow map. This is done four times, each with a different offset and the results blended together to remove any seams.

Creating the flow map could be a bit of a hassle. It would be best done using a fluid simulation and some 3D modelling programs can do this for you. You could also paint it by hand in Photoshop but this could be quite hard.

At the moment the shader is just applied to a flat plane and viewed from above so the effect can be seen best. Moving this to a terrain shader would be relatively trivial if that is what you need.

You can download a unity package [here](https://app.box.com/s/up29uas60wpy1f9mf17amcs0tk7gyvtq).

![Tiled Directional Flow](https://static.wixstatic.com/media/1e04d5_aed597394e9741ba8f5e816f9f8fd3cd~mv2.jpg/v1/fill/w_550,h_509,al_c,q_80,usm_0.66_1.00_0.01/1e04d5_aed597394e9741ba8f5e816f9f8fd3cd~mv2.jpg)
