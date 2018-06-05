/* 
 CableBot related class, with methods for x y and z pod set & read positions 
 */

class CableBot {
  
  final float GRID_SIZE = 5000; //GRID_SIZE 1px = 1mm
  final float GRID_RES = 100; //resoltion in between grid lines in mm
  
  Winch[] winch; //store each pillar's x y coordinates and height
  Pod pod;
  ReactShape footprint;

  CableBot(PVector[] coords) {
    this.pod = new Pod();
    this.winch = new Winch[coords.length];
    PVector[] shape = new PVector[this.winch.length];
    for(int i=0;i<coords.length;i++){
      this.winch[i] = new Winch(i,coords[i]);
      shape[i] = this.winch[i].getCoordinates();
    }
    this.footprint = new ReactShape(shape);
    this.setFootPrint();
    this.setPresentLengthFromPod();
  }
  
  CableBot(Winch[] wincharray){
    this.pod = new Pod();
    this.winch = new Winch[wincharray.length];
    for(int i=0;i<wincharray.length;i++){
      this.winch[i] = new Winch(i,wincharray[i].getPresentLength());
    }
  }
  
  
  /*
  *  Build and receive frame for serial updates
  */
  
  int[] buildFrame(){ //move to CableBot class ?
    int[] result = new int[SerialBridge.num_data];
    int nWinch = this.winch.length;
    for(int i =0;i<nWinch;i++){
      result[i*SerialBridge.nb_data_per_actuator] = int( (this.winch[i].getGoalLength() + this.winch[i].getZeroOffset())/POSITION_TO_FLOAT_mm );
      result[i*SerialBridge.nb_data_per_actuator+1] = int(this.winch[i].getGoalSpeed());
      result[i*SerialBridge.nb_data_per_actuator+2] = int(this.winch[i].getTorqueLimit());
    }
    return result;
  }
  
  //TODO : write winch methods to convert word values in float values
  void receiveFrame(String[] tokens){
    for(int i = 0;i<this.winch.length;i++){
      float len = float(tokens[i*SerialBridge.nb_data_per_actuator]) * POSITION_TO_FLOAT_mm - this.winch[i].getZeroOffset();
      float speed = float(tokens[i*SerialBridge.nb_data_per_actuator+1]);
      float load = float(tokens[i*SerialBridge.nb_data_per_actuator+2]);
      this.winch[i].setPresentValues(len,speed,load);
    }
  } 
  
  
  /*
  *  update pod present coordinates from new winch lengths reading 
  *  &
  *  updates goal winch length from new pod goal coordinates
  */
  
  void setPresentPodFromWinchLengths(){
    if(this.winch.length<3){
      println("number of winches needs to be at least 3");
      this.pod.setPresentCoordinates(new PVector(0,0,0));
    }else{
      float[] lengths = new float[this.winch.length];
      PVector[] poses = new PVector[this.winch.length];
      for(int i=0;i<this.winch.length;i++){
        lengths[i] = this.winch[i].getPresentLength();
        poses[i] = this.winch[i].getCoordinates();
      }
      this.pod.setPresentCoordinates(trilateration(lengths,poses).coordinates);
    }
  }
  
  //used only when no serial available
  void setPresentLengthFromPod(){ 
    for(Winch w : this.winch){
      float Li = w.getCoordinates().dist(this.pod.getGoalCoordinates());
      w.setPresentLength(Li);
    }
  }
  //used only when no serial available
  void setPresentLengthFromLengths(Winch[] wincharray){ 
    for(int i=0;i<wincharray.length;i++){
      this.winch[i].setPresentLength(wincharray[i].getPresentLength());
    }
    this.setPresentPodFromWinchLengths();
  }
  
  void setGoalLengthFromPod(){
    for(Winch w : this.winch){
      float Li = w.getCoordinates().dist(this.pod.getGoalCoordinates());
      w.setGoalLength(Li);
    }
  }
  
  PVector getPodFromLengths(float[] lengths){
    PVector[] poses = copyWinchCoords();
    return trilateration(lengths,poses).coordinates;
  }
  
  float[] getWinchPresentLength(){
    float[] result = new float[this.winch.length];
    for(int i=0;i<this.winch.length;i++){
      result[i]=this.winch[i].getPresentLength();
    }
    return result;
  }
  
  PVector[] copyWinchCoords(){
    PVector[] result = new PVector[this.winch.length];
    for(int i=0;i<this.winch.length;i++){
      result[i] = new PVector();
      result[i]=this.winch[i].getCoordinates().copy();
    }
    return result;
  }
  
  
  /*
  *  UI functions
  */
  
  void grabPod(){
    this.pod.grabber.setGrab(true);
  }
  
  void releaseGrab(){
    this.pod.grabber.setGrab(false);
  }
  
  boolean isGrabbed(){
    return this.pod.grabber.getGrab();
  }
  
  boolean isPointOverGrabber(PVector point){
    return this.pod.grabber.isPointOverButton(point);
  }
  
  
  /*
  *  Actuator driving functions
  */
  
  boolean setZeroingActuators(int t0){
    boolean result;
    int nbWinchZeroed = 0;
    for (Winch w : this.winch) {
      if (w.getPresentSpeed() == 0 && t0>10000) { //means that winch reached true zero position
        w.setGoalSpeed(0);
        w.setGoalLength(0);
        w.setPresentLength(0);
        w.setZeroOffset(w.getPresentLength());
        nbWinchZeroed+=1;
      } else {
        w.setGoalValues(0, 300, Winch.MAX_TORQUE);
      }
    }
    if (nbWinchZeroed == this.winch.length){
      result = true;
    }else{
      result = false;
    }
    return result;
  }
  
  void setCompliantActuators(){
    for (Winch w : this.winch) {
      if (w.getTorqueLimit()<w.getPresentLoad()) {
        float newTorque = max(w.getTorqueLimit()-10, 0);
        w.setTorqueLimit(newTorque);
      } else {
        float newTorque = min(w.getTorqueLimit()+10, Winch.MAX_TORQUE);
        w.setTorqueLimit(newTorque);
      }
    }
  }
  
  
  /*
  *  drawing functions
  */
  
  void drawGrid() {
    stroke(50);
    strokeWeight(1);
    for (int i=-(int)GRID_SIZE/2; i<(int)GRID_SIZE/2; i+=GRID_RES) {
      line(i, GRID_SIZE/2, i, -GRID_SIZE/2);
      line(GRID_SIZE/2, i, -GRID_SIZE/2, i);
    }
  }
  
  void drawCursorAxis(){
    strokeWeight(1);
    stroke(255,0,255);
    PVector[] podXYbound = this.footprint.getUpDownLeftRightbounds(this.pod.getGoalCoordinates());
    line(podXYbound[0].x, podXYbound[0].y, podXYbound[2].x, podXYbound[2].y);
    line(podXYbound[1].x, podXYbound[1].y, podXYbound[3].x, podXYbound[3].y);
  }
  
  void drawCables(){
    for(Winch w : this.winch){
      stroke(w.c,100,100);
      PVector winchcoord = w.getCoordinates();
      PVector podcoord = this.pod.getPresentCoordinates();
      line(winchcoord.x,winchcoord.y,winchcoord.z,podcoord.x,podcoord.y,podcoord.z);
    }
  }

  void setFootPrint(){
    PVector[] shape = new PVector[this.winch.length];
    for(int i=0;i<this.winch.length;i++){
      shape[i] = this.winch[i].getCoordinates();
    }
    this.footprint.setShape(shape);
  }
  
  void drawBot(){
    for(Winch w : this.winch){
      w.drawWinch();
    }
    this.drawGrid();
    this.pod.draw();
    this.drawCables();
    
    if(this.footprint != null){
      this.footprint.drawShape();
      this.drawCursorAxis();
    }
  }
}
