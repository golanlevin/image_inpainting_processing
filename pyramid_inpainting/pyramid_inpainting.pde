// Simple program for pyramid-based image inpainting on the CPU
// Developed in Processing 3.5.3
// Golan Levin, July 2019

PImage inputImage; 
PGraphics mipmap[];
PGraphics upscaled[];
int nLevels;
int imageCounter;

/*
 From Chema Guerra:
 The pixel extrapolation algorithm works in 2 stages:
 1. The first stage (analysis) prepares the mean pyramid of the source 
 image by doing progressive 1:2 downscalings. Only the meaningful (not-a-hole) 
 pixels in each 2×2 packet are averaged down. If a 2×2 packet does not have 
 any meaningful pixels, a hole is passed to the next (lower) level.
 
 2. The second stage (synthesis) starts at the smallest level and goes up, 
 leaving meaningful pixels intact, while replacing holes by upscaled data 
 from the previous (lower) level.
 
 References: 
 http://chemaguerra.com/filling-of-missing-image-pixels/
 http://wwwvis.informatik.uni-stuttgart.de/~kraus/preprints/vmv06_strengert.pdf
 https://rosettacode.org/wiki/Bilinear_interpolation#Java
 key words: image inpainting; image completion
 
 Performance: 
 About 3ms for 256x256 pixel image, approx. 20% occluded,
 on MacBook Pro (Early 2013), 3GHz Intel Core i7.
 Sample images from Flickr CC.
 */


//===========================================================
void setup() {

  size(384, 512); 
  frameRate(5); 
  noSmooth(); 
  
  imageCounter = 0; 
  loadNextImage(); // loads data into inputImage

  int imgW = inputImage.width; 
  int imgH = inputImage.height;

  nLevels = 9;
  mipmap = new PGraphics[nLevels];
  for (int i=0; i<nLevels; i++) {
    int twopow = (int)pow(2, i); 
    mipmap[i] = createGraphics (imgW/twopow, imgH/twopow);
  }

  upscaled = new PGraphics[nLevels];
  for (int i=1; i<nLevels; i++) { // Caution: no 0'th element.
    int twopowm1 = (int)pow(2, i-1); 
    upscaled[i] = createGraphics (imgW/twopowm1, imgH/twopowm1);
  }
}


//===========================================================
void draw() {
  background(0);
  int maskColor = color(0, 255, 0); 

  //-------------------
  // Copy the first level, at the original scale.
  int srcW = inputImage.width; 
  int srcH = inputImage.height; 
  int dstW = mipmap[0].width;
  int dstH = mipmap[0].height; 
  
  mipmap[0].beginDraw();
  mipmap[0].loadPixels();
  arrayCopy(inputImage.pixels, mipmap[0].pixels);
  mipmap[0].updatePixels(); 
  mipmap[0].endDraw(); 

  //-------------------
  // Analysis: generate the subsequent mipmap levels
  int drawX = mipmap[0].width; 
  for (int level=1; level<nLevels; level++) { 
    mipmap[level].beginDraw();
    mipmap[level].loadPixels();
    PGraphics srcMipmap = mipmap[level-1];
    PGraphics dstMipmap = mipmap[level  ];

    srcW = srcMipmap.width; 
    srcH = srcMipmap.height; 
    dstW = dstMipmap.width;
    dstH = dstMipmap.height; 

    for (int dstX=0; dstX<dstW; dstX++) {
      for (int dstY=0; dstY<dstH; dstY++) {

        int srcX0 = dstX*2; 
        int srcY0 = dstY*2; 
        int srcX1 = dstX*2+1; 
        int srcY1 = dstY*2; 
        int srcX2 = dstX*2; 
        int srcY2 = dstY*2+1; 
        int srcX3 = dstX*2+1; 
        int srcY3 = dstY*2+1; 

        int srcIndex0 = srcY0*srcW + srcX0; 
        int srcIndex1 = srcY1*srcW + srcX1; 
        int srcIndex2 = srcY2*srcW + srcX2; 
        int srcIndex3 = srcY3*srcW + srcX3; 
        int srcColor0 = srcMipmap.pixels[srcIndex0];
        int srcColor1 = srcMipmap.pixels[srcIndex1];
        int srcColor2 = srcMipmap.pixels[srcIndex2];
        int srcColor3 = srcMipmap.pixels[srcIndex3];

        int count = 0;
        int r = 0; 
        int b = 0; 
        int g = 0;
        if (srcColor0 != maskColor) {
          r += (srcColor0 & 0x00FF0000)>>16;
          g += (srcColor0 & 0x0000FF00)>>8;
          b += (srcColor0 & 0x000000FF);
          count++;
        }
        if (srcColor1 != maskColor) {
          r += (srcColor1 & 0x00FF0000)>>16;
          g += (srcColor1 & 0x0000FF00)>>8;
          b += (srcColor1 & 0x000000FF);
          count++;
        }
        if (srcColor2 != maskColor) {
          r += (srcColor2 & 0x00FF0000)>>16;
          g += (srcColor2 & 0x0000FF00)>>8;
          b += (srcColor2 & 0x000000FF);
          count++;
        }
        if (srcColor3 != maskColor) {
          r += (srcColor3 & 0x00FF0000)>>16;
          g += (srcColor3 & 0x0000FF00)>>8;
          b += (srcColor3 & 0x000000FF);
          count++;
        }

        int dstColor = maskColor;
        if (count > 0) {
          dstColor = color(r/count, g/count, b/count);
        } 

        int dstIndex = dstY*dstW + dstX; 
        dstMipmap.pixels[dstIndex] = dstColor;
      }
    }
    mipmap[level].updatePixels(); 
    mipmap[level].endDraw();
  }

  //-------------------
  // Synthesis: Propagate the filled data down the pyramid. 
  for (int level=(nLevels-2); level>=0; level--) {
    PGraphics filMipmap = mipmap[level]; // the one to fill
    PGraphics srcMipmap = mipmap[level+1];  // the next higher mipmap
    PGraphics dstMipmap = upscaled[level+1]; // the one to fill from: the next higher mipmap, upscaled

    filMipmap.beginDraw();
    filMipmap.loadPixels();
    dstMipmap.beginDraw();
    dstMipmap.loadPixels();

    int filW = filMipmap.width; 
    int filH = filMipmap.height;
    srcW = srcMipmap.width; 
    srcH = srcMipmap.height; 
    dstW = dstMipmap.width;
    dstH = dstMipmap.height;

    for (int filY=0; filY<filH; filY++) {
      for (int filX=0; filX<filW; filX++) {
        int filIndex = filY * filW + filX;

        // check if there are any mask pixels in the one to fill
        if (filMipmap.pixels[filIndex] == maskColor) {

          int dstX = filX; // upscaled image, and image-to-fill, 
          int dstY = filY; // have the same dimensions

          float gx = dstX/2.0; 
          float gy = dstY/2.0; 
          int gxi = (int) gx;
          int gyi = (int) gy;
          gxi = min(gxi, srcW-2); 
          gyi = min(gyi, srcH-2); 

          int c00 = srcMipmap.pixels[ (gxi  )+(gyi  )*srcW ];
          int c10 = srcMipmap.pixels[ (gxi+1)+(gyi  )*srcW ];
          int c01 = srcMipmap.pixels[ (gxi  )+(gyi+1)*srcW ];
          int c11 = srcMipmap.pixels[ (gxi+1)+(gyi+1)*srcW ];

          int dstColor = 0xFF000000;
          for (int i=0; i<3; ++i) {
            float b00 = getByte (c00, i);
            float b10 = getByte (c10, i);
            float b01 = getByte (c01, i);
            float b11 = getByte (c11, i);
            int ble = ((int) blerp(b00, b10, b01, b11, gx - gxi, gy - gyi)) << (8 * i);
            dstColor |= ble;
          }

          dstMipmap.pixels[filIndex] = dstColor;  
          filMipmap.pixels[filIndex] = dstMipmap.pixels[filIndex];
        }
      }
    }

    filMipmap.updatePixels(); 
    filMipmap.endDraw();
    dstMipmap.updatePixels(); 
    dstMipmap.endDraw();
  }
 

  //-------------------
  // Draw the results
  int mipY = inputImage.height; 
  image(inputImage, 0, 0);
  image(mipmap[0], 0, mipY);
  int mipX = mipmap[0].width;
  for (int i=1; i<nLevels; i++) {
    image(mipmap[i], mipX, mipY);
    mipY += mipmap[i].height;
  }
}


//===========================================================
void keyPressed() {
  // saveFrame("example.png"); 
  loadNextImage(); 
}

void mousePressed() {
  loadNextImage(); 
}


//===========================================================
int getByte(int col, int n) {
  return (col >> (n * 8)) & 0xFF;
}

float lerp2 (float s, float e, float t) {
  return s + (e - s) * t;
}

float blerp (final float c00, float c10, float c01, float c11, float tx, float ty) {
  return lerp2(lerp2(c00, c10, tx), lerp2(c01, c11, tx), ty);
}

void loadNextImage(){
  int nImagesInDataFolder = 25;
  String filename = "data/" + nf(imageCounter, 5) + ".png";  
  inputImage = loadImage(filename);
  
  imageCounter++; 
  if (imageCounter > nImagesInDataFolder){
    imageCounter = 0; 
  }
}
