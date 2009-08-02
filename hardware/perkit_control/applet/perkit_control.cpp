/*
  Perkit - Podcast Enabled Radio Kit
  Language: Wiring/Arduino (pin numbers defined for Arduino)
*/

#define stopped 0
#define downloading 1
#define downloaded 2
#define loaded 3
#define playing 4

#define stateLED 13

#define onOffSwitch 2

#include "WProgram.h"
void setup();
void loop();
void detectStopEvent();
void performRadioFunctions();
void startDownload();
void detectCompletedDownload();
void loadDownloadedPodcast();
void detectIsPlaying();
void setLED();
void blink(int led);
int playerStatus = stopped;
int rxByte= -1;

int lastOnOffSwitchState = 0;
int onOffSwitchState = 0;

long lastDebounceTime = 0;
long debounceDelay = 300;   // the debounce time, increase if the output flickers

int ledBlinkState = 0;
long timeOfLastBlink = 0;
int blinkInterval = 200;

void debounce(int inputPin, int &pinState, int &lastPinState);

void setup(){
  pinMode(stateLED, OUTPUT);
  pinMode(onOffSwitch, INPUT);
  
  Serial.begin(9600);
}

void loop(){
  debounce(onOffSwitch, onOffSwitchState, lastOnOffSwitchState);
  detectStopEvent();
  performRadioFunctions();
  setLED();
}

void detectStopEvent(){
  if(onOffSwitchState == LOW && playerStatus != stopped) 
  {
    Serial.println("S");
    playerStatus = stopped;
  }
}

void performRadioFunctions(){
  switch(playerStatus){
    case stopped:
      startDownload();
      break;
    case downloading:
      detectCompletedDownload();
      break; 
    case downloaded:
      loadDownloadedPodcast();
      break;
    case loaded:
      detectIsPlaying();
      break;
    case playing:
      break;
  }
}

void startDownload(){
  if(onOffSwitchState == HIGH) 
  {
    Serial.println("D");
    playerStatus = downloading;
  }
}

void detectCompletedDownload()
{
  if(Serial.available())
  {
    rxByte = Serial.read();
    if (rxByte == 'C') playerStatus = downloaded;
  }
}

void loadDownloadedPodcast()
{
  Serial.println("L");
  playerStatus = loaded;
}

void detectIsPlaying(){
  if(Serial.available())
  {
    rxByte = Serial.read();
    if (rxByte == 'P') playerStatus = playing;
  }
}

void setLED(){
  switch(playerStatus){
    case stopped:
      digitalWrite(stateLED, LOW);
      break;
    case downloading:
      blink(stateLED);
      break; 
    case downloaded:
      blink(stateLED);
      break;
    case loaded:
      blink(stateLED);
      break;
    case playing:
      digitalWrite(stateLED, HIGH);
  }
}

void blink(int led){
  if(millis() - timeOfLastBlink > blinkInterval)
  {
    timeOfLastBlink = millis();
    ledBlinkState = (ledBlinkState == LOW ? HIGH : LOW);
    digitalWrite(led, ledBlinkState);
  }
}

void debounce(int inputPin, int &pinState, int &lastPinState){
  int reading = digitalRead(inputPin);
  if(reading != lastPinState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) pinState = reading;
  lastPinState = reading;
}

int main(void)
{
	init();

	setup();
    
	for (;;)
		loop();
        
	return 0;
}

