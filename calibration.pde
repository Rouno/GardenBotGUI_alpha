/*
 * calibration class and utility functions to calibrate pillars coordinates
 * with gradient descent method
 */

final float MAX_GRADIENT_AMP = 100;

class Calibrator {
  float init_height;
  float[][] cableLengthSet; //set of pillars lengths samples for calibration
  int maxSet = 40; //maximum number of samples for gradient descent 
  PVector[] pillarsToCalibrate; //store all pillars coordinates to be calibrated
  float minVariation; //minimum length variation to add new sample to sets, in pixels
  float epsilon = 0.0001; //epsilon value for partial derivative computation, value is in pixel so far
  float alpha = 0.05; //rate of gradient descent convergence
  ReactShape footprint;
  PVector pod = new PVector(); //coordinates of predicted pod position from calibration dataset
  color CalibratorColor = color(0, 100, 220); //color of calibrated data drawing
  float[] errorFactorArray;
  float[] errorFactorEstimationArray;

  Calibrator(float[] initialcableLengthData, float z) {
    this.init_height = z;
    this.minVariation = maxFloatValue(initialcableLengthData)/5;
    this.pod = new PVector(0, 0, this.init_height);
    this.pillarsToCalibrate = new PVector[initialcableLengthData.length];
    this.reset(initialcableLengthData);
    this.footprint = new ReactShape(this.pillarsToCalibrate);
    this.errorFactorArray = new float[initialcableLengthData.length];
    this.errorFactorEstimationArray = new float[initialcableLengthData.length];
    for (int i=0; i<initialcableLengthData.length; i++) {
      this.errorFactorArray[i] = 1 +  randomGaussian()/30;
      this.errorFactorEstimationArray[i] = 1;
    }
  }

  //add a new sample cableLengthData measures in the sample list
  void addSample(float[] length_measures) {
    if (this.cableLengthSet.length >= this.maxSet) {
      this.cableLengthSet = (float[][])shorten(this.cableLengthSet);
    }
    float[][] tmp = new float[1][length_measures.length];
    tmp[0]=length_measures;
    this.cableLengthSet = (float[][]) splice(this.cableLengthSet, tmp, 0);
  }

  //evaluation function for gradient descent algorithm
  float costFunction() {
    float error=0;
    PVector[] myPillars = this.pillarsToCalibrate;
    int m=this.pillarsToCalibrate.length; //length must be >= 4
    for (float[] sample : this.cableLengthSet) {
      PVector[] podPredictionArray = new PVector[myPillars.length];
      for (int j=0; j<m; j++) {
        podPredictionArray[j] = podFromcableLengthDataMeasures(sample, myPillars);
        float Lij = podPredictionArray[j].copy().sub(myPillars[j]).mag();
        float realLij = sample[j] * this.errorFactorArray[j] * this.errorFactorEstimationArray[j];
        float lengthErr = sq(Lij - realLij);
        error += lengthErr;
        if (podPredictionArray[j].z <0) error+= sq(podPredictionArray[j].z);
      }
    }
    error/=2 * this.cableLengthSet.length;
    return error;
  }

  //gradient of evalution function
  PVector[] costFunctionGradient() {
    float fxyz = this.costFunction();
    PVector[] gradient = new PVector[2*this.pillarsToCalibrate.length];
    println("cost criteria : " +fxyz);
    println("error set : ");
    println(errorFactorArray);
    println(" error estimated : ");
    println(errorFactorEstimationArray);
    //compute partial derivatives for each pillar
    for (int i=0; i<this.pillarsToCalibrate.length; i++) {
      float dfx, dfy, dfz, d_errfact;
      this.pillarsToCalibrate[i].x += epsilon;
      dfx = constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP, MAX_GRADIENT_AMP);
      this.pillarsToCalibrate[i].x -= epsilon;
      this.pillarsToCalibrate[i].y += epsilon;
      dfy = constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP, MAX_GRADIENT_AMP);
      this.pillarsToCalibrate[i].y -= epsilon;
      dfz = 0; //constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP,MAX_GRADIENT_AMP); //assume that all pillars are at the same height
      this.errorFactorEstimationArray[i] += epsilon;
      d_errfact = constrain((this.costFunction() - fxyz), -MAX_GRADIENT_AMP, MAX_GRADIENT_AMP);
      this.errorFactorEstimationArray[i] -= epsilon;
      gradient[i] = new PVector(dfx, dfy, dfz);
      gradient[this.pillarsToCalibrate.length + i]= new PVector(d_errfact, 0);
    }
    //println(gradient);
    return gradient;
  }

  void optimizationStep() {
    this.footprint.setShape(this.pillarsToCalibrate);
    int n = this.pillarsToCalibrate.length;
    PVector[] gradient = new PVector[n];
    gradient = costFunctionGradient();
    //correction step : params -= alpha * gradient
    for (int i = 0; i<n; i++) { //fix first pillar coordinates 
      gradient[i].mult(this.alpha);
      this.pillarsToCalibrate[i].sub(gradient[i]);
      this.errorFactorEstimationArray[i] -= epsilon * gradient[i+n].x;
    }
    this.pillarsToCalibrate[0].x += gradient[0].x; //fix 1st pillar x coordinate
    this.pillarsToCalibrate[0].y += gradient[0].y; //fix 1st pillar x coordinate
    this.pillarsToCalibrate[1].y += gradient[1].y; //fix 2nd pillar y coordinate
    //center pillars x y coordinates around origin
    centerVectorArray(this.pillarsToCalibrate);
  }

  void reset(float[] initial_values) {
    int n = initial_values.length;
    this.cableLengthSet = new float[1][n];
    this.cableLengthSet[0] = initial_values;
    for (int i=0; i<n; i++) { 
      this.pillarsToCalibrate[i] = PVector.fromAngle(TWO_PI * i/n);
      this.pillarsToCalibrate[i].mult(this.cableLengthSet[0][i]).add(new PVector(0, 0, this.init_height));
    }
    alignAccordingToFstEdge(this.pillarsToCalibrate); //align and center initial pillars coordinates prediction to match ground truth convergence
  }

  void processData(float[] cableLengthData) {
    //update pod predicted location
    this.pod = podFromcableLengthDataMeasures(cableLengthData, this.pillarsToCalibrate);
    PVector lastPodInSample = podFromcableLengthDataMeasures(this.cableLengthSet[0], this.pillarsToCalibrate);
    if (lastPodInSample.sub(this.pod).mag() > this.minVariation) {
      myCalibrator.addSample(cableLengthData);
    }

    myCalibrator.optimizationStep();
    //draw ground truth pod poses used to record cableLengthData measures
    stroke(this.CalibratorColor);
    strokeWeight(5);
    for (float[] cableLength : this.cableLengthSet) {
      PVector pose = podFromcableLengthDataMeasures(cableLength, this.pillarsToCalibrate);
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