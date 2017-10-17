GardenBot myGardenBot; // GardenBot object
Calibrator myCalibrator; //store all calibration data sets, length and pod poses

PVector mouseXY = new PVector(0,0);   //used to store mouse coordinate in 2D vector
PVector lastMouseClickedXY = new PVector(0,0); //mouse coordinates when clicked for the last time 
PVector lastMouseReleaseXY = new PVector(1400,400); //mouse coordinates when released for the last time
PVector mouseOnGroundPlane = new PVector(0,0); //used to store 2D mouse projection on (x,y,0) plane
float h = 200; //height in z of robot pod, controlled with up & down keys
float grid_size = 5000; //gridsize 1px = 1mm
int nbPillars = 4;

PVector orbitAngle = new PVector(0,0);
float orbitRadius, lastOrbitRadius;
boolean mouseWheelMove = false;

void setup(){
  size(800, 600, P3D);
  rectMode(CENTER);
  
  orbitRadius = width;
  lastOrbitRadius = orbitRadius;
  
  //camera initialization
  camera_init();
  
  //bot init  
  PVector[] pillars = randomVect(nbPillars, h, width, 0.5) ; 
  alignAccordingToFstEdge(pillars);
  myGardenBot = new GardenBot(pillars); //255 is the color of the main gardenBot

  //calibration initialization
  float[] initialLengthSet = myGardenBot.returnLinksMeasurements(myGardenBot.pod);
  myCalibrator = new Calibrator(initialLengthSet,myGardenBot.pod, h);
}

void draw(){
  mouseXY.set(mouseX,mouseY); //store current mouse coordinates in a vector 
  mouseOnGroundPlane.set(worldCoords(mouseXY.x, mouseXY.y, 0)); //get 3D coordinates on ground plane which correspond to the 2D position of the mouse on the screen

  //perform mouse orbiting motion if mousePressed and pod not grabbed by user
  if(orbitRadius != lastOrbitRadius) camera_orbit(orbitRadius, orbitAngle);
  
  //orbitAngle = lastMouseReleaseXY.copy().add(mouseXY).sub(lastMouseClickedXY);
  if(mousePressed && !myGardenBot.podGrabbed){
    orbitAngle = lastMouseReleaseXY.copy().add(mouseXY).sub(lastMouseClickedXY);
    camera_orbit(orbitRadius, orbitAngle);
  }
  
  //drawing part
  background(0);
  drawGrid();
  myGardenBot.drawBot(); //draw pillars, pod, cables, pod grabber and axis
  myCalibrator.updateCalibrator(myGardenBot.returnLinksMeasurements(myGardenBot.pod),myGardenBot.pod); //draw samples poses

}


void keyPressed(){
  if(keyCode == UP){
    h+=10;
  }
  if(keyCode == DOWN){
    h-=10;
  }
  if(key == ' '){
    myCalibrator.reset();
  }
}

void mousePressed(){
  lastMouseClickedXY = mouseXY.copy();
  
  //update button state
  myCalibrator.isRunning.stateUpdate();
  
  //update grab state if pod is grabbed by user
  myGardenBot.grabingUpdate();
}

void mouseReleased(){
  //handle camera orbit resume after mouse release
  if(!myGardenBot.podGrabbed){
    lastMouseReleaseXY.sub(lastMouseClickedXY).add(mouseXY); 
  }
}

void mouseWheel(MouseEvent event) {
  int e=event.getCount();
  orbitRadius += e;
}

void drawGrid(){
  float inBetween = 100;
  stroke(50);
  for(int i=-(int)grid_size/2;i<(int)grid_size/2;i+=inBetween){
    line(i,grid_size/2,i,-grid_size/2);
    line(grid_size/2,i,-grid_size/2,i);
  }
}