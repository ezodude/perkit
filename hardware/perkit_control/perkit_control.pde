/*
  Perkit - Podcast Enabled Radio Kit
  Language: Wiring/Arduino (pin numbers defined for Arduino)
*/

#define stopped 0
#define loading 1
#define playing 2

#define stateLED 13

#define onOffSwitch 2
#define skipSwitch 4

int playerStatus = stopped;
int rxByte= -1;

int lastOnOffSwitchState = 0;
int onOffSwitchState = 0;

int lastSkipSwitchState = 0;
int skipSwitchState = 0;
int skipTolerance = 275;
long lastSkipTime = 0;
boolean skipped;

long debounceDelay = 200;
long onOffSwitchLastDebounceTime = 0;
long skipSwitchLastDebounceTime = 0;

int ledBlinkState = 0;
long timeOfLastBlink = 0;
int blinkInterval = 200;

void debounce(int inputPin, int &pinState, int &lastPinState, long &lastDebounceTime);

void setup(){
  pinMode(stateLED, OUTPUT);
  pinMode(onOffSwitch, INPUT);
  pinMode(skipSwitch, INPUT);
  
  Serial.begin(9600);
  skipped = false;
}

void loop(){
  debounce(onOffSwitch, onOffSwitchState, lastOnOffSwitchState, onOffSwitchLastDebounceTime);
  debounce(skipSwitch, skipSwitchState, lastSkipSwitchState, skipSwitchLastDebounceTime);
  detectStopEvent();
  performRadioFunctions();
  setLED();
}

void detectStopEvent(){
  if(onOffSwitchState == LOW && playerStatus != stopped){
    Serial.println("S");
    playerStatus = stopped;
  }
}

void performRadioFunctions(){
  switch(playerStatus){
    case stopped:
      startLoadingAPodcast();
      break;
    case loading:
      detectIsPlaying();
      break;
    case playing:
      monitor_skip();
  }
}

void startLoadingAPodcast(){
  if(onOffSwitchState == HIGH){
    Serial.println("L");
    playerStatus = loading;
  }
}

void detectIsPlaying(){
  if(Serial.available()){
    rxByte = Serial.read();
    if (rxByte == 'P') playerStatus = playing;
  }
}

void monitor_skip() {
  if(skipSwitchState == HIGH && skipped == false){
    skipped = true;
    Serial.println("N");
    lastSkipTime = millis();
  }
  determineSkipReset();
}

void determineSkipReset(){
  if(skipped && skipSwitchState == LOW && (millis() - lastSkipTime > skipTolerance)) skipped = false;
}

void setLED(){
  switch(playerStatus){
    case stopped:
      digitalWrite(stateLED, LOW);
      break;
    case loading:
      blinkStateLED();
      break; 
    case playing:
      digitalWrite(stateLED, HIGH);
  }
}

void blinkStateLED(){
  if(millis() - timeOfLastBlink > blinkInterval){
    timeOfLastBlink = millis();
    ledBlinkState = (ledBlinkState == LOW ? HIGH : LOW);
    digitalWrite(stateLED, ledBlinkState);
  }
}

void debounce(int inputPin, int &pinState, int &lastPinState, long &lastDebounceTime){
  int reading = digitalRead(inputPin);
  if(reading != lastPinState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) pinState = reading;
  lastPinState = reading;
}