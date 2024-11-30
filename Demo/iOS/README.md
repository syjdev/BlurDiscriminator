<div align = "center">
  <img src="https://img.shields.io/badge/iOS-13.0-0099FF?style=flat" />
  <img src="https://img.shields.io/badge/Swift-5-fb4e22?style=flat" />
  <img src="https://img.shields.io/badge/TFLite-2.4.2-BF53FF?style=flat" />
</div>

# Intro

 __Demo/iOS__  is structured as follows.

<img src="https://user-images.githubusercontent.com/17686601/140548368-8d4437fe-861f-46d4-bbea-eed3f4d8365e.png" width="70%"/>

- __Demo__<br />
: Simple iOS Demo Project.

<div class="images-container">
  <img src="https://user-images.githubusercontent.com/17686601/140615200-7863ae9f-bcd7-433f-ab3a-317af9bdd530.jpg" width="35%"/>
  <img src="https://user-images.githubusercontent.com/17686601/140615206-3cb485d0-ee1c-41d7-9b27-15279cb0c612.jpg" width="35%"/>
</div>
<br />

- __BlurDiscriminatorKit__<br />
: Deep-Learning Based Framework. For inference image, use a TFLite(libtensorflow-lite.a, static library).

<br/>

# Usage

- __build BlurDiscriminatorKit.xcframework__
1) in `./BlurDiscriminatorKit`, execute `sh build_blurDiscriminator.sh` in terminal.
2) after building BlurDiscriminatorKit.xcframework, BlurDiscriminatorKit.xcframework will be generated in `./BlurDiscriminatorKit/built_xcframework`

<br/>
<br/>

- __add BlurDiscriminatorKit.xcframework in Xcode Project.__

1) add BlurDiscriminatorKit.xcframework in `Embed Frameworks` and TFLite model.

<img src="https://user-images.githubusercontent.com/17686601/144717621-8c6fdde5-5291-4225-a51c-78d3be0da8b9.png" width="70%"/><br />

2) When you initialize a BlurDiscriminator, You have to pass the path that specify model location. In my case, I locate the model in App main bundle.

<img src="https://user-images.githubusercontent.com/17686601/144718182-e8fb1ca8-0377-4967-af8c-4f0d0113226f.png" width="70%"/><br />

You can download a model, [model directory](https://github.com/syjdev/BlurDiscriminator/tree/master/model).
