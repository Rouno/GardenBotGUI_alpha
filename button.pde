  /* 
    a square button class for the interface
  */
  
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