/* 
 * Set variables for camera control 
 */

PGraphicsOpenGL gl;
PMatrix3D S = new PMatrix3D(); //camera space to screen space matrix
PMatrix3D P = new PMatrix3D(); //projection of model to camera
PMatrix3D M = new PMatrix3D(); //projection of world to model
PMatrix3D Si = new PMatrix3D(); //screen to camera
PMatrix3D Pi = new PMatrix3D(); //camera to model
PMatrix3D Mi = new PMatrix3D(); //model to world



void camera_init(){
  //set the fixed camera to screen matrix
  S.set(width/2, 0, 0, width/2,
        0, -height/2, 0, height/2,
        0, 0, 0.5, 0.5,
        0, 0, 0, 1);
        
  //get inverse matrix
  Si.set(S);
  Si.invert();
  
  //get the graphics object which contains camera projection/model view
  gl = (PGraphicsOpenGL) this.g;
  
  //set camera position
  camera(0, 0, width, 0, 0, 0, 0, 1, 0);
  
  //get current camera projection and inverse
  P.set(gl.projection);
  Pi.set(P);
  Pi.invert();
}

//"lastMouseReleaseXY.x + mouseX - lastMouseClickedXYX" is used to preserve last cursor position while mouse was dragged 
void camera_orbit(float my_orbitRadius,PVector my_orbitAngle){
  float xpos = cos(radians(my_orbitAngle.x - width/2)/10)*my_orbitRadius;
  float ypos = sin(radians(my_orbitAngle.x - width/2)/10)*my_orbitRadius;
  float zpos = my_orbitRadius / width * my_orbitAngle.y;
  camera(xpos, ypos, zpos, 0, 0, 0, 0, 0, -1);
}


//project 2d mouse x y on 3D point belonging on h z-plane
float[] worldCoords(float x, float y, float h){
  //get the current model view matrix and inverse
  M.set(gl.modelview);
  Mi.set(M);
  Mi.invert();
  
  //inversion of 2D screen coordinates to 3D world coordinates with z-plane constraint
  PMatrix3D SPMi = new PMatrix3D();
  SPMi.set(Si);
  SPMi.preApply(Pi);
  SPMi.preApply(Mi);
  
  //solve for z needed to end up with world-z = h
  float z = ((SPMi.m20 - h*SPMi.m30)*x + (SPMi.m21 - h*SPMi.m31)*y + (SPMi.m23 - h*SPMi.m33)) / (h*SPMi.m32 - SPMi.m22);
  
  float[] mouse = {x, y, z, 1};
  float[] orig = new float[4];
  
  SPMi.mult(mouse, orig);
  
  for(int i = 0; i < 4; i++){
    orig[i] /= orig[3];
  }
  float[] result = {orig[0],orig[1],orig[2]};
  return result;
}