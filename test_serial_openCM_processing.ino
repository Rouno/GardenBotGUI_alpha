/* 
  code snippet used for actuators commands packet deserialization
  packet format muste respect :
  "Position_actuator1 Speed_actuator1 Load_actuator1 ...Position_actuatorN Speed_actuatorN Load_actuatorN \n"
  Position, Speed and Load are floats
*/

#include "USBprint.h"

#define NUM_ACTUATORS 4

char rx_buffer[1024];
const byte num_addr = 3, num_data = num_addr*NUM_ACTUATORS;
word write_position_speed_load_data[num_data], read_position_speed_load_data[num_data];

void setup() {
  SerialUSB.begin(); // Start serial communication at 9600 bps
}

void loop() {
  int i = 0;
  while (SerialUSB.available()) { // If data is available to read,
    char val = SerialUSB.read(); // read it and store it in val
    rx_buffer[i] = val;
    i++;
    if(!SerialUSB.available()){ 
      deserializeIdsPosSpeedLoad(rx_buffer, sizeof(rx_buffer), write_position_speed_load_data, sizeof(write_position_speed_load_data));
    }
  }
  
  delay(2000);
}

//packet must end with ' '+'\n'
void deserializeIdsPosSpeedLoad(char* src_buffer, int src_size, word* dest_buffer, int dest_size){
  int src_index = 0;
  int dest_index = 0;
  while(src_buffer[src_index] != '\n'){ 
    int nbChar = nbCharBeforeNextSpace(src_buffer, src_index);
    char extracted_string[nbChar];
    for(int i=0; i < nbChar ;i++){
      extracted_string[i] = src_buffer[src_index+i];
    }
    //USBprintf("%f \n", (float) atof(extracted_string));
    dest_buffer[dest_index] = (word) atof(extracted_string);
    USBprintf("%u \n", (word) atof(extracted_string));
    src_index += nbChar + 1; 
  }
}

int nbCharBeforeNextSpace(char* src_buffer, int index){
  int result = 0;
  while(src_buffer[index+result] != ' '){
    result += 1;
  }
  return result;
}



