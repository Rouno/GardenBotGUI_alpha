/*
 *	two_actuators.ino
 *	
 *	Run Actuator IDs 1 and 2 at different speeds in joint mode. Read position and speed
 *	from each. Use USBprint to print read data and timing statistics to the USB serial
 *	port.
 *	
 *	Actuator IDs 1 and 2 must be MX Series actuators. Change the baud rate to
 *	DXL_BAUD_1000000 or less to handle AX Series actuators or mixed types.
 *	
 *	Author: Andrew D. Horchler, horchler @ gmail . com
 *	Created: 7-28-15, modified: 7-28-15
 */

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
enum {COMPLIANT, CALIBRATION, OPERATION};

#define POSITION_TO_LENGTH_in_mm_RATIO 0.03409753690161
#define MOUNT_LENGTH_in_mm 85.0

byte write_start_addr = DXL_GOAL_POSITION, read_start_addr = DXL_PRESENT_POSITION;
const byte num_addr = 3, num_data = num_addr*NUM_ACTUATORS;
word write_load_data[NUM_ACTUATORS], read_position_speed_load_data[num_data];


word max_load = 150;
word torque_load_avg = 50;
float curvature_factor = 0.03;  //0.05;

static byte actuator_ids[NUM_ACTUATORS] = {
	1,2,3,4
};

word actuators_initial_position[NUM_ACTUATORS];

void setup()
{
  word init_speed = 1023;
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
  Dxl.setLoad(actuator_ids, NUM_ACTUATORS, 100);
  //Dxl.setGoalAcceleration(actuator_ids, NUM_ACTUATORS,(uint8) 0);    //0~254, max acceleration = 2180°/sec^2
  
  // Initialize DXL_MOVING_SPEED of ACTUATOR_IDS
  Dxl.setPosition(actuator_ids, NUM_ACTUATORS,(uint16) 0);
  Dxl.setSpeed(actuator_ids, NUM_ACTUATORS,(uint8) init_speed);
  
  USBprintf("Initialized, starting zeroing calibration\n");
  
  for (i = 0; i < NUM_ACTUATORS; i++){
    int read_speed = -1;
    do
    {
      Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
      read_speed = read_position_speed_load_data[num_addr*i+1];
      delay(500);
    }while (read_speed != 0);
    word multiturn_offset = read_position_speed_load_data[num_addr*i];
    actuators_initial_position[i] = multiturn_offset;
    USBprintf("Multiturn offset for motor %u is %d \n", i, multiturn_offset);
  }
  
  USBprintf("Zeroing calibration done\n");
}

void loop()
{
  byte i;
  
  // Read present position, speed and load from all actuators in actuator_ids and store in array
  Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
  
  //controlling torque for compliance
  word torque, present_load;
  for (i = 0; i < NUM_ACTUATORS; i++) {
    present_load = read_position_speed_load_data[num_addr*i+2];
    if (present_load > 1023) present_load = 0;
    torque = (max_load - present_load);
    if(present_load < torque_load_avg) torque += (int)(curvature_factor * pow((present_load - torque_load_avg),2));
    write_load_data[i] = torque;
  }
  
  //write torques to all actuators in actuators ids
  Dxl.setLoad(actuator_ids, NUM_ACTUATORS, write_load_data);
    
  // Write goal position and moving speed to all actuators in actuator_ids
  //Dxl.syncWrite(actuator_ids, NUM_ACTUATORS, write_start_addr, write_position_speed_load_data, num_addr, num_data);
  
  // Print position in mm, speed and load data for each actuator in actuator_ids
  for (i = 0; i < NUM_ACTUATORS; i++) {
    float cable_length_end_to_end = MOUNT_LENGTH_in_mm + POSITION_TO_LENGTH_in_mm_RATIO * (read_position_speed_load_data[num_addr*i]-actuators_initial_position[i]);
    USBprintf("Actuator: %u Position: %f Speed: %u Load: %u ",
    actuator_ids[i],cable_length_end_to_end,read_position_speed_load_data[num_addr*i+1],read_position_speed_load_data[num_addr*i+2]);
  }
  USBprintf("\n");
  
}
