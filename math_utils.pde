

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

//returns distanc between an array and another
float[] absDiffArray(float[] firstArray, float[] secondArray){
  int n = firstArray.length;
  float[] resultarray = new float[n];
  for(int i=0; i<n;i++){
    resultarray[i]=abs(firstArray[i]-secondArray[i]);
  }
  return resultarray;
}

//returns sum of array of floats
float sumFloatArray(float[] anArray){
  float result = 0;
  for(int i=0; i<anArray.length; i++){
    result += anArray[i];
  }
  return result;
}

//returns mean vector of a PVector array
PVector pvectorMean(PVector[] vector_array){
  PVector result = new PVector(0,0,0);
  for(PVector vect : vector_array){
    result = result.add(vect);
  }
  result = result.div(vector_array.length);
  return result;
}

//align and center a set of PVector according to the first edge along x axis
void alignAccordingToFstEdge(PVector[] vector_to_align){
  PVector Ex = new PVector(-1,0);
  PVector axis_to_align = vector_to_align[1].copy().sub(vector_to_align[0]);
  float angle = PVector.angleBetween(Ex, axis_to_align);
  for(PVector vect : vector_to_align){
    vect.rotate(angle);
  }
  PVector mean=pvectorMean(vector_to_align);
  mean.z = 0;
  for(PVector vect : vector_to_align){
    vect.sub(mean);
  }
}

//returns max over z coordinates of PVector array
float maxZcoordinates(PVector[] vector_array){
  float result=0; //assume z coordinates >= 0
  for(PVector vect : vector_array){
    if(vect.z > result) result = vect.z;
  }
  return result;
}

//returns width of the centered rectangle bounding vector_array
float maxWidth(PVector[] vector_array){
  float max;
  max=0;
  for(PVector vect : vector_array){
    if(abs(vect.x) > max) max = abs(vect.x);
  }
  return 2*max;
}

//returns height of the centered rectangle bounding vector_array
float maxHeight(PVector[] vector_array){
  float max;
  max=0;
  for(PVector vect : vector_array){
    if(abs(vect.y) > max) max = abs(vect.y);
  }
  return 2*max;
}