import processing.serial.*;

static class SerialBridge {
  
  static Serial myPort;      // The serial port
  static final int nb_data_per_actuator = 3;
  static final int num_data = NB_ACTUATORS * nb_data_per_actuator;
  static final int NEW_LINE = 10;
  static boolean goSendData = true;
  static boolean firstContact = true;

  static void sendDataToMicrocontroller(int[] src) {
    if(myPort != null && goSendData){
      String dataOut="";
      for (int i = 0; i<src.length; i++) {
        dataOut += src[i];
        dataOut += ' ';
      }
      if (dataOut.length()>64) { 
        println("no tx data sent, tx buffer > 64 bytes");
      } else {
        myPort.write(dataOut);
      }
      goSendData = false;
    }
  }
  
  static void serialCallBack(CableBot abot, Serial aport){
    if (SerialBridge.firstContact) {
      SerialBridge.firstContact = false;
      aport.clear();
      return;
    }
    if(!SerialBridge.goSendData){
      SerialBridge.goSendData = true;
    }
    String[] tokens = splitTokens(aport.readString(), " ");
    abot.receiveFrame(tokens);
    myPort.clear();
  }
  
}
