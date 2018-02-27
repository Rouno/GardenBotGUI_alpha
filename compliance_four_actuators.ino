#include "DynamixelQ.h"
#include "USBprint.h"

// Specify IDs of Dynamixels
#define NUM_ACTUATORS 4
#define CW_Angle_Limit 6
#define CCW_Angle_Limit 8
#define TORQUE_LIMIT 34
#define GOAL_POSITION 30
#define GOAL_ACCEL 73

//specify states of actuators
enum State {
  COMPLIANT, CALIBRATION, OPERATION};
State actuators_state = COMPLIANT;

#define POSITION_TO_LENGTH_in_mm_RATIO 0.075 //0.0375
#define MOUNT_LENGTH_in_mm 80.0

byte write_start_addr = DXL_GOAL_POSITION, read_start_addr = DXL_PRESENT_POSITION;
const byte num_addr = 3, num_data = num_addr*NUM_ACTUATORS;
word write_load_data[NUM_ACTUATORS],write_position_data[NUM_ACTUATORS], write_position_speed_load_data[num_data], read_position_speed_load_data[num_data];

boolean TX_enabled = true;
boolean RX_enabled = true;

int write_index=0;

word init_speed = 300;
word max_load = 250; //150 

static byte actuator_ids[NUM_ACTUATORS] = {
  1,2,3,4
};
word actuators_initial_position[NUM_ACTUATORS];

void setup()
{
  SerialUSB.begin(); // Start serial communication at 9600 bps
  //SerialUSB.attachInterrupt(usbInterrupt);
  pinMode(BOARD_LED_PIN, OUTPUT);  //toggleLED_Pin_Out
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

  // Set DXL_CW_ANGLE_LIMIT, DXL_CCW_ANGLE_LIMIT, and DXL_TORQUE_LIMIT on actuator_ids to specify joint mode
  Dxl.setMultiTurnMode(actuator_ids, NUM_ACTUATORS);
  Dxl.setResolutionDivider(actuator_ids, NUM_ACTUATORS, (uint16) 2);
  //Dxl.setGoalAcceleration(actuator_ids, NUM_ACTUATORS,(uint8) 0);    //0~254, max acceleration = 2180°/sec^2

    // Initialize DXL_MOVING_SPEED of ACTUATOR_IDS
  Dxl.setLoad((uint16) max_load);
  Dxl.setPosition(actuator_ids, NUM_ACTUATORS,(uint16) 0);
  Dxl.setSpeed(actuator_ids, NUM_ACTUATORS,(uint16) init_speed);

  USBprintf("Initialized, starting zeroing calibration\n");

  for (i = 0; i < NUM_ACTUATORS; i++){
    int read_speed = -1;
    do
    {
      Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
      read_speed = read_position_speed_load_data[num_addr*i+1];
      delay(500);
    }
    while (read_speed != 0);
    actuators_initial_position[i] = read_position_speed_load_data[num_addr*i];
    USBprintf("Multiturn offset for motor %u is %d \n", i, actuators_initial_position[i]);

    for(int j=0; j<num_addr; j++){
      write_position_speed_load_data[i*num_addr+j] = (word) 0;
    }
  }
  USBprintf("Zeroing calibration done\n");
}

void loop()
{
  const uint16 wSize = 256;
  uint8 bNum, bData[wSize];
  bNum = usbBytesAvailable();
  SerialUSB.read(bData, bNum);
  usbInterrupt(bData,bNum);
  Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
  sendDataToPC();


  //controlling torque for compliance
  switch (actuators_state) {
  case COMPLIANT :
    write_index = 0;
    for (int i = 0; i < NUM_ACTUATORS; i++) {
      if(write_load_data[i] < read_position_speed_load_data[i*num_addr+2]){
        write_load_data[i] -= 10;
        write_load_data[i] = max(write_load_data[i],0);
      }
      else{
        write_load_data[i] += 10;
        write_load_data[i] = min(write_load_data[i],max_load);
      }
    }
    //write torques to all actuators in actuators ids
    Dxl.setPosition(actuator_ids, NUM_ACTUATORS, actuators_initial_position);
    Dxl.setSpeed(actuator_ids, NUM_ACTUATORS,(uint16) init_speed);
    Dxl.setLoad(actuator_ids, NUM_ACTUATORS, write_load_data);
    break;

  case CALIBRATION :
    break;

  case OPERATION :
    //Dxl.syncWrite(actuator_ids, NUM_ACTUATORS, write_start_addr, write_position_speed_load_data, num_addr, num_data);
    break;  
  }

}

void sendDataToPC(){
  // Print ids, position in mm, speed and load data for each actuator in actuator_ids
  for (int i = 0; i < NUM_ACTUATORS; i++) {
    float cable_length_end_to_end = MOUNT_LENGTH_in_mm + POSITION_TO_LENGTH_in_mm_RATIO * (read_position_speed_load_data[num_addr*i]-actuators_initial_position[i]);
    USBprintf("%u %u %u ", (word) cable_length_end_to_end,read_position_speed_load_data[num_addr*i+1],read_position_speed_load_data[num_addr*i+2]);
  }
  USBprintf("\n");
}

void usbInterrupt(byte* buffer, byte nCount){
  if(nCount <= 2){
    if((char) buffer[0] == 'O'){
      actuators_state = OPERATION;
      //USBprintf("Operation mode \n");
    }
    else if((char) buffer[0] == 'M'){
      actuators_state = COMPLIANT;
      //USBprintf("Compliant mode \n");
    }
    else if((char) buffer[0] == 'C'){
      actuators_state = CALIBRATION;
      //USBprintf("Calibration mode \n");
    }
  }
  else {
    if((char) buffer[0] == 'G'){
      deserializeIdsPosSpeedLoad(buffer+1, write_position_speed_load_data, &write_index);
      write_index %= num_data;
    }
  }
}

//packet must end with ' '+'\n'
//packet format is (float index, float position (in mm), float speed (0 .. 1023), float load
void deserializeIdsPosSpeedLoad(byte* src_buffer, word* dest_buffer, int* dest_index){
  int src_index = 0;
  while(src_buffer[src_index] != '\n'){
    int nbChar = nbCharBeforeNextSpace(src_buffer, src_index);
    char extracted_string[nbChar+1];
    for(int i=0; i < nbChar ;i++){
      extracted_string[i] = src_buffer[src_index+i];
    }
    extracted_string[nbChar] = '\O';
    int actuator_id = *dest_index / num_addr;

    if(*dest_index % num_addr == 0){ //mean we need to convert float length to sservo pos
      double tmp_pos = atof(extracted_string);
      tmp_pos -= MOUNT_LENGTH_in_mm;
      tmp_pos /= POSITION_TO_LENGTH_in_mm_RATIO;
      tmp_pos += actuators_initial_position[actuator_id];
      dest_buffer[*dest_index] = (word) tmp_pos;
    }
    else{
      dest_buffer[*dest_index] = (word) atof(extracted_string);
    }
    *dest_index += 1;
    src_index += nbChar + 1;
  }
}

int nbCharBeforeNextSpace(byte* src_buffer, int index){
  int result = 0;
  while((char) src_buffer[index+result] != ' '){
    result += 1;
  }
  return result;
}





































