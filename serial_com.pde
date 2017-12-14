/* So far microcontroller returns periodically cable motor positions, //<>//
 * Microcontroler code is like 
 * USBprintf("Actuator: %u Position: %u ",actuator_ids[i],read_position_speed_load_data[num_addr*i]);
 * inside a for loop where i is the index number of a motor
 * so far there are 4 words in serial in data
 */

import processing.serial.*;
static Serial myPort;      // The serial port

String txBuffer ="";
String rxBuffer = "";
String[] incomingSerialData;
boolean firstContact = true;        // Whether we've heard from the microcontroller
static final int NB_WORD_SERIAL_IN = 4;
static final int NB_WORD_SERIAL_OUT = 4;
static final int NEW_LINE = 10;

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
}

void serialEvent(Serial myPort) {
  int inByte = myPort.read();

  if (inByte  == NEW_LINE) {
    if (!firstContact) {
      myPort.clear();
      incomingSerialData = splitTokens(rxBuffer, " ");
    } else {
      myPort.clear();
      firstContact = false;
    }
    rxBuffer = "";
  } else {
    rxBuffer += (char) inByte;
  }
}

void sendDataToMicrocontroller(float[] src) {
  for (int i = 0; i<src.length/NB_WORD_SERIAL_OUT; i++) {
    txBuffer += src[i] + ' ' + src[i+1] + ' ' + src[i+2] + ' ' + src[i+3] + ' ';
  }
  txBuffer += '\n';
  //myPort.write(txBuffer);
  txBuffer = "";
}

void setControllerState(State state) {
  switch (state) {
  case CALIBRATION:
    //myPort.write('C');
    break;
  default :
    break;
  }
}

float[] getCableLength_in_mm(String[] srcTokens) {
  float[] result = new float[srcTokens.length/NB_WORD_SERIAL_IN];
  for (int i = 0; i<result.length; i++) {
    result[i] = float(srcTokens[NB_WORD_SERIAL_IN*i+1]);
  }
  return result;
}