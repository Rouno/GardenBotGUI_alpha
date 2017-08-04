Button aButton; //GUI test button
GardenBot myGardenBot; // GardenBot object
CalibrationData myCalibrationData; //store all calibration data sets, length and pod poses

PVector mouseXY = new PVector(0,0);   //used to store mouse coordinate in 2D vector
PVector lastMouseClickedXY = new PVector(0,0); //mouse coordinates when clicked for the last time 
PVector lastMouseReleaseXY = new PVector(1400,400); //mouse coordinates when released for the last time
PVector mouseOnGroundPlane = new PVector(0,0); //used to store 2D mouse projection on (x,y,0) plane
float h = 200; //height in z of robot pod, controlled with up & down keys

void setup(){
  size(800, 600, P3D);
  rectMode(CENTER);
  //camera initialization
  camera_init();
  
  //button init
  aButton = new Button(90/2 + width/2, 90/2 + height/2, 90);
  
  //bot init
  PVector[] pillars = new PVector[0]; //length of pillars must be >= 4
  pillars = (PVector[]) append(pillars,new PVector(width/3,height/3,h));
  pillars = (PVector[]) append(pillars,new PVector(-width/3,height/2,h));
  pillars = (PVector[]) append(pillars,new PVector(-width/2,-height/2,h));
  pillars = (PVector[]) append(pillars,new PVector(width/2,-height/2,h));
  pillars = (PVector[]) append(pillars,new PVector(width/2,height/4,h));
  alignAccordingToFstEdge(pillars);
  myGardenBot = new GardenBot(pillars,255); //255 is the color of the main gardenBot

  //calibration initialization
  float[] initialLengthSet = myGardenBot.returnLinksMeasurements();
  myCalibrationData = new CalibrationData(initialLengthSet,myGardenBot.pod, h);
}

void draw(){
  mouseXY.set(mouseX,mouseY); //store current mouse coordinates in a vector 
  mouseOnGroundPlane.set(worldCoords(mouseXY.x, mouseXY.y, 0)); //get 3D coordinates on ground plane which correspond to the 2D position of the mouse on the screen

  //perform mouse orbiting motion if mousePressed and pod not grabbed by user
  if(mousePressed && !myGardenBot.podGrabbed){
    camera_orbit();
  }
  
  //add sample to dataSet and make an optimization step
  myCalibrationData.addSample(myGardenBot.returnLinksMeasurements(),myGardenBot.pod);
  myCalibrationData.optimizationStep();

  //drawing part
  background(0);
  aButton.drawButton();  //draw button
  myGardenBot.drawBot(); //draw pillars, pod, cables, pod grabber and axis
  myCalibrationData.drawData(); //draw samples poses

}


void keyPressed(){
  if(keyCode == UP){
    h+=10;
  }
  if(keyCode == DOWN){
    h-=10;
  }
}

void mousePressed(){
  lastMouseClickedXY = mouseXY.copy();
  
  //update button state
  aButton.stateUpdate();
  
  //update grab state if pod is grabbed by user
  myGardenBot.grabingUpdate();
}

void mouseReleased(){
  //handle camera orbit resume after mouse release
  if(!myGardenBot.podGrabbed){
    lastMouseReleaseXY.sub(lastMouseClickedXY).add(mouseXY); 
  }
}


//overRect is true if cursor on a 2D rectangle that lies on ground plane
boolean overRect(float x, float y, float width, float height)  {
  if (mouseOnGroundPlane.x >= x-width/2 && mouseOnGroundPlane.x <= x+width/2 && 
      mouseOnGroundPlane.y >= y-height/2 && mouseOnGroundPlane.y <= y+height/2) {
    return true;
  } else {
    return false;
  }
}