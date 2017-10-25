import processing.serial.*;

Serial myPort;      // The serial port

String rxBuffer = "";
boolean firstContact = false;        // Whether we've heard from the microcontroller
static float SERVO_TO_CABLE_RATIO = 0.00345528;
static int CARRIAGE_RETURN = 13;
static int NEW_LINE = 10;

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
}

void serialEvent(Serial myPort) {
  int inByte = myPort.read();
  
  if (inByte  == NEW_LINE) {
    myPort.clear();
    //println(rxBuffer);
    String[] receivedTokens = splitTokens(rxBuffer," ");
    float cable_length = 13.0 + SERVO_TO_CABLE_RATIO * float(receivedTokens[3]);
    println(cable_length);
    rxBuffer = "";
  } else {
    rxBuffer += (char) inByte;
  }
}