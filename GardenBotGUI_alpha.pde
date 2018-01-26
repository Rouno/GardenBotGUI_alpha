GardenBot myGardenBot; // GardenBot object //<>//
Calibrator myCalibrator; //store all calibration data sets, length and pod poses
CameraControlManager myCameraControls;

enum State {
  COMPLIANT, CALIBRATION, OPERATION
};
State status;

final float h = 480; //height of pillars in mm
final float GRID_SIZE = 5000; //GRID_SIZE 1px = 1mm
final float GRID_RES = 100; //resoltion in between grid lines in mm
int nbPillars = 4;
PVector[] pillars=new PVector[nbPillars];
float[] errorFactors = new float[nbPillars];
boolean isBotSimulated = false;

final int TEXT_SIZE = 30; //size of text used

void setup() {
  //init serial port
  println("Initializaing serial port");
  try {
    setupSerial();
    println("Waiting for data from microcontroller");
    delay(100);
  }
  catch (Exception e) {
    println("Serial port initialization failed, forcing simulation mode");
    isBotSimulated = true;
  } 
  setState(State.COMPLIANT);

  size(800, 600, P3D);
  rectMode(CENTER);

  //camera initialization
  myCameraControls = new CameraControlManager((PGraphicsOpenGL) this.g, 1500);

  File f = new File(sketchPath("calibration.txt"));
  if (f.exists()) {
    setState(State.OPERATION);
    nbPillars = getNbPillarsFromFile(sketchPath("calibration.txt"));
    pillars=new PVector[nbPillars];
    errorFactors = new float[nbPillars];
    loadCalibFromFile("calibration.txt", nbPillars, pillars, errorFactors);
  } else {
    setState(State.CALIBRATION);
    PVector[] pillars=new PVector[nbPillars];
    pillars = randomVect(nbPillars, h, 1500, 0.5) ; 
    alignAccordingToFstEdge(pillars);
  }
  //simulated bot init
  if (isBotSimulated) {
    myGardenBot = new GardenBot(pillars, h);
    myCalibrator = new Calibrator(myGardenBot.returnCableLengths(myGardenBot.currentPodPosition), h);
  }

}

void draw() {

  myCameraControls.updateMouse();
  if (mousePressed) {
    if (myGardenBot!= null && myGardenBot.podGrabbed) {
      myGardenBot.moveTargetPodPosition(myCameraControls.mouseOnGroundPlane);
    } else {
      myCameraControls.updateOrbitAngle();
    }
  }
  myCameraControls.updateCamera();

  //drawing part
  background(0);
  drawGrid();
  if (myGardenBot!=null) {
    myGardenBot.drawBot(); //draw pillars, pod, cables, pod grabber and axis
  }

  String message="";

  switch (status) {
  case COMPLIANT :
    message = "press ENTER to start calibration";
    showData(getCableLength_in_mm(incomingSerialData));
    break;
  case CALIBRATION :
    message = "press ENTER to end calibration \n or SPACE to reset";
    if (isBotSimulated) {
      myGardenBot.testSetCurrentPodPos();
      myCalibrator.processData(myGardenBot.returnCableLengths(myGardenBot.currentPodPosition)); //draw samples poses
    } else {
      try {
        myCalibrator.processData(getCableLength_in_mm(incomingSerialData));
      }   
      catch (Exception e) {
        println("Serial port failed despite serial initialization, try to reboot micro-controller");
      }
    }
    myCalibrator.drawCalibration();
    showCalibInfo();
    break;
  case OPERATION :
    if (myGardenBot == null) myGardenBot = new GardenBot(pillars, h, errorFactors);
    message = "system running, drag the white box & UP DOWN to operate, ENTER to save";
    if (isBotSimulated) {
      myGardenBot.testSetCurrentPodPos();
    } else {
      myGardenBot.setCurrentPodPosition(getCableLength_in_mm(incomingSerialData), myGardenBot.errorFactorArray);
      sendDataToMicrocontroller(myGardenBot.getTargetPosSpeedLoad());
      showData(concat(myGardenBot.getTargetPosSpeedLoad(),getCableLength_in_mm(incomingSerialData)));
    }
    break;
  }
  textSize(TEXT_SIZE);
  textAlign(CENTER);
  text(message, 0, height);
}


void keyPressed() {

  switch (status) {
  case COMPLIANT :
    if (keyCode == ENTER) {
      setState(State.CALIBRATION);
      if (myCalibrator == null) { 
        myCalibrator = new Calibrator(getCableLength_in_mm(incomingSerialData), h);
        setState(State.CALIBRATION);
      }
    }
    break;

  case CALIBRATION :
    if (key == ' ') {
      if (myGardenBot == null) { 
        myCalibrator.reset(getCableLength_in_mm(incomingSerialData));
      } else {
        myCalibrator.reset(myGardenBot.returnCableLengths(myGardenBot.currentPodPosition));
      }
    }
    if (keyCode == ENTER) {
      setState(State.OPERATION);
      pillars=myCalibrator.pillarsToCalibrate;
      errorFactors=myCalibrator.errorFactorArray;
    }
    if (keyCode == UP) {
      myGardenBot.mouvePodUp();
    }
    if (keyCode == DOWN) {
      myGardenBot.movePodDown();
    }
    break;

  case OPERATION :
    if(keyCode == ENTER){
      saveDataInFile(sketchPath("calibration.txt"));
    };
    if (keyCode == UP) {
      myGardenBot.mouvePodUp();
    }
    if (keyCode == DOWN) {
      myGardenBot.movePodDown();
    }
    break;
  }
}

void mousePressed() {
  myCameraControls.lastMouseClickedXY = myCameraControls.mouseXY.copy();

  //update grab state if pod is grabbed by user
  if (myGardenBot!=null && myGardenBot.isMouseOverGrabber()) {
    myGardenBot.podGrabbed =true;
  }
}

void mouseReleased() {
  //handle camera orbit resume after mouse release
  if (myGardenBot!=null && myGardenBot.podGrabbed) {
    myGardenBot.podGrabbed = false;
  } else {
    myCameraControls.updateLastMouseReleased();
  }
}

void mouseWheel(MouseEvent event) {
  myCameraControls.orbitRadius += event.getCount();
}

void drawGrid() {
  stroke(50);
  for (int i=-(int)GRID_SIZE/2; i<(int)GRID_SIZE/2; i+=GRID_RES) {
    line(i, GRID_SIZE/2, i, -GRID_SIZE/2);
    line(GRID_SIZE/2, i, -GRID_SIZE/2, i);
  }
}

void showCalibInfo() {
  pushMatrix();
  textAlign(LEFT);
  fill(0, 255, 0);
  textSize(TEXT_SIZE/2);
  camera();
  text("Cost Criteria : " + myCalibrator.cost, 0, TEXT_SIZE/2);
  fill(100, 255, 100);
  for (int i= 0; i<nbPillars; i++) {
    text("err factor "+i+" is : "+myCalibrator.errorFactorEstimationArray[i], 0, TEXT_SIZE/2*(i+2));
  }
  popMatrix();
}

void showData(float[] data) {
  pushMatrix();
  textAlign(LEFT);
  fill(0, 255, 0);
  textSize(TEXT_SIZE/2);
  camera();
  for (int i=0; i<data.length; i++) {
    text(" " + data[i], 0, TEXT_SIZE/2 * (1+i));
  }
  popMatrix();
}

void saveDataInFile(String pathToFile) {
  PrintWriter calibrationOutput;
  calibrationOutput = createWriter(pathToFile);
  calibrationOutput.println(myCalibrator.pillarsToCalibrate.length);
  for (int i=0; i<myCalibrator.pillarsToCalibrate.length; i++) {
    calibrationOutput.println(myCalibrator.pillarsToCalibrate[i].x+" "+myCalibrator.pillarsToCalibrate[i].y+" "+myCalibrator.pillarsToCalibrate[i].z);
  }

  for (int i=0; i<myCalibrator.pillarsToCalibrate.length; i++) {
    calibrationOutput.println(myCalibrator.errorFactorEstimationArray[i]);
  }

  calibrationOutput.flush(); // Writes the remaining data to the file
  calibrationOutput.close(); // Finishes the file
}

int getNbPillarsFromFile(String filePath) {
  try {
    BufferedReader reader;
    reader= createReader(filePath);
    String line = reader.readLine();
    return int(line);
  }
  catch(IOException e) {
    e.printStackTrace();
    return 0;
  }
}

void loadCalibFromFile(String filePath, int nbWinch, PVector[] winchCoord, float[] errFact) {
  try {
    BufferedReader reader;
    reader= createReader(filePath);
    String line = reader.readLine();
    for (int i=0; i<nbWinch; i++) {
      line = reader.readLine();
      String[] pieces = split(line, " ");
      winchCoord[i] = new PVector(float(pieces[0]), float(pieces[1]), float(pieces[2]));
    }
    for (int i=0; i<nbWinch; i++) {
      line = reader.readLine();
      errFact[i] = float(line);
    }
  }
  catch(IOException e) {
    e.printStackTrace();
  }
}