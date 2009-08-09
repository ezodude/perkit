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
#define volumeControl 5

#define minPotValue 0
#define maxPotValue 1023
#define minVolume 0
#define maxVolume 10

int playerStatus = stopped;
int rxByte= -1;

int lastOnOffSwitchState = 0;
int onOffSwitchState = 0;

int lastVolume = 0;
float rawVolumeSmoothed;
boolean initialVolumeAdjustment = true;

int lastSkipSwitchState = 0;
int skipSwitchState = 0;

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
  rawVolumeSmoothed = analogRead(volumeControl);
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
      monitor_volume();
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

void monitor_volume() {
  int rawVolume = analogRead(volumeControl);
  rawVolumeSmoothed = 0.75f * rawVolumeSmoothed + 0.25f * rawVolume;
  
  int newVolume = map(rawVolumeSmoothed, minPotValue, maxPotValue, minVolume, maxVolume);
  if(initialVolumeAdjustment || newVolume != lastVolume){
    Serial.print("V.");
    Serial.println(newVolume);
    lastVolume = newVolume;
    initialVolumeAdjustment = false;
  }
}

void monitor_skip() {
  Serial.println("");
  Serial.print("skipSwitchState: ");
  Serial.println(skipSwitchState);
  Serial.println("");
  if(skipSwitchState == HIGH) Serial.println("N");
}

void setLED(){
  switch(playerStatus){
    case stopped:
      digitalWrite(stateLED, LOW);
      break;
    case loading:
      blink(stateLED);
      break; 
    case playing:
      digitalWrite(stateLED, HIGH);
  }
}

void blink(int led){
  if(millis() - timeOfLastBlink > blinkInterval){
    timeOfLastBlink = millis();
    ledBlinkState = (ledBlinkState == LOW ? HIGH : LOW);
    digitalWrite(led, ledBlinkState);
  }
}

void debounce(int inputPin, int &pinState, int &lastPinState, long &lastDebounceTime){
  int reading = digitalRead(inputPin);
  if(reading != lastPinState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) pinState = reading;
  lastPinState = reading;
}