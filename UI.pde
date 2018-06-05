static class UI {
  static State state = State.ZEROING;
  static String stateName = "ZEROING";

  static void updateUserInputs(CameraControlManager mycam, CableBot mybot, boolean isMousePressed) {
    mycam.updateMouse();
    if (isMousePressed) {
      if (mybot.isGrabbed()) {
        PVector mouseCoordInsideShape = mybot.footprint.getClosestPointInsideShape(mycam.mouseOnGroundPlane);
        PVector newgoal = new PVector(mouseCoordInsideShape.x, mouseCoordInsideShape.y, mybot.pod.getGoalCoordinates().z);
        mybot.pod.setGoalCoordinates(newgoal);
        if (SerialBridge.myPort == null) { 
          mybot.pod.setPresentCoordinates(mybot.pod.getGoalCoordinates());
          mybot.setPresentLengthFromPod();
        }
      } else {
        mycam.updateOrbitAngle();
      }
    }
    mycam.updateCamera();
  }

  static void updateBotOutput(CableBot mybot, Calibrator calibrator) {
    switch (UI.state) {
    case ZEROING :
      UI.stateName = "ZEROING";
      if (mybot.setZeroingActuators(T0)) UI.state = State.COMPLIANT;
      break;
    case COMPLIANT :
      UI.stateName = "COMPLIANT";
      mybot.setCompliantActuators();
      calibrator.spreadWinchesCoord();
      break;
    case CALIBRATION :
      UI.stateName = "CALIBRATION";
      mybot.setCompliantActuators();
      calibrator.addSample();
      calibrator.drawSamples();
      calibrator.drawCostValue();
      calibrator.optimize();
      break;
    case OPERATION :
      UI.stateName = "OPERATION";
      break;
    }
  }

  static void mousePressedCallback(CameraControlManager mycam, CableBot mybot) {
    mycam.lastMouseClickedXY = mycam.mouseXY.copy();
    if (mybot.isPointOverGrabber(mycam.mouseOnGroundPlane)) {
      mybot.grabPod();
    }
  }

  static void mouseReleasedCallback(CameraControlManager mycam, CableBot mybot) {
    if (mybot.isGrabbed()) {
      mybot.pod.grabber.setGrab(false);
    } else {
      mycam.updateLastMouseReleased();
    }
  }

  static void mouseWheelCallback(CameraControlManager mycam, CableBot mybot, int wheelcount) {
    if (mybot.isPointOverGrabber(mycam.mouseOnGroundPlane)) {
      mybot.pod.offsetGoalZ(wheelcount);
      if (SerialBridge.myPort == null) { 
        mybot.pod.setPresentCoordinates(mybot.pod.getGoalCoordinates());
        mybot.setPresentLengthFromPod();
      }
    } else {
      mycam.orbitRadius += wheelcount;
    }
  }

  static void keyPressedCallback() {
    switch (UI.state) {
    case ZEROING :
      UI.state = State.COMPLIANT;
      break;
    case COMPLIANT :
      UI.state = State.CALIBRATION;
      break;
    case CALIBRATION :
      UI.state = State.OPERATION;
      break;
    case OPERATION :
      break;
    }
  }
  
}

void drawInfo(String str) {
  pushMatrix();
  textAlign(LEFT);
  fill(100, 100, 100);
  textSize(TEXT_SIZE/2);
  camera();
  text(str, 0, TEXT_SIZE);
  popMatrix();
}
