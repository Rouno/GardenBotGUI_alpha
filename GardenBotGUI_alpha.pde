GardenBot myGardenBot; // GardenBot object //<>//
Calibrator myCalibrator; //store all calibration data sets, length and pod poses
CameraControlManager myCameraControls;

enum State {
  COMPLIANT, CALIBRATION, OPERATION
};
State status = State.COMPLIANT;

final float h = 480; //height of pillars in mm
final float GRID_SIZE = 5000; //GRID_SIZE 1px = 1mm
final float GRID_RES = 100; //resoltion in between grid lines in mm
final int nbPillars = 4;
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

  size(800, 600, P3D);
  rectMode(CENTER);

  //camera initialization
  myCameraControls = new CameraControlManager((PGraphicsOpenGL) this.g, 1500);

  //simulated bot init
  if (isBotSimulated) {
    status = State.CALIBRATION;
    PVector[] pillars = randomVect(nbPillars, h, 1000, 0.5) ; 
    alignAccordingToFstEdge(pillars);
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
    break;
  case OPERATION :
    message = "system running, drag the white box & UP DOWN to operate ";
    if (isBotSimulated) {
      myGardenBot.testSetCurrentPodPos();
    } else {
      try {
        myGardenBot.setCurrentPodPosition(getCableLength_in_mm(incomingSerialData));
        sendDataToMicrocontroller(myGardenBot.getTargetPosSpeedLoad());
      }   
      catch (Exception e) {
        println("Serial port failed despite serial initialization, try to reboot micro-controller");
      }
    }
    break;
  }
  textSize(TEXT_SIZE);
  textAlign(CENTER);
  text(message, 0, height);
  textAlign(LEFT);
  fill(0, 255, 0);
  text("\n\nCost Criteria : " + myCalibrator.cost, 0, height);
}


void keyPressed() {

  switch (status) {
  case COMPLIANT :
    if (keyCode == ENTER) {
      status = State.CALIBRATION;
      if (myCalibrator == null) { 
        myCalibrator = new Calibrator(getCableLength_in_mm(incomingSerialData), h);
        setControllerState(State.CALIBRATION);
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
      status = State.OPERATION;
      if (myGardenBot == null) myGardenBot = new GardenBot(myCalibrator.pillarsToCalibrate, h);
    }
    if (keyCode == UP) {
      myGardenBot.mouvePodUp();
    }
    if (keyCode == DOWN) {
      myGardenBot.movePodDown();
    }
    break;

  case OPERATION :
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