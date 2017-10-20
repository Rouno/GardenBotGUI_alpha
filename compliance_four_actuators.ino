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


word max_load = 200;
word torque_load_avg = 60;
float curvature_factor = 0.05;

static byte actuator_ids[NUM_ACTUATORS] = {
	1,2,3,4
};

word initial_position[NUM_ACTUATORS];
unsigned long t0;

// Calculate moving average
inline double movingAverge(double Yt)
{
  static int n = 0;
  static double St = 0.0;
  
  St += Yt;
  return St/(++n);
}

void setup()
{
  word init_speed = 512;
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
  Dxl.setGoalAcceleration(actuator_ids, NUM_ACTUATORS,(uint8) 0);    //0~254, max acceleration = 2180°/sec^2
  
  // Initialize DXL_MOVING_SPEED of ACTUATOR_IDS
  Dxl.setPosition(actuator_ids, NUM_ACTUATORS,(uint16) 0);
  Dxl.setSpeed(actuator_ids, NUM_ACTUATORS,(uint8) init_speed);
  
  USBprintf("Initialized.\n");
  delay(1000);
  
  // Phase offest for sinusoidal oscillations
  t0 = millis();
}

void loop()
{
  static unsigned long iter = 0;
  unsigned long read_duration, print_duration;
  double mean_total_duration;
  byte i, write_start_addr = DXL_GOAL_POSITION, read_start_addr = DXL_PRESENT_POSITION;
  const byte num_addr = 3, num_data = num_addr*NUM_ACTUATORS;
  word write_load_data[NUM_ACTUATORS], read_position_speed_load_data[num_data];
  word torque = 100,present_load;
  
  // Elapsed time for printing and reset timer
  print_duration = usElapsed();
  
  // Read present position, speed and load from all actuators in actuator_ids and store in array
  Dxl.syncRead(actuator_ids, NUM_ACTUATORS, read_start_addr, num_addr, read_position_speed_load_data);
  
  // Elapsed time for reading and reset timer
  read_duration = usElapsed();
  mean_total_duration = movingAverge(read_duration+print_duration);
  iter++;
  
  //controlling torque for compliance
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
  
  
  // Print position and speed data for each actuator in actuator_ids 
  for (i = 0; i < NUM_ACTUATORS; i++) {
    USBprintf("  -  Actuator: %u  -  Position: %u, Speed: %u - Load: %u\n",
      actuator_ids[i],read_position_speed_load_data[num_addr*i],read_position_speed_load_data[num_addr*i+1],read_position_speed_load_data[num_addr*i+1]);
  }
  USBprintf("\n");
}
