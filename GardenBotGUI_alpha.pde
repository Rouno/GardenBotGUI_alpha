GardenBot myGardenBot; // GardenBot object
Calibrator myCalibrator; //store all calibration data sets, length and pod poses
CameraControlManager myCameraControls;

float h = 200; //height in z of robot pod, controlled with up & down keys
float grid_size = 5000; //gridsize 1px = 1mm
int nbPillars = 4;


boolean mouseWheelMove = false;

void setup(){
  size(800, 600, P3D);
  rectMode(CENTER);
  
  //camera initialization
  myCameraControls = new CameraControlManager((PGraphicsOpenGL) this.g, width);
  //camera_init();
  
  //bot init  
  PVector[] pillars = randomVect(nbPillars, h, width, 0.5) ; 
  alignAccordingToFstEdge(pillars);
  myGardenBot = new GardenBot(pillars, h); //255 is the color of the main gardenBot

  //calibration initialization
  float[] initialLengthSet = myGardenBot.returnLinksMeasurements(myGardenBot.pod);
  myCalibrator = new Calibrator(initialLengthSet,myGardenBot.pod, h);
}

void draw(){
  
  myCameraControls.update_mouse();
  if(mousePressed){
    if(myGardenBot.podGrabbed){
      myGardenBot.update_pod_location(myCameraControls.mouseOnGroundPlane);
    }else{
      myCameraControls.update_orbit_angle();
    }
  }
  myCameraControls.update_camera();
  
  //drawing part
  background(0);
  drawGrid();
  myGardenBot.drawBot(); //draw pillars, pod, cables, pod grabber and axis
  myCalibrator.updateCalibrator(myGardenBot.returnLinksMeasurements(myGardenBot.pod),myGardenBot.pod); //draw samples poses

}


void keyPressed(){
  if(keyCode == UP){
    myGardenBot.pod.z +=10;
  }
  if(keyCode == DOWN){
    myGardenBot.pod.z -=10;
  }
  if(key == ' '){
    myCalibrator.reset();
  }
}

void mousePressed(){
  myCameraControls.lastMouseClickedXY = myCameraControls.mouseXY.copy();
  
  //update button state
  myCalibrator.isRunning.stateUpdate();
  
  //update grab state if pod is grabbed by user
  if(myGardenBot.isMouseOverGrabber()){
    myGardenBot.podGrabbed =true;
  }
}

void mouseReleased(){
  //handle camera orbit resume after mouse release
  if(!myGardenBot.podGrabbed){
    myCameraControls.lastMouseReleaseXY.sub(myCameraControls.lastMouseClickedXY).add(myCameraControls.mouseXY); 
  }else{
    myGardenBot.podGrabbed = false;
  }
}

void mouseWheel(MouseEvent event) {
  int e=event.getCount();
  myCameraControls.orbitRadius += e;
}

void drawGrid(){
  float inBetween = 100;
  stroke(50);
  for(int i=-(int)grid_size/2;i<(int)grid_size/2;i+=inBetween){
    line(i,grid_size/2,i,-grid_size/2);
    line(grid_size/2,i,-grid_size/2,i);
  }
}