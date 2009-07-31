/*
  Perkit - Podcast Enabled Radio Kit
  Language: Wiring/Arduino (pin numbers defined for Arduino)
*/

#define stopped 0
#define downloading 1
#define downloaded 2
#define playerInitiated 3
#define playing 4

#define stateLED 13

#define onOffSwitch 2

int status = stopped;
int rxByte= -1;

int ledBlinkState = 0;
long timeOfLastBlink = 0;
int blinkInterval = 200;

void setup(){
  pinMode(stateLED, OUTPUT);
  pinMode(onOffSwitch, INPUT);
  
  Serial.begin(9600);
}

void loop(){
  Serial.println(status);
  performRadioFunctions();
  setLED();
}

void performRadioFunctions(){
  switch(status){
    case stopped:
      if(digitalRead(onOffSwitch) == HIGH) 
      {
        Serial.println("D");
        status = downloading;
      }
      break;
    case downloading:
      if(digitalRead(onOffSwitch) == LOW) 
      {
        Serial.println("S");
        status = stopped;
      }
      else
      {
        if(Serial.available())
        {
          rxByte = Serial.read();
          if (rxByte == 'C') status = downloaded;
        }
      }
      break; 
    case downloaded:
      Serial.println("I");
      status = playerInitiated;
      break;
    case playerInitiated:
      if(Serial.available())
      {
        rxByte = Serial.read();
        if (rxByte == 'P') status = playing;
      }
      break;
    case playing:
      break;
  }
}

void setLED(){
  switch(status){
    case stopped:
      digitalWrite(stateLED, LOW);
      break;
    case downloading:
      blink(stateLED);
      break; 
    case downloaded:
      blink(stateLED);
      break;
    case playerInitiated:
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