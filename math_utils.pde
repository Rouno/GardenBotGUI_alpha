

//Compute pod 3d position from cableLengthData measurements and, takes only 3 points and 3 distances
//from https://en.wikipedia.org/wiki/Trilateration
PVector podFromcableLengthDataMeasures(float[] measures, PVector[] P1P2P3) {
  float r1 = measures[0];
  float r2 = measures[1];
  float r3 = measures[2];
  PVector P1, P2, P3, P1P2, P1P3 = new PVector();

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
  if (r1*r1 - x*x - y*y >=0 ) {
    z = - sqrt(r1*r1 - x*x - y*y);
    result = P1.add(Ex.mult(x)).add(Ey.mult(y)).add(Ez.mult(z));
  } else {
    //if 3 spheres intersection has no solution, grab closest solution following Al Kashi theoreme 
    //http://kuartin.math.pagesperso-orange.fr/theoremealkashi.htm
    float cosalpha = (sq(d)-sq(r2)+sq(r1))/(2*r1*d);
    cosalpha = max(min(cosalpha, 1), -1); //ensure unique cosalpha solution by caping cosalpha between -1 and 1, appears when r1 & r2 cableLengthData cross each others
    float sinalpha = sqrt(1 - sq(cosalpha));
    result = P1.add(Ex.mult(cosalpha*r1).add(Ey.mult(sinalpha*r1)));
  }
  return result;
}

//returns shorten float array by index
float[] shortenByIndex(float[] src, int index) {
  int n = src.length;
  float[] result;
  
  switch(index/n) {
  case 0:
    result = subset(src, 1);
    break;
  case 1:
    result = subset(src, 0, index - 1);
    break;
  default:
    float[] before = subset(src, 0, index-1);
    float[] after= subset(src, index+1, n-1 - index);
    result = concat(before, after);
    break;
  }

  //println(result.length);
  return result;
}

PVector[] shortenByIndex(PVector[] src, int index) {
  int n = src.length;
  PVector[] result;
  
  switch(index/n) {
  case 0:
    result = (PVector[]) subset(src, 1);
    break;
  case 1:
    result = (PVector[]) subset(src, 0, index - 1);
    break;
  default:
    PVector[] before = (PVector[]) subset(src, 0, index-1);
    PVector[] after= (PVector[]) subset(src, index+1, n-1 - index);
    result = (PVector[]) concat(before, after);
    break;
  }
  
  //println(result.length);
  return result;
}

//returns distance between an array and another
float[] absDiffArray(float[] firstArray, float[] secondArray) {
  int n = firstArray.length;
  float[] resultarray = new float[n];
  for (int i=0; i<n; i++) {
    resultarray[i]=abs(firstArray[i]-secondArray[i]);
  }
  return resultarray;
}

//returns sum of array of floats
float sumFloatArray(float[] anArray) {
  float result = 0;
  for (int i=0; i<anArray.length; i++) {
    result += anArray[i];
  }
  return result;
}

//returns mean vector of a PVector array
PVector pvectorMean(PVector[] vector_array) {
  PVector result = new PVector(0, 0, 0);
  for (PVector vect : vector_array) {
    result = result.add(vect);
  }
  result = result.div(vector_array.length);
  return result;
}

//center vector array aouround x & y mean vector
void centerVectorArray(PVector[] vector_array) {
  PVector mean = pvectorMean(vector_array);
  mean.z=0;
  for (PVector vect : vector_array) {
    vect.sub(mean);
  }
}

//align and center a set of PVector according to the first edge along x axis
void alignAccordingToFstEdge(PVector[] vector_to_align) {
  centerVectorArray(vector_to_align);

  PVector Ex = new PVector(1, 0);
  PVector axis_to_align = vector_to_align[1].copy().sub(vector_to_align[0]);
  float angle = PVector.angleBetween(axis_to_align, Ex);
  for (PVector vect : vector_to_align) {
    vect.rotate(-angle);
  }
  axis_to_align = vector_to_align[1].copy().sub(vector_to_align[0]);
}

//returns max over z coordinates of PVector array
float maxZcoordinates(PVector[] vector_array) {
  float result=0; //assume z coordinates >= 0
  for (PVector vect : vector_array) {
    if (vect.z > result) result = vect.z;
  }
  return result;
}

//returns width of the centered rectangle bounding vector_array
float maxWidth(PVector[] vector_array) {
  float max;
  max=0;
  for (PVector vect : vector_array) {
    if (abs(vect.x) > max) max = abs(vect.x);
  }
  return 2*max;
}

//returns height of the centered rectangle bounding vector_array
float maxHeight(PVector[] vector_array) {
  float max;
  max=0;
  for (PVector vect : vector_array) {
    if (abs(vect.y) > max) max = abs(vect.y);
  }
  return 2*max;
}

float maxFloatValue(float[] float_array) {
  float result=0;
  for (float afloat : float_array) {
    if (afloat>result) result=afloat;
  }
  return result;
}

//return an array of n random angles arranged and sorted from 0 to TWO_PI
float[] randomAngles(int n) {
  float[] angle_array = new float[n];
  float sum_array = 0;
  for (int i = 0; i<n; i++) {
    angle_array[i] = 1 + random(1);
    sum_array += angle_array[i];
  }
  for (int i = 0; i<n; i++) {
    angle_array[i] /= sum_array;
    angle_array[i] *= TWO_PI;
    angle_array[i] -= angle_array[0];
    if (i>0)angle_array[i]+=angle_array[i-1];
  }
  printArray(angle_array);
  return angle_array;
}

//return vector array of n random vectors (constant height z, radius: mean & std) sorted by angle 
PVector[] randomVect(int n, float z, float mean, float std_dev) {
  PVector[] vector_array = new PVector[0]; //length of pillars must be >= 4
  float[] angle_array = randomAngles(n);
  for (int i=0; i<nbPillars; i++) {
    vector_array = (PVector[]) append(vector_array, new PVector());
    vector_array[i] = PVector.fromAngle(angle_array[i]); //vector_array[i] = PVector.fromAngle(TWO_PI * i/n);
    vector_array[i].mult(random(mean*std_dev)+mean*(1-std_dev));
    vector_array[i].add(new PVector(0, 0, z));
  }
  return vector_array;
}