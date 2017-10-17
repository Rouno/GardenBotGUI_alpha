import processing.serial.*;

Serial myPort;      // The serial port
int serialDataSize = 4;
int[] serialInArray = new int[4];    // Where we'll put what we receive
int serialCount = 0;                 // A count of how many bytes we receive
boolean firstContact = false;        // Whether we've heard from the microcontroller

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
}

void serialEvent(Serial myPort) {
  int inByte = myPort.read();
  
  if (firstContact == false) {
    if (inByte == 'A') { 
      myPort.clear();          // clear the serial port buffer
      firstContact = true;     // you've had first contact from the microcontroller
      //myPort.write('A');       // ask for more
    } 
  } else {
    // Add the latest byte from the serial port to array:
    serialInArray[serialCount] = inByte;
    serialCount++;
    
    if(serialCount == serialDataSize){
      serialCount = 0;
    }
  }
}

void drawSerialData() {
  int n = serialInArray.length;
  for(int i=0;i<n;i++){
    text("last data received: ", +serialInArray[i], 10, 130+i*10);
  }
}