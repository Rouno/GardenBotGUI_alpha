CameraControlManager cameraControls;
CableBot myCableBot; //used to simulate bot when serial not available
CableBot simulatedBot;
CableBot botUsedForUI; //is just a reference on myCableBot or simulatedBot
Calibrator myCalibrator;

static int T0;
static final int NB_ACTUATORS = 4;
static final float POSITION_TO_FLOAT_mm = 0.075;
static final float WINCH_PROTO_HEIGHT_mm = 480;
//static final float MOUNT_LENGTH_in_mm = 80.0;

PVector[] botCoords = {new PVector(1000,-1000,WINCH_PROTO_HEIGHT_mm), new PVector(-1000,-1000,WINCH_PROTO_HEIGHT_mm), new PVector(-1000,1000,WINCH_PROTO_HEIGHT_mm),
new PVector(1000,1000,WINCH_PROTO_HEIGHT_mm)};

static int TEXT_SIZE; //size of text used

enum State {
  ZEROING, COMPLIANT, CALIBRATION, OPERATION
};

void setup(){
  //setup() should always start with serial init to determine if we need to simulate cablebot or not
  try{
    SerialBridge.myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
    SerialBridge.myPort.bufferUntil(SerialBridge.NEW_LINE);
  }catch (Exception e) {
    println("Serial port initialization failed");
  } 
  
  simulatedBot = new CableBot(botCoords);
  myCableBot = new CableBot(simulatedBot.winch);
  myCableBot.setPresentLengthFromLengths(simulatedBot.winch);
  myCalibrator = new Calibrator(myCableBot);
  
  size(800, 600, P3D);
  TEXT_SIZE = height/20;
  rectMode(CENTER);
  colorMode(HSB,100);
  cameraControls = new CameraControlManager((PGraphicsOpenGL) this.g);
  
  
}

void draw(){
  background(0);
  T0 = millis();
  UI.updateUserInputs(cameraControls,simulatedBot,mousePressed);
  
  //used only in simulation mode
  simulatedBot.drawBot();
  myCableBot.setPresentLengthFromLengths(simulatedBot.winch);
  
  //used in regular mode
  myCableBot.drawBot();
  drawInfo(UI.stateName);
  UI.updateBotOutput(myCableBot, myCalibrator);
  SerialBridge.sendDataToMicrocontroller(simulatedBot.buildFrame());
}

void serialEvent(Serial myPort) {
  SerialBridge.serialCallBack(simulatedBot, myPort);
}

void mousePressed() {
  UI.mousePressedCallback(cameraControls,simulatedBot);
}

void mouseReleased() {
  UI.mouseReleasedCallback(cameraControls,simulatedBot);
}

void mouseWheel(MouseEvent event) {
  UI.mouseWheelCallback(cameraControls,simulatedBot,event.getCount());
}

void keyPressed() {
  UI.keyPressedCallback();
}
