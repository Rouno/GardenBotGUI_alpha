/*
 * calibration class and utility functions to calibrate pillars coordinates
 * with gradient descent method
 */
 
class CalibrationData{
  float[][] lengthSet; //set of pillars lengths samples for calibration
  PVector[] poseSet; //set of pod positions correspondong to lengths samples
  int maxSet = 40; //maximum number of samples for gradient descent 
  int setCursor = 0; //cursor for lengthset and poseSet ring buffer
  PVector[] pillarsToCalibrate; //store all pillars coordinates to be calibrated
  float minVariation = 400; //minimum length variation to add new sample to sets, in pixels
  float epsilon = 0.0001; //epsilon value for partial derivative computation, value is in pixel so far
  float alpha = 0.1; //rate of gradient descent convergence
  int nbGradientDescentStep = 10; //number of gradient descent steps for each optimization step
  PVector pod = new PVector(); //coordinates of predicted pod position from calibration dataset
  
  color calibrationDataColor = color(0,100,220); //color of calibrated data drawing
  
  CalibrationData(float[] initialLinks, PVector initialPod, float z){
    int n = initialLinks.length;
    this.minVariation = maxFloatArray(initialLinks)/5;
    this.lengthSet = new float[this.maxSet][n];
    this.poseSet = new PVector[this.maxSet];
    for(int i=0;i<this.maxSet;i++){
      this.lengthSet[i] = initialLinks;
      this.poseSet[i] = initialPod.copy();
    }
    this.pod = initialPod.copy();
    
    //spread initial pillars coordinates in each direction from measurement amount
    this.pillarsToCalibrate = new PVector[n];
    float tetha = TWO_PI / n;
    for(int i=0;i<n;i++){
      this.pillarsToCalibrate[i] = new PVector(initialLinks[i] * cos(i*tetha + tetha/2), initialLinks[i] * sin(i*tetha + tetha/2),z);
    }
    alignAccordingToFstEdge(pillarsToCalibrate); //align and center initial pillars coordinates prediction to match ground truth convergence
  }

  
  //add a new sample links measures in the sample list
  void addSample(float[] length_measures, PVector pose){
    int last_cursor = (this.setCursor+this.maxSet-1)%this.maxSet;
    PVector pod_eval = podFromLinksMeasures(this.lengthSet[last_cursor], this.pillarsToCalibrate);
    this.pod = podFromLinksMeasures(length_measures, this.pillarsToCalibrate);
    //only add sample if pod differes from last pod by at least minVariation amount
    if( pod_eval.sub(this.pod).mag() > this.minVariation){ 
      this.lengthSet[this.setCursor] = length_measures;
      this.poseSet[this.setCursor] = pose.copy();
      this.setCursor +=1;
      this.setCursor %= this.maxSet;
    }
    
  }
  
  //returns predicted measurements from current recorded data
  float[] returnLinksMeasurements(){
    int n = this.pillarsToCalibrate.length;
    float[] links = new float[n];
    for(int i = 0;i<n;i++){
      links[i]= this.pillarsToCalibrate[i].copy().sub(this.pod).mag();
    }
    printArray(links);
    return links;
  }

  float costFunction(){
    float error=0;
    PVector[] myPillars = this.pillarsToCalibrate;
    int n=this.setCursor % this.maxSet+1;
    int m=this.pillarsToCalibrate.length; //length must be >= 4
    for(int i=0; i<n;i++){ //compute error over all samples
      PVector podPrediction = podFromLinksMeasures(this.lengthSet[i],myPillars);
      for(int j=0; j<m;j++){
        float Lij = podPrediction.copy().sub(myPillars[j]).mag();
        float realLij = this.lengthSet[i][j];
        error += sq(Lij - realLij);
        if(podPrediction.z<0) error+=sq(podPrediction.z); //pod cannot have negative z coordinate
        if(podPrediction.z>maxZcoordinates(myPillars)) error+= sq(podPrediction.z - maxZcoordinates(myPillars)); // pod cannot be higher than pillars
      }
    }
    error/=2 * n;
    return error;
  }
  
  PVector[] costFunctionGradient(){
    float fxyz = this.costFunction(); 
    PVector[] gradient = new PVector[0];
    
    //compute partial derivatives for each pillar
    for(PVector vect : this.pillarsToCalibrate){
      float dfx,dfy,dfz;
      vect.x += epsilon;
      dfx = (this.costFunction() - fxyz)/this.epsilon;
      vect.x -= epsilon;
      vect.y += epsilon;
      dfy = (this.costFunction() - fxyz)/this.epsilon;
      vect.y -= epsilon;
      dfz = 0 ;  //(this.costFunction() - fxyz)/this.epsilon; assume that all pillars are at the same height
      gradient = (PVector[]) append(gradient, new PVector(dfx,dfy,dfz));
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
    
    //center pillars x y coordinates around origin
    PVector meanPillarsCoordinates = pvectorMean(this.pillarsToCalibrate);
    meanPillarsCoordinates.z=0;
    for(PVector vect : this.pillarsToCalibrate){
      vect.sub(meanPillarsCoordinates);
    }
  }

  void drawData(){
    //draw ground truth pod poses used to record links measures
    stroke(this.calibrationDataColor);
    strokeWeight(5);
    for(PVector pose : this.poseSet){
      point(pose.x,pose.y,pose.z);
    }
    strokeWeight(1);
  
    //draw pod
    stroke(this.calibrationDataColor);
    strokeWeight(10);
    point(this.pod.x,this.pod.y,this.pod.z);
    strokeWeight(1);
 
    //draw pillars under calibration
    stroke(this.calibrationDataColor);
    PVector[] pillars=this.pillarsToCalibrate;
    int n = pillars.length;
    for(int i=0;i<n;i++){
      if(i>1)stroke(color(200,0,200));
      strokeWeight(3);
      line(pillars[i].x,pillars[i].y,pillars[i].z,pillars[i].x,pillars[i].y,0); 
      strokeWeight(1);
      line(pillars[i].x,pillars[i].y,pillars[i].z,this.pod.x,this.pod.y,this.pod.z);
    }
  }
 
}