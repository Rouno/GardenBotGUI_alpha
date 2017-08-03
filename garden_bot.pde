  /* 
    GardenBot related class, with methods for x y and z pod set & read positions 
  */

class GardenBot{
  color drawingColor = color(0);
  int nbPillars; //set number of pillars composing the gardenbot
  int podSize = 40; //set pod size for circle shape and projected square
  PVector[] pillars; // = new PVector[nbPillars]; //store each pillar's x y coordinates and height
  ReactShape footprint;
  PVector pod = new PVector(0,0,0); //store pod's x y z coordinates
  Button grabber = new Button(0,0,podSize); //a button used to grab the pod on ground plane
  
  boolean podGrabbed = false; //true if pod projection on ground plane is grabbed by user
  
  GardenBot(PVector[] pillarsCoordinates, color myColor){
      this.drawingColor = myColor;
      this.nbPillars = pillarsCoordinates.length;
      this.pillars = new PVector[this.nbPillars];
      arrayCopy(pillarsCoordinates,this.pillars);
      footprint = new ReactShape();
      footprint.fillReactShape(pillars);
  }
  
  void drawBot(){
    
    //draw bot footprint
    noFill();
    stroke(this.drawingColor);
    shape(footprint.custom_shape,0,0);
    
    //draw Pillars and lines between pillars and pod
    for(int i=0;i<this.nbPillars;i++){
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
    float[] links = new float[nbPillars];
    for(int i = 0;i<nbPillars;i++){
      links[i]= this.pillars[i].copy().sub(this.pod).mag();
    }
    return links;
  }
  
}


class ReactShape {
  PShape custom_shape;
  PShape offscreen_custom_shape;
  PGraphics pg; //create offscreen buffer to test if a point is within shape
   
  ReactShape(){
    super();
    pg = createGraphics((int) width,(int) height);
  }
   
  void fillReactShape(PVector[] vertices){
    this.custom_shape = createShape();
    offscreen_custom_shape = createShape();
    this.custom_shape.beginShape();
    offscreen_custom_shape.beginShape();
    this.custom_shape.noFill();
    offscreen_custom_shape.fill(255);
    this.custom_shape.stroke(255);
    for(PVector vect : vertices){
      this.custom_shape.vertex(vect.x, vect.y);
      offscreen_custom_shape.vertex(vect.x, vect.y);
      
    }
    this.custom_shape.endShape(CLOSE);
    offscreen_custom_shape.endShape(CLOSE);
    shape(this.custom_shape,0,0);
    this.pg.beginDraw();
    this.pg.background(0);
    this.pg.stroke(255);
    this.pg.shape(offscreen_custom_shape,width/2,height/2);
    this.pg.endDraw();
  }
    
  boolean isInsideShape(float x, float y){
    if(this.pg.get((int) x + width/2,(int) y+height/2) == color(255)){
      return true;
    }else{
      return false;
    }
  }
   
}