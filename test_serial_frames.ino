#include "DynamixelQ.h"
#include "USBprint.h"

// Specify IDs of Dynamixels
#define NUM_ACTUATORS 1
#define CW_Angle_Limit 6
#define CCW_Angle_Limit 8
#define TORQUE_LIMIT 34
#define GOAL_POSITION 30
#define GOAL_ACCEL 73


byte write_start_addr = DXL_GOAL_POSITION, read_start_addr = DXL_PRESENT_POSITION;
const byte num_addr = 3, num_data = num_addr*NUM_ACTUATORS;
word write_load_data[NUM_ACTUATORS],write_position_data[NUM_ACTUATORS], write_position_speed_load_data[num_data], read_position_speed_load_data[num_data];
  
static byte actuator_ids[NUM_ACTUATORS] = {
  1
};

word actuators_initial_position[NUM_ACTUATORS];

void setup()
{ 
  SerialUSB.begin(); // Start serial communication at 9600 bps
  pinMode(BOARD_LED_PIN, OUTPUT);  //toggleLED_Pin_Out
  SerialUSB.attachInterrupt(usbInterrupt);
  byte i, return_delay = 0;
  
  // Start communicating with actuators at 1 Mbps
  Dxl.begin(DXL_BAUD_1000000);
  delay(1000);
  USBprintf("\nInitializing... ");

  // Stop all actuators in case any are moving
  Dxl.stop();
  delay(1000);

  // Check if specified actuator_ids exist and are communicating
  for (i = 0; i < NUM_ACTUATORS; i++) {
    while (!Dxl.isID(actuator_ids[i])) {
      USBprintf("Actuator ID %u not found. Looking...\n", actuator_ids[i]);
      delay(2000);
    }
    USBprintf("Actuator ID %u found... ", actuator_ids[i]);
  }
  // Set DXL_RETURN_DELAY_TIME to 0 ms on actuator_ids
  Dxl.setReturnDelay(actuator_ids, NUM_ACTUATORS, return_delay);

  // Set multiturn mode and resolution divider
  Dxl.setMultiTurnMode(actuator_ids, NUM_ACTUATORS);
  Dxl.setResolutionDivider(actuator_ids, NUM_ACTUATORS, (uint16) 2);

  USBprintf("Initialized\n");
  
  for(int i=0;i<num_data;i++){ //reset write_position_speed_load_data data to 0
    write_position_speed_load_data[i]=0;
  }
}

void loop()
{
  SerialUSB.detachInterrupt();
  Dxl.syncWrite(actuator_ids, NUM_ACTUATORS, write_start_addr, write_position_speed_load_data, num_addr, num_data);
  Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
  SerialUSB.attachInterrupt(usbInterrupt);
  
  for(int i=0;i<num_data;i++){ 
    SerialUSB.print(read_position_speed_load_data[i]);
    SerialUSB.print(" ");
  }
  SerialUSB.print('\n');
}

void usbInterrupt(byte* buffer, byte nCount){
  
  for(int i=0;i<num_data;i++){ //reset write_position_speed_load_data data to 0
    write_position_speed_load_data[i]=0;
  }
  
  int dataInCount = 0;
  for(unsigned int i=0; i < nCount;i++){
    if((char) buffer[i] != ' ' && dataInCount<num_data){ //convert char array into corresponding 16bits int value
      write_position_speed_load_data[dataInCount] *= 10;
      write_position_speed_load_data[dataInCount] += (word) (buffer[i] - '0');
    }
    else{
      dataInCount+=1;
    }
  }
  
}































