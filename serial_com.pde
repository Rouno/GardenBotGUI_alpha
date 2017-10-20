import processing.serial.*;

Serial myPort;      // The serial port
int serialDataSize = 1;
int[] serialInArray = new int[serialDataSize];    // Where we'll put what we receive
String rxBuffer = "";
int serialCount = 0;                 // A count of how many bytes we receive
boolean firstContact = false;        // Whether we've heard from the microcontroller
static int CARRIAGE_RETURN = 13;
static int NEW_LINE = 10;

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
}

void serialEvent(Serial myPort) {
  int inByte = myPort.read();
  if(inByte == CARRIAGE_RETURN){
    myPort.clear();
    //do the packet process function here
    return;
  }
  
  if (inByte  == NEW_LINE) {
    rxBuffer = "";
  } else {
    rxBuffer += (char) inByte;
  }
}

void drawSerialData() {
  int n = serialInArray.length;
  //for(int i=0;i<n;i++){
    println(char(serialInArray[1]));
    text("last data received: ", +char(serialInArray[1]), 10, 130+10);
  //}
}