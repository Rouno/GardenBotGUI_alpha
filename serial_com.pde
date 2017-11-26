/* So far microcontroller returns periodically cable motor positions,
 * Microcontroler code is like 
 * USBprintf("Actuator: %u Position: %u ",actuator_ids[i],read_position_speed_load_data[num_addr*i]);
 * inside a for loop where i is the index number of a motor
 * so far there are 4 words in serial in data
 */

import processing.serial.*;
static Serial myPort;      // The serial port

static String txBuffer ="";
static String rxBuffer = "";
String[] incomingSerialData;
boolean firstContact = true;        // Whether we've heard from the microcontroller
static final int NB_WORD_SERIAL_IN = 4;
static final int NEW_LINE = 10;

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
}

void serialEvent(Serial myPort) {
  int inByte = myPort.read();
  
  if (inByte  == NEW_LINE) {
    if(!firstContact){
      myPort.clear();
      incomingSerialData = splitTokens(rxBuffer," "); //<>//
    }else{
      myPort.clear();
      firstContact = false;
    }
    rxBuffer = "";
  } else {
    rxBuffer += (char) inByte;
  }
}

void sendDataToMicrocontroller(float[] src){
  float speedi = 100; //speed in mm/s
  float loadi = 100; //load
  for(int i = 0; i<src.length; i++){
    txBuffer += src[i] + " " + speedi + " " + loadi + " ";
  }
  myPort.write(txBuffer);
  txBuffer = "";
}

float[] getCableLength_in_mm(String[] srcTokens){
  float[] result = new float[srcTokens.length/NB_WORD_SERIAL_IN];
  for(int i = 0;i<result.length;i++){
    result[i] = float(srcTokens[NB_WORD_SERIAL_IN*i+3]);
  }
  return result;
}