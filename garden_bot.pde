  /* 
    GardenBot related class, with methods for x y and z pod set & read positions 
  */

class GardenBot{
  color drawingColor = color(0);
  int numPillars = 4; //set number of pillars composing the gardenbot
  int podSize = 40; //set pod size for circle shape and projected square
  PVector[] pillars; // = new PVector[numPillars]; //store each pillar's x y coordinates and height
  PVector pod = new PVector(0,0,0); //store pod's x y z coordinates
  Button grabber = new Button(0,0,podSize); //a button used to grab the pod on ground plane
  
  boolean podGrabbed = false; //true if pod projection on ground plane is grabbed by user
  
  GardenBot(PVector[] pillarsCoordinates, color myColor){
      this.drawingColor = myColor;
      this.pillars = new PVector[pillarsCoordinates.length];
      arrayCopy(pillarsCoordinates,this.pillars);
  }
  
  void drawBot(){
    
    //draw plane rectangle
    noFill();
    stroke(this.drawingColor);
    rect(0, 0, width, height);
    
    //draw Pillars and lines between pillars and pod
    for(int i=0;i<this.numPillars;i++){
      strokeWeight(3);
      line(this.pillars[i].x,this.pillars[i].y,this.pillars[i].z,this.pillars[i].x,this.pillars[i].y,0); 
      strokeWeight(1);
      line(this.pillars[i].x,this.pillars[i].y,this.pillars[i].z,this.pod.x,this.pod.y,this.pod.z); 
    }
    
    //draw pod
    translate(0, 0, this.pod.z);
    ellipse(this.pod.x, this.pod.y, this.podSize, this.podSize);
    translate(0, 0, -this.pod.z);
    
    
    //draw x and y cursor axis
    stroke(150);
    line(this.pod.x,height/2,this.pod.x,-height/2);
    line(width/2,this.pod.y,-width/2,this.pod.y);
      
    //draw grabber
    this.grabber.x = (int) this.pod.x;
    this.grabber.y = (int) this.pod.y;
    this.grabber.drawButton();
  }
  
  void grabingUpdate(){
    if (overRect(this.pod.x, this.pod.y, this.podSize, this.podSize)) {
      this.podGrabbed = true;
    } else {
      this.podGrabbed = false;
    }
  }
  
  float[] returnLinksMeasurements(){
    float[] links = new float[4];
    for(int i = 0;i<4;i++){
      links[i]= this.pillars[i].copy().sub(this.pod).mag();
    }
    return links;
  }
  
}


class ReactShape {
  PShape custom_shape;
  PGraphics pg; //create offscreen buffer to test if a point is within shape
   
  ReactShape(){
    super();
    pg = createGraphics((int) width,(int) height);
  }
   
  void fillReactShape(PVector[] vertices){
    this.custom_shape = createShape();
    this.custom_shape.beginShape();
    this.custom_shape.fill(255);
    this.custom_shape.noStroke();
    for(PVector vect : vertices){
      this.custom_shape.vertex(vect.x, vect.y);
    }
    this.custom_shape.endShape(CLOSE);
    shape(this.custom_shape,0,0);
    this.pg.beginDraw();
    this.pg.background(0);
    this.pg.stroke(255);
    this.pg.shape(this.custom_shape,width/2,height/2);
    this.pg.endDraw();
  }
  
  void drawShape(){
    if(this.isInsideShape(mouseOnGroundPlane.x,mouseOnGroundPlane.y)){
      this.custom_shape.setFill(color(255));
      println("overshape");
    }else{
      this.custom_shape.setFill(color(0));
      println("not over shape");
    }
    shape(this.custom_shape,0,0);
  }
  
  boolean isInsideShape(float x, float y){
    if(this.pg.get((int) x + width/2,(int) y+height/2) == color(255)){
      return true;
    }else{
      return false;
    }
  }
   
}