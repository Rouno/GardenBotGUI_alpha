/*
 * calibration class and utility functions to calibrate pillars coordinates
 * with gradient descent method
 */

final float MAX_GRADIENT_AMP = 200;

class Calibrator {
  float[] initValues; //store initial measurement values for reset function
  float init_height;
  float[][] cableLengthSet; //set of pillars lengths samples for calibration
  int maxSet = 50; //maximum number of samples for gradient descent 
  int setCursor = 0; //cursor for cableLengthSet ring buffer
  PVector[] pillarsToCalibrate; //store all pillars coordinates to be calibrated
  float minVariation = 200; //minimum length variation to add new sample to sets, in pixels
  float epsilon = 0.001; //epsilon value for partial derivative computation, value is in pixel so far
  float alpha = 0.1; //rate of gradient descent convergence
  int nbGradientDescentStep = 20; //number of gradient descent steps for each optimization step
  ReactShape footprint;
  PVector pod = new PVector(); //coordinates of predicted pod position from calibration dataset
  color CalibratorColor = color(0, 100, 220); //color of calibrated data drawing

  Calibrator(float[] initialcableLengthData, float z) {
    this.init_height = z;
    int n = initialcableLengthData.length;
    this.initValues = new float[n];
    arrayCopy(initialcableLengthData, this.initValues);
    this.minVariation = maxFloatValue(initialcableLengthData)/5;
    //this.cableLengthSet = new float[this.maxSet][n];
    this.pod = new PVector(0, 0, this.init_height);
    //this.cableLengthSet[0] = initialcableLengthData;
    //println(this.cableLengthSet[0]);
    /*for (int i=0; i<this.maxSet; i++) {
     this.cableLengthSet[i] = initialcableLengthData;
     }
     */

    //spread initial pillars coordinates in each direction from measurement amount
    this.pillarsToCalibrate = new PVector[n];
    this.reset(this.initValues);
    this.footprint = new ReactShape(this.pillarsToCalibrate);
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
    int n=this.cableLengthSet.length;
    int m=this.pillarsToCalibrate.length; //length must be >= 4
    for (float[] sample : this.cableLengthSet) {
      //for (int i=0; i<n; i++) { //compute error over all samples
      PVector podPrediction = podFromcableLengthDataMeasures(sample, myPillars);
      for (int j=0; j<m; j++) {
        //float[] cableLengthForPrediction = shortenByIndex(this.cableLengthSet[i], j);
        //PVector[] pillarsForPrediction = shortenByIndex(myPillars, j);

        float Lij = podPrediction.copy().sub(myPillars[j]).mag();
        float realLij = sample[j];
        error += sq(Lij - realLij);

        //error+= sq(podPrediction.z - maxZcoordinates(myPillars)); // pod cannot be higher than pillars
      }
      error += sq(this.footprint.getClosestPointInsideShape(podPrediction).dist(podPrediction));
    }
    error/=2 * n;
    return error;
  }

  //gradient of evalution function
  PVector[] costFunctionGradient() {
    float fxyz = this.costFunction(); 
    PVector[] gradient = new PVector[0];
    println("cost criteria : " +fxyz);
    //compute partial derivatives for each pillar
    for (PVector vect : this.pillarsToCalibrate) {
      float dfx, dfy, dfz;
      vect.x += epsilon;
      dfx = constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP, MAX_GRADIENT_AMP);
      vect.x -= epsilon;
      vect.y += epsilon;
      dfy = constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP, MAX_GRADIENT_AMP);
      vect.y -= epsilon;
      dfz = 0; //constrain((this.costFunction() - fxyz)/this.epsilon, -MAX_GRADIENT_AMP,MAX_GRADIENT_AMP); //assume that all pillars are at the same height
      gradient = (PVector[]) append(gradient, new PVector(dfx, dfy, dfz));
    }
    return gradient;
  }

  void optimizationStep() {
    int n = this.pillarsToCalibrate.length;
    PVector[] gradient = new PVector[n];
    this.footprint.setShape(this.pillarsToCalibrate);
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

  void reset(float[] initial_values) {
    int n = initial_values.length;
    //this.cableLengthSet = (float[][]) append(this.cableLengthSet, initial_values);
    this.cableLengthSet = new float[1][n];
    this.cableLengthSet[0] = initial_values;
    //println("ceci est la position du curseur sur le tableau des echantillons " + this.setCursor);
    /*for (int i=0; i<this.maxSet; i++) {
     this.cableLengthSet[i] = this.cableLengthSet[this.setCursor];
     }*/
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
    //println(this.cableLengthSet.length);
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