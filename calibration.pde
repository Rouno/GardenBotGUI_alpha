/*
 * calibration class and utility functions to calibrate pillars coordinates
 * with gradient descent method
 */

class Calibrator {
  float[] initValues; //store initial measurement values for reset function
  float init_height;
  float[][] cableLengthSet; //set of pillars lengths samples for calibration
  PVector[] podPoseSet; //set of pod positions correspondong to lengths samples
  int maxSet = 40; //maximum number of samples for gradient descent 
  int setCursor = 0; //cursor for cableLengthSet and podPoseSet ring buffer
  PVector[] pillarsToCalibrate; //store all pillars coordinates to be calibrated
  float minVariation = 400; //minimum length variation to add new sample to sets, in pixels
  double epsilon = 0.0001; //epsilon value for partial derivative computation, value is in pixel so far
  float alpha = 0.1; //rate of gradient descent convergence
  int nbGradientDescentStep = 20; //number of gradient descent steps for each optimization step
  PVector pod = new PVector(); //coordinates of predicted pod position from calibration dataset
  color CalibratorColor = color(0, 100, 220); //color of calibrated data drawing

  Calibrator(float[] initialcableLengthData, float z) {
    this.init_height = z;
    int n = initialcableLengthData.length;
    this.initValues = new float[n];
    arrayCopy(initialcableLengthData, this.initValues);
    this.minVariation = maxFloatValue(initialcableLengthData)/5;
    this.cableLengthSet = new float[this.maxSet][n];
    this.podPoseSet = new PVector[this.maxSet];
    this.pod = new PVector(0, 0, this.init_height);
    for (int i=0; i<this.maxSet; i++) {
      this.cableLengthSet[i] = initialcableLengthData;
      this.podPoseSet[i] = this.pod.copy();
    }


    //spread initial pillars coordinates in each direction from measurement amount
    this.pillarsToCalibrate = new PVector[n];
    this.reset();
  }



  //add a new sample cableLengthData measures in the sample list
  void addSample(float[] length_measures, PVector pose) {
    int last_cursor = (this.setCursor+this.maxSet-1)%this.maxSet;
    PVector pod_eval = podFromcableLengthDataMeasures(this.cableLengthSet[last_cursor], this.pillarsToCalibrate);
    //only add sample if pod differes from last pod by at least minVariation amount
    if ( pod_eval.sub(this.pod).mag() > this.minVariation) { 
      this.cableLengthSet[this.setCursor] = length_measures;
      this.podPoseSet[this.setCursor] = pose.copy();
      this.setCursor +=1;
      this.setCursor %= this.maxSet;
    }
  }

  //evaluation function for gradient descent algorithm
  float costFunction() {
    float error=0;
    PVector[] myPillars = this.pillarsToCalibrate;
    int n=this.setCursor % this.maxSet+1;
    int m=this.pillarsToCalibrate.length; //length must be >= 4
    for (int i=0; i<n; i++) { //compute error over all samples
      PVector podPrediction = podFromcableLengthDataMeasures(this.cableLengthSet[i], myPillars);
      for (int j=0; j<m; j++) {
        float Lij = podPrediction.copy().sub(myPillars[j]).mag();
        float realLij = this.cableLengthSet[i][j];
        error += sq(Lij - realLij);
        if (podPrediction.z<0) error+=sq(podPrediction.z); //pod cannot have negative z coordinate
        if (podPrediction.z>maxZcoordinates(myPillars)) error+= sq(podPrediction.z - maxZcoordinates(myPillars)); // pod cannot be higher than pillars
      }
    }
    error/=2 * n;
    return error;
  }

  //gradient of evalution function
  PVector[] costFunctionGradient() {
    float fxyz = this.costFunction(); 
    PVector[] gradient = new PVector[0];
    //println("cost criteria : " +fxyz);
    //compute partial derivatives for each pillar
    for (PVector vect : this.pillarsToCalibrate) {
      double dfx, dfy, dfz;
      vect.x += epsilon;
      dfx = (this.costFunction() - fxyz)/this.epsilon;
      vect.x -= epsilon;
      vect.y += epsilon;
      dfy = (this.costFunction() - fxyz)/this.epsilon;
      vect.y -= epsilon;
      dfz = 0 ;  //(this.costFunction() - fxyz)/this.epsilon; assume that all pillars are at the same height
      gradient = (PVector[]) append(gradient, new PVector((float) dfx, (float) dfy, (float) dfz));
    }
    return gradient;
  }

  void optimizationStep() {
    int n = this.pillarsToCalibrate.length;
    PVector[] gradient = new PVector[n];

    for (int i= 0; i<this.nbGradientDescentStep; i++) {
      gradient = costFunctionGradient();
      //correction step : params -= alpha * gradient
      for (int j = 1; j<n; j++) { //fix first pillar coordinates 
        gradient[j].mult(this.alpha);
        this.pillarsToCalibrate[j].sub(gradient[j]);
      }
      this.pillarsToCalibrate[1].y += gradient[1].y; //fix 2nd pillar y coordinate
    }

    //center pillars x y coordinates around origin
    centerVectorArray(this.pillarsToCalibrate);
  }

  void reset() {
    int n = this.initValues.length;
    for (int i=0; i<this.maxSet; i++) {
      this.cableLengthSet[i] = this.initValues;
      this.podPoseSet[i] = this.pod.copy();
    }
    for (int i=0; i<n; i++) { 
      this.pillarsToCalibrate[i] = PVector.fromAngle(TWO_PI * i/n);
      this.pillarsToCalibrate[i].mult(this.initValues[i]).add(new PVector(0, 0, this.init_height));
    }
    alignAccordingToFstEdge(this.pillarsToCalibrate); //align and center initial pillars coordinates prediction to match ground truth convergence
  }

  void processData(float[] cableLengthData) {
    //update pod predicted location
    this.pod = podFromcableLengthDataMeasures(cableLengthData, this.pillarsToCalibrate);

    //draw sample poses and calibrate only if calibrator is running 
    myCalibrator.addSample(cableLengthData, this.pod);
    myCalibrator.optimizationStep();
    //draw ground truth pod poses used to record cableLengthData measures
    stroke(this.CalibratorColor);
    strokeWeight(5);
    for (PVector pose : this.podPoseSet) {
      point(pose.x, pose.y, pose.z);
    }
  }

  void drawCalibration() {
    //draw pod
    strokeWeight(1);
    stroke(this.CalibratorColor);
    strokeWeight(10);
    point(this.pod.x, this.pod.y, this.pod.z);
    strokeWeight(1);

    //draw pillars under calibration
    stroke(this.CalibratorColor);
    PVector[] pillars=this.pillarsToCalibrate;
    int n = pillars.length;
    for (int i=0; i<n; i++) {
      if (i>1)stroke(color(200, 0, 200));
      strokeWeight(3);
      line(pillars[i].x, pillars[i].y, pillars[i].z, pillars[i].x, pillars[i].y, 0); 
      strokeWeight(1);
      line(pillars[i].x, pillars[i].y, pillars[i].z, this.pod.x, this.pod.y, this.pod.z); //lines between pillars and pod
    }

  }
}