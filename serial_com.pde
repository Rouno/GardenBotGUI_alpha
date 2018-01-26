/* So far microcontroller returns periodically cable motor positions, //<>//
 * Microcontroler code is like 
 * USBprintf("Actuator: %u Position: %u ",actuator_ids[i],read_position_speed_load_data[num_addr*i]);
 * inside a for loop where i is the index number of a motor
 * so far there are 4 words in serial in data
 */

import processing.serial.*;
static Serial myPort;      // The serial port
final int serialOutPeriod = 1; //minimum time in between sending serial commands, in ms
boolean serialReadingEnabled = true;
int lastTimeSerialOut = millis();

String txBuffer ="";
String rxBuffer = "";
String[] incomingSerialData;
boolean firstContact = true;        // Whether we've heard from the microcontroller
static final int NB_WORD_SERIAL_IN = 3;
static final int NB_WORD_SERIAL_OUT = 3;
static final int NEW_LINE = 10;

void setupSerial() {
  myPort = new Serial(this, "/dev/tty.usbmodem1411", 57600);
  myPort.bufferUntil(NEW_LINE);
}

void serialEvent(Serial myPort) {
  if (serialReadingEnabled) {
    if (firstContact) {
      firstContact = false;
    } else {
      rxBuffer = myPort.readString();
      incomingSerialData = splitTokens(rxBuffer, " ");
    }
  }
  myPort.clear();
  rxBuffer = "";
}

void sendDataToMicrocontroller(float[] src) {
  if (millis() - lastTimeSerialOut >= serialOutPeriod) {
    lastTimeSerialOut = millis();
    txBuffer="G";
    for (int i = 0; i<src.length/NB_WORD_SERIAL_OUT; i++) {
      txBuffer += Integer.toString((int)src[i*NB_WORD_SERIAL_OUT]) + ' ' + Integer.toString((int)src[i*NB_WORD_SERIAL_OUT+1]) + ' ' + Integer.toString((int)src[i*NB_WORD_SERIAL_OUT+2]) + ' ';
    }
    txBuffer += '\n';
    myPort.write(txBuffer);
    txBuffer = "";
  }
}

void setState(State state) {
  status = state;
  switch (state) {
  case COMPLIANT:
    if (!isBotSimulated) {
      myPort.write('M');
    }
    break;
  case CALIBRATION:
    if (!isBotSimulated) {
      //myPort.write('C');
    }
    break;
  case OPERATION:
    if (!isBotSimulated) {
      myPort.write('O');
    }
    break;
  default :
    break;
  }
}

float[] getCableLength_in_mm(String[] srcTokens) {
  serialReadingEnabled = false;
  try {
    float[] result = new float[srcTokens.length/NB_WORD_SERIAL_IN];
    for (int i = 0; i<result.length; i++) {
      result[i] = float(
        srcTokens[NB_WORD_SERIAL_IN*i]);
    }
    serialReadingEnabled = true;
    return result;
  } 
  catch (Exception e) {
    println("Serial port failed despite serial initialization, try to reboot micro-controller");
    serialReadingEnabled = true;
    return null;
  }
}

int computeChecksum(String packet) {
  byte result = 0;
  for (int i=0; i<packet.length(); i++) {
    result += (byte) packet.charAt(i);
  }
  return result;
}