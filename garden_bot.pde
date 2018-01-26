/* 
 GardenBot related class, with methods for x y and z pod set & read positions 
 */

static float MAX_WINCH_SPEED = 30;
static float MIN_WINCH_SPEED = 1;
static float WINCH_SPEED_RATE = 1.1;
static float ACTUATOR_LOAD = 200;
static float BREAKING_DISTANCE_IN_MM = 100;

class GardenBot {

  color drawingColor = 255;
  int nbPillars; //set number of pillars composing the gardenbot
  int podSize = 40; //set pod size for circle shape and projected square
  float pillarHeight;
  PVector[] pillars; //store each pillar's x y coordinates and height
  float[] errorFactorArray;
  ReactShape footprint;
  PVector targetPodPosition = new PVector(0, 0, 0); //store target pod position
  PVector currentPodPosition = new PVector(0, 0, 0); //store current pod position
  float winchSpeed = MAX_WINCH_SPEED;
  Button grabber; //a button used to grab the pod on ground plane

  boolean podGrabbed = false; //true if pod projection on ground plane is grabbed by user

  GardenBot(PVector[] pillarsCoordinates, float pod_height) {

    this.grabber = new Button(0, 0, podSize);
    this.pillarHeight = pillarsCoordinates[0].z;
    this.nbPillars = pillarsCoordinates.length;
    this.pillars = new PVector[this.nbPillars];
    this.errorFactorArray = new float[this.nbPillars];
    for(float f : this.errorFactorArray){
      f=1.0;
    }
    this.currentPodPosition.z = pod_height;
    this.targetPodPosition.z = pod_height;
    arrayCopy(pillarsCoordinates, this.pillars);
    footprint = new ReactShape(pillars);
  }
  
  GardenBot(PVector[] pillarsCoordinates, float pod_height, float[] measureErrorFactors) {
    this(pillarsCoordinates, pod_height);
    this.errorFactorArray = measureErrorFactors;
  }

  void drawBot() {

    //draw bot footprint
    noFill();
    stroke(this.drawingColor);
    shape(footprint.custom_shape, 0, 0);

    //draw Pillars and lines between pillars and pod
    for (int i=0; i<this.nbPillars; i++) {
      strokeWeight(3);
      line(this.pillars[i].x, this.pillars[i].y, this.pillars[i].z, this.pillars[i].x, this.pillars[i].y, 0); 
      strokeWeight(1);
      line(this.pillars[i].x, this.pillars[i].y, this.pillars[i].z, this.currentPodPosition.x, this.currentPodPosition.y, this.currentPodPosition.z);
      //drawCoordinatesOnPlane(this.pillars[i]);
  }

    //draw pod
    translate(0, 0, this.targetPodPosition.z);
    ellipse(this.targetPodPosition.x, this.targetPodPosition.y, this.podSize, this.podSize);
    translate(0, 0, -this.targetPodPosition.z);

    //draw current pod
    translate(0, 0, this.currentPodPosition.z);
    ellipse(this.currentPodPosition.x, this.currentPodPosition.y, this.podSize, this.podSize);
    translate(0, 0, -this.currentPodPosition.z);

    //draw x and y cursor axis
    stroke(150);

    PVector[] podXYbound = footprint.getUpDownLeftRightbounds(this.targetPodPosition);
    line(podXYbound[0].x, podXYbound[0].y, podXYbound[2].x, podXYbound[2].y);
    line(podXYbound[1].x, podXYbound[1].y, podXYbound[3].x, podXYbound[3].y);

    //draw grabber
    this.grabber.x = (int) this.targetPodPosition.x;
    this.grabber.y = (int) this.targetPodPosition.y;
    this.grabber.drawButton();
  }

  boolean isMouseOverGrabber() {
    return overRect(this.targetPodPosition.x, this.targetPodPosition.y, this.podSize, this.podSize);
  }

  void moveTargetPodPosition(PVector updatedLocation) {
    float savedheight = this.targetPodPosition.z;
    this.targetPodPosition = this.footprint.getClosestPointInsideShape(updatedLocation);
    this.targetPodPosition.z = savedheight;
  }

  float[] returnCableLengths(PVector point) {
    float[] cableLengthData = new float[this.nbPillars];
    for (int i = 0; i<this.nbPillars; i++) {
      cableLengthData[i]= this.pillars[i].copy().sub(point).mag();
    }
    return cableLengthData;
  }
  
  void setCurrentPodPosition(float[] lengthInputs){
    int n = this.pillars.length;
    PVector[] poseEstimationsArray = new PVector[n];
    for(int i=0; i<n;i++){
      poseEstimationsArray[i] = podFromcableLengthDataMeasures(shortenByIndex(lengthInputs,i),shortenByIndex(this.pillars,i));
    }
    this.currentPodPosition = pvectorMean(poseEstimationsArray);
  }
  
  void setCurrentPodPosition(float[] lengthInputs, float[] errCorrection){
    for(int i=0;i<lengthInputs.length;i++){
      lengthInputs[i] *= errCorrection[i]; //apply correction factors calibrated by calibrator
    }
    this.setCurrentPodPosition(lengthInputs);
  }

  float[] getCableVariations() {
    float[] result = new float[this.nbPillars];
    PVector goalDirection = this.targetPodPosition.copy().sub(this.currentPodPosition);
    if(goalDirection.mag()>1) goalDirection.div(goalDirection.mag());
    PVector d_goalDirection = this.currentPodPosition.copy().add(goalDirection);
    float[] currentCableLength = returnCableLengths(this.currentPodPosition);
    float[] d_targetCableLength = returnCableLengths(d_goalDirection);
    float maxCableVariation = 0;

    for (int i = 0; i<this.nbPillars; i++) {
      result[i] = d_targetCableLength[i] - currentCableLength[i];
      if (abs(result[i]) > maxCableVariation) maxCableVariation = abs(result[i]);
    }
    for (int i = 0; i<this.nbPillars; i++) {
      if(maxCableVariation!= 0) result[i] /= maxCableVariation;
    }
    return result;
  }
  
  float[] getTargetPosSpeedLoad(){
    float[] cableLengths = returnCableLengths(this.targetPodPosition);
    float[] cableVariations = getCableVariations();
    float[] result = new float[pillars.length * NB_WORD_SERIAL_OUT];
    for(int i = 0; i<pillars.length; i++){
      result[i*NB_WORD_SERIAL_OUT] = cableLengths[i]/this.errorFactorArray[i]; //divide by correction factor before sending to microtronller 
      result[i*NB_WORD_SERIAL_OUT+1] = MAX_WINCH_SPEED * cableVariations[i];
      result[i*NB_WORD_SERIAL_OUT+2] = ACTUATOR_LOAD;
    }
    return result;
  }
  
  void testSetCurrentPodPos() {
    PVector[] first3Pillars = (PVector[]) subset(this.pillars, 0, 3);
    float[] first3CableLength = (float[]) subset(returnCableLengths(this.currentPodPosition), 0, 3);
    float[] first3CableRatios = (float[]) subset(getCableVariations(), 0, 3);
    if (this.currentPodPosition.dist(this.targetPodPosition) > MAX_WINCH_SPEED) {
      for (int i=0; i<3; i++) {
        first3CableLength[i] += first3CableRatios[i]*this.winchSpeed;
      }
    }
    this.currentPodPosition = podFromcableLengthDataMeasures(first3CableLength, first3Pillars);
  }

  void setWinchSpeed() {
    if (this.targetPodPosition.dist(this.currentPodPosition)>BREAKING_DISTANCE_IN_MM) {
      this.winchSpeed = min(this.winchSpeed * WINCH_SPEED_RATE, MAX_WINCH_SPEED);
    } else {
      this.winchSpeed = max(this.winchSpeed / WINCH_SPEED_RATE, MIN_WINCH_SPEED);
    }
  }

  void mouvePodUp() {
    if (this.targetPodPosition.z + 10 <= this.pillarHeight) {
      this.targetPodPosition.z += 10;
    }
  }

  void movePodDown() {
    if (this.targetPodPosition.z - 10 >= 0) {
      this.targetPodPosition.z -= 10;
    }
  }
}

//class made of any custom shape to know if a point is inside the shape
class ReactShape {
  PShape custom_shape;
  PShape offscreen_custom_shape;
  PGraphics pg; //create offscreen buffer to test if a point is within shape

  ReactShape(PVector[] vertices) {
    pg = createGraphics((int) (1 * maxWidth(vertices)), (int) (1 * maxHeight(vertices)));
    println("maxwidth "+maxWidth(vertices)+ " maxheight "+maxHeight(vertices));
    this.setShape(vertices);
    
  }

  void setShape(PVector[] shapeVertices){
    this.custom_shape = createShape();
    this.offscreen_custom_shape = createShape();
    this.custom_shape.beginShape();
    this.offscreen_custom_shape.beginShape();
    this.custom_shape.noFill();
    this.offscreen_custom_shape.fill(255);
    this.custom_shape.stroke(255);
    for (PVector vect : shapeVertices) {
      this.custom_shape.vertex(vect.x, vect.y);
      offscreen_custom_shape.vertex(vect.x, vect.y);
    }
    this.custom_shape.endShape(CLOSE);
    this.offscreen_custom_shape.endShape(CLOSE);
    shape(this.custom_shape, 0, 0);
    this.pg.beginDraw();
    this.pg.background(0);
    this.pg.stroke(255);
    this.pg.shape(offscreen_custom_shape, pg.width/2, pg.height/2);
    this.pg.endDraw();
  }

  //return true if point over shape
  boolean isOverFootprint(PVector point) {
    if (this.pg.get((int) point.x + pg.width/2, (int) point.y+pg.height/2) == color(255)) {
      return true;
    } else {
      return false;
    }
  }

  //return the closest coordinates inside shape from point using dicotomy, origin must be inside shape
  PVector getClosestPointInsideShape(PVector point) {
    PVector pt = point.copy();
    if (isOverFootprint(pt)) return pt;
    float dicotomy_mag = pt.mag()/2;
    while (dicotomy_mag >= 1) {  //while pixel diff between point and result > 1 pixel
      if (isOverFootprint(pt)) {
        pt.setMag(pt.mag()+dicotomy_mag);
      } else {
        pt.setMag(pt.mag()-dicotomy_mag);
      }
      dicotomy_mag /= 2;
    }
    return pt;
  }

  PVector[] getUpDownLeftRightbounds(PVector point) {
    PVector[] result=new PVector[4]; //4 vectors : 4 boundaries along +x +y -x -y
    PVector unitVector = new PVector(1, 0);
    for (int i=0; i<4; i++) {
      float dicotomy_mag = max(pg.width/2, pg.height/2);
      result[i] = point.copy();
      while (dicotomy_mag > 1) {  //while pixel diff between point and result > 1 pixel
        if (isOverFootprint(result[i])) {   
          result[i].add(unitVector.copy().mult(dicotomy_mag));
        } else {
          result[i].sub(unitVector.copy().mult(dicotomy_mag));
        }
        dicotomy_mag /= 2;
      }
      unitVector.rotate(HALF_PI);
    }
    return result;
  }
}

//overRect is true if cursor on a 2D rectangle that lies on ground plane
boolean overRect(float x, float y, float width, float height){
  if (myCameraControls.mouseOnGroundPlane.x >= x-width/2 && myCameraControls.mouseOnGroundPlane.x <= x+width/2 && 
    myCameraControls.mouseOnGroundPlane.y >= y-height/2 && myCameraControls.mouseOnGroundPlane.y <= y+height/2) {
    return true;
  } else {
    return false;
  }
}

class Button{
  int x,y;  //button center coordinates
  int size;  //button size
  color rectColor, rectHighlight, rectClicked;  //color states
  boolean onoff = true;
  
  Button(int tmp_x, int tmp_y, int tmp_size) {
    this.x = tmp_x;
    this.y = tmp_y;
    this.size = tmp_size;
    this.rectColor = 100;
    this.rectHighlight = 150;
    this.rectClicked = 255;
    this.onoff = true;
  }
  
  void drawButton(){
    if (this.onoff){
      fill(this.rectClicked);
    } else {
      fill(this.rectColor);
    }
    
    if(overRect(this.x, this.y, this.size, this.size)){ 
       stroke(255);
     } else {
       stroke(0);
     }
    rect(this.x, this.y, this.size, this.size);
  }
  
  void stateUpdate(){
    if (overRect(this.x, this.y, this.size, this.size)){ 
      this.onoff = !this.onoff;
    }
  }

}