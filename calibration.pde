/*
 * calibration class and utility functions to calibrate pillars coordinates
 * with gradient descent method
 */
 
class CalibrationData{
  ArrayList<float[]> lengthSet = new ArrayList<float[]>(); //set of pillars lengths samples for calibration
  ArrayList<PVector> poseSet = new ArrayList<PVector>(); //set of pod positions correspondong to lengths samples
  int maxSet = 20;
  int setCursor = 1;
  PVector[] pillarsToCalibrate; //store all pillars coordinates to be calibrated
  float minVariation = 400; //minimum length variation to add new sample to sets, in pixels
  float epsilon = 0.0001; //epsilon value for partial derivative computation, value is in pixel so far
  float alpha = 0.1; //rate of gradient descent convergence
  int nbGradientDescentStep = 10; //number of gradient descent steps for each optimization step
  PVector pod = new PVector();
  
  color calibrationDataColor = color(0,100,220); //color of calibrated data drawing
  
  CalibrationData(float[] initialLengths, PVector initialPod, float z){
    this.lengthSet.add(initialLengths);
    this.poseSet.add(initialPod);
    this.pod = initialPod.copy();
    
    //spread initial pillars coordinates in each direction from measurement amount
    int n = initialLengths.length;
    this.pillarsToCalibrate = new PVector[n];
    float tetha = TWO_PI / n;
    for(int i=0;i<n;i++){
      this.pillarsToCalibrate[i] = new PVector(initialLengths[i] * cos(i*tetha + tetha/2), initialLengths[i] * sin(i*tetha + tetha/2),z);
    }
  }
  
  //add a new sample in the sample list only if new measurement has a relative change at least of minVariation and call optimizationStep for gradient descent
  void addSample(float[] length_measures, PVector pose){   
    this.pod = podFromLinksMeasures(length_measures,this.pillarsToCalibrate);
    float linksVariation=sumFloatArray(absDiffArray(length_measures,this.lengthSet.get((this.setCursor-1) % this.maxSet)));
    
    if(linksVariation > this.minVariation){
      if(this.setCursor < this.maxSet){
        this.lengthSet.add(length_measures);
        this.poseSet.add(pose.copy());    
      }else{
        this.lengthSet.set(this.setCursor % this.maxSet,length_measures);
        this.poseSet.set(this.setCursor % this.maxSet,pose.copy());
      }
      this.setCursor +=1;
    }
  }
  
  float[] returnLinksMeasurements(){
    float[] links = new float[this.pillarsToCalibrate.length];
    for(int i = 0;i<4;i++){
      links[i]= this.pillarsToCalibrate[i].copy().sub(this.pod).mag();
    }
    return links;
  }

  float costFunction(){
    float error=0;
    PVector[] myPillars = this.pillarsToCalibrate;
    int n=this.lengthSet.size();
    int m=this.pillarsToCalibrate.length; //length must be >= 4
    
    for(int i=0; i<n;i++){ //compute error over all samples
      PVector podPrediction = podFromLinksMeasures(this.lengthSet.get(i),myPillars);
      for(int j=0; j<m;j++){
        float Lij = podPrediction.copy().sub(myPillars[j]).mag();
        float realLij = this.lengthSet.get(i)[j];
        error += sq(Lij - realLij);
        if(podPrediction.z<0) error+=sq(podPrediction.z); //pod cannot have negative z coordinate
        if(podPrediction.z>maxZcoordinates(myPillars)) error+= sq(podPrediction.z - maxZcoordinates(myPillars)); // pod cannot be higher than pillars
      }
    }
    error/=2 * n;
    return error;
  }
  
  PVector[] costFunctionGradient(){
    int n = this.pillarsToCalibrate.length;
    float fxyz = this.costFunction();
    println("cost function evaluation : " + fxyz); 
    PVector[] gradient = new PVector[n];
    
    //compute partial derivatives for each pillar
    for(int i=0;i<n;i++){
      float dfx,dfy,dfz;
      this.pillarsToCalibrate[i].x += epsilon;
      dfx = (this.costFunction() - fxyz)/this.epsilon;
      this.pillarsToCalibrate[i].x -= epsilon;
      
      this.pillarsToCalibrate[i].y += epsilon;
      dfy = (this.costFunction() - fxyz)/this.epsilon;
      this.pillarsToCalibrate[i].y -= epsilon;
      
      dfz = 0 ;  //(this.costFunction() - fxyz)/this.epsilon; assume that all pillars are at the same height
      
      gradient[i] = new PVector(dfx,dfy,dfz);
    }
    return gradient;
  }
  
  void optimizationStep(){
    int n = this.pillarsToCalibrate.length;
    PVector[] gradient = new PVector[n];
    for(int i= 0;i<this.nbGradientDescentStep;i++){
      gradient = costFunctionGradient();
      //correction step : params -= alpha * gradient
      for(int j = 1;j<n;j++){ //fix first pillar coordinates 
        gradient[j].mult(this.alpha);
        this.pillarsToCalibrate[j].sub(gradient[j]);
      }
      this.pillarsToCalibrate[1].y += gradient[1].y; //fix 2nd pillar y coordinate
    }
    
    //center pillars coordinates around origin
    PVector meanPillarsCoordinates = pvectorMean(this.pillarsToCalibrate);
    for(PVector vect : this.pillarsToCalibrate){
      vect.x -=meanPillarsCoordinates.x;
      vect.y -=meanPillarsCoordinates.y;
    }
  }

  void drawPoseSamples(){
    stroke(this.calibrationDataColor);
    strokeWeight(5);
    for(PVector pose : this.poseSet){
      point(pose.x,pose.y,pose.z);
    }
    strokeWeight(1);
  }
  
  void drawPod(){
    stroke(this.calibrationDataColor);
    strokeWeight(10);
    point(this.pod.x,this.pod.y,this.pod.z);
    strokeWeight(1);
  }
 
 void drawPillarsToCalibrate(){
   stroke(this.calibrationDataColor);
   PVector[] pillars=this.pillarsToCalibrate;
   int n = pillars.length;
   //draw Pillars and lines between pillars and pod
    for(int i=0;i<n;i++){
      if(i>1)stroke(color(200,0,200));
      strokeWeight(3);
      line(pillars[i].x,pillars[i].y,pillars[i].z,pillars[i].x,pillars[i].y,0); 
      strokeWeight(1);
      line(pillars[i].x,pillars[i].y,pillars[i].z,this.pod.x,this.pod.y,this.pod.z); 
    }
 }
 
}


//Compute pod 3d position from links measurements, takes only 3 points
//from https://en.wikipedia.org/wiki/Trilateration
PVector podFromLinksMeasures(float[] measures, PVector[] P1P2P3){
  float r1 = measures[0];
  float r2 = measures[1];
  float r3 = measures[2];
  PVector P1,P2,P3,P1P2,P1P3 = new PVector();
  
  P1 = P1P2P3[0].copy();
  P2 = P1P2P3[1].copy();
  P3 = P1P2P3[2].copy();
  P1P2 = P2.copy().sub(P1);
  P1P3 = P3.copy().sub(P1);
  
  
  //Compute unit vectors derived from first 3 first pillars coordinates
  PVector Ex = P1P2.copy().div(P1P2.mag());
  float i = Ex.copy().dot(P3.copy().sub(P1));
  PVector Ey = P1P3.copy().sub(Ex.copy().mult(i)).div(P1P3.copy().sub(Ex.copy().mult(i)).mag());
  PVector Ez = Ex.copy().cross(Ey);
  
  float d = P1P2.mag();
  float j = Ey.copy().dot(P3.copy().sub(P1));
  
  float x = (r1*r1 - r2*r2 + d*d)/(2*d);
  float y = (r1*r1 - r3*r3 + i*i + j*j)/(2*j) - i/j*x;
  
  PVector result = new PVector();
  float z = 0;
  if(r1*r1 - x*x - y*y >=0 ){
    z = - sqrt(r1*r1 - x*x - y*y);
    result = P1.add(Ex.mult(x)).add(Ey.mult(y)).add(Ez.mult(z));
  }else{
    //if 3 spheres intersection has no solution, grab closest solution following Al Kashi theoreme 
    //http://kuartin.math.pagesperso-orange.fr/theoremealkashi.htm
    float cosalpha = (sq(d)-sq(r2)+sq(r1))/(2*r1*d);
    cosalpha = max(min(cosalpha,1),-1); //ensure unique cosalpha solution by caping cosalpha between -1 and 1, appears when r1 & r2 links cross each others
    float sinalpha = sqrt(1 - sq(cosalpha));
    result = P1.add(Ex.mult(cosalpha*r1).add(Ey.mult(sinalpha*r1)));
  }
  return result;
}

float[] absDiffArray(float[] firstArray, float[] secondArray){
  int n = firstArray.length;
  float[] resultarray = new float[n];
  for(int i=0; i<n;i++){
    resultarray[i]=abs(firstArray[i]-secondArray[i]);
  }
  return resultarray;
}

float sumFloatArray(float[] anArray){
  float result = 0;
  for(int i=0; i<anArray.length; i++){
    result += anArray[i];
  }
  return result;
}

PVector pvectorMean(PVector[] vector_array){
  PVector result = new PVector(0,0,0);
  for(PVector vect : vector_array){
    result = result.add(vect);
  }
  result = result.div(vector_array.length);
  return result;
}

float maxZcoordinates(PVector[] vector_array){
  float result=0; //assume z coordinates >= 0
  for(PVector vect : vector_array){
    if(vect.z > result) result = vect.z;
  }
  return result;
}