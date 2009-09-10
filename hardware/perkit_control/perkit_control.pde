/*
  Perkit - Podcast Enabled Radio Kit
  Language: Wiring/Arduino (pin numbers defined for Arduino)
*/

#include <string.h>
#include "NewSoftSerial.h"
#include "AF_XPort.h"

#define STOPPED 0
#define CONNECTED 1
#define SKIPPING_TO_PODCAST_CONTENT_START 2
#define PODCAST_CONTENT_AT_START 3
#define PODCAST_STORAGE_READY 4
#define PODCAST_BUFFERING_STARTED 5
#define PLAYING 6

#define STATE_LEDPIN 13

#define ONOFF_SWITCHPIN 11
#define SKIP_SWITCHPIN 12

#define XPORT_CTSPIN 2
#define XPORT_DTRPIN 3
#define XPORT_RESETPIN 4
#define XPORT_RXPIN 5
#define XPORT_TXPIN 6

#define UMP3_RXPIN 8
#define UMP3_TXPIN 9

AF_XPort xport = AF_XPort(XPORT_RXPIN, XPORT_TXPIN, XPORT_RESETPIN, XPORT_DTRPIN, 0, XPORT_CTSPIN);
NewSoftSerial uMp3(UMP3_RXPIN, UMP3_TXPIN);

// xport variables
#define HOSTNAME "audio.theguardian.tv" //hardcoded for now
#define IPADDR "93.188.128.18"          // audio.theguardian.tv
#define PORT 80                         // HTTP
// #define HTTPPATH "/audio/kip/standalone/environment/1245927728119/7650/gdn.sci.090625.tm.Chris-Rapley2.mp3" // Hardcoded 6 mins Podcast
#define HTTPPATH "/audio/kip/standalone/sport/1247769014633/2992/gdn.spo.ps.090716.ashes.mp3" // Hardcoded 2 mins Podcast
#define BUFFER_SIZE 256
#define READ_MAX_LENGTH (BUFFER_SIZE - 1)
#define READ_TIMEOUT 1000

// uMp3 module variables
#define ESC 27    //ascii code for escape
#define CARROT 62 //ascii code for >

#define PODCAST_STREAMING_MIN_SIZE 64000 // 7.5 seconds of content

int kitStatus = STOPPED;

char linebuffer[BUFFER_SIZE]; // data buffer
long podcastSize;
long podcastContentSizeSoFar;

boolean startKit;
boolean podcastPlaying;

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
  pinMode(STATE_LEDPIN, OUTPUT);
  pinMode(ONOFF_SWITCHPIN, INPUT);
  pinMode(SKIP_SWITCHPIN, INPUT);
  
/*  xport.begin(115200);
  uMp3.begin(115200);
  Serial.begin(115200);*/

  xport.begin(57600);
  uMp3.begin(57600);
  Serial.begin(57600);
  
  startKit = false;
  podcastPlaying = false;
  skipped = false;
}

void loop(){
  if(Serial.available() && Serial.read() == 'S'){
    startKit = true;
  }
  
  if(Serial.available() && Serial.read() == 'D'){
    Serial.println("Disconnected!");
    startKit = false;
  }
  
  debounce(ONOFF_SWITCHPIN, onOffSwitchState, lastOnOffSwitchState, onOffSwitchLastDebounceTime);
  debounce(SKIP_SWITCHPIN, skipSwitchState, lastSkipSwitchState, skipSwitchLastDebounceTime);
  detectStopEvent();
  performRadioFunctions();
  setLED();
}

void detectStopEvent(){
/*  if(onOffSwitchState == LOW && kitStatus != STOPPED){*/
  if(!startKit){
    kitStatus = STOPPED;
  }
}

void performRadioFunctions(){
  switch(kitStatus){
    case STOPPED:
      startConnectingToDeliveryService();
      break;
    case CONNECTED:
      requestPodcastContent();
      break;
    case SKIPPING_TO_PODCAST_CONTENT_START:
      skipToPodcastContentStart();
      break;
    case PODCAST_CONTENT_AT_START:
      initialiseUMp3();
      break;
    case PODCAST_STORAGE_READY:
      startPodcastContentBuffering();
      break;
    case PODCAST_BUFFERING_STARTED:
      bufferAndPlayPodcastContent();
      if(podcastPlaying) monitor_skip();
    case PLAYING:
      bufferAndPlayPodcastContent();
      monitor_skip();
  }
}

void startConnectingToDeliveryService(){
/*  if(onOffSwitchState == HIGH){*/
  if(startKit){
    Serial.println("Kit Started!");
    uint8_t connected = connectToDeliveryService();
    if(connected) kitStatus = CONNECTED;
  }
}

uint8_t connectToDeliveryService(){
  Serial.println("Attempting to connect to server...");
  
  uint8_t reset = xport.reset();
  switch (reset) {
    case ERROR_NONE: { 
     Serial.println("  Xport reset OK!");
     break;
    }
    case  ERROR_TIMEDOUT: { 
        Serial.println("  Timed out while resetting xport!"); 
        return 0;
     }
     case ERROR_BADRESP:  { 
        Serial.println("  Bad response while resetting xport!");
        return 0;
     }
     default:
       Serial.println("  Unknown error while resetting xport!"); 
       return 0;
  }
    
  uint8_t connected = xport.connect(IPADDR, PORT);
  switch (connected) {
    case ERROR_NONE: { 
     Serial.println("  Connected OK!");
     break;
    }
    case  ERROR_TIMEDOUT: { 
        Serial.println("  Timed out on connecting!"); 
        return 0;
     }
     case ERROR_BADRESP:  { 
        Serial.println("  Bad response on connecting!");
        return 0;
     }
     default:
       Serial.println("  Unknown error while connecting!"); 
       return 0;
  }
  return 1;
}

void requestPodcastContent(){
  
  //xport.get(HTTPPATH, HOSTNAME);
  Serial.println("Attempting to requst podcast content from server...");
  xport.print("GET "); 
  xport.print(HTTPPATH); 
  xport.println(" HTTP/1.1"); 
  
  xport.print("Host: ");
  xport.print(HOSTNAME);
  xport.println("\r\n");

  Serial.println("Attempting to read after connection (LAST RUN 3 MINS FOR 2 MIN PODCAST GET REQUEST)...");
  xport.readline_timeout(linebuffer, 255, 3000);
  Serial.print("Read: ["); Serial.print(linebuffer); Serial.println("]");
  
  if(strstr(linebuffer, "HTTP/1.1 200 OK") == linebuffer)
    kitStatus = SKIPPING_TO_PODCAST_CONTENT_START; 
  else
   kitStatus = STOPPED;
}

void skipToPodcastContentStart(){
  Serial.println("Attempting to skip podcast Start...");
  xport.readline_timeout(linebuffer, READ_MAX_LENGTH, 3000);
  Serial.print("Read: ["); Serial.print(linebuffer); Serial.println("]");
  
/*  if(strlen(linebuffer) == 0)*/  
  if((strlen(linebuffer) == 1 && linebuffer[0] == '\n') || 
    (strlen(linebuffer) == 2 && linebuffer[1] == '\r' && linebuffer[1] == '\n'))
    kitStatus = PODCAST_CONTENT_AT_START;
}

void initialiseUMp3(){
  Serial.println("Attempting to initialise uMp3...");
  uMp3.println(ESC, BYTE);
  if(foundUMp3Carrot()) 
    kitStatus = PODCAST_STORAGE_READY;
}

uint8_t foundUMp3Carrot(){
  if(uMp3.available())
    if(CARROT == uMp3.read()){
      return 1;
    }
    else{
      uMp3.flush();
      return 0;
    }
}

void bufferPodcastContent(){
  xport.readline_timeout(linebuffer, READ_MAX_LENGTH, 3000);
  uint8_t numberOfBytesToWrite = strlen(linebuffer);
  
  uMp3.print("FC W 1 ");
  uMp3.print(numberOfBytesToWrite, DEC);
  uMp3.print("\r");
  uMp3.print(linebuffer);
  uMp3.flush();
  delay(50); //wait for a ms
  
  podcastContentSizeSoFar += numberOfBytesToWrite;
}

void startPodcastContentBuffering(){
  Serial.println("Opening [/PODCAST.MP3] for appending...");
  uMp3.print("FC O 1 A /PODCAST.MP3\r");
  uMp3.flush();
  delay(5);
  
  if(foundUMp3Carrot()){
    Serial.println("Buffering [/PODCAST.MP3] for appending...");
    bufferPodcastContent();
    kitStatus = PODCAST_BUFFERING_STARTED;
  }
}

void bufferAndPlayPodcastContent(){
  if(foundUMp3Carrot()){
    
    bufferPodcastContent();
    
    if(foundUMp3Carrot() && !podcastPlaying && podcastContentSizeSoFar > PODCAST_STREAMING_MIN_SIZE){
      Serial.println("Attempting to play [/PODCAST.MP3]");
      uMp3.print("PC F /PODCAST.MP3\r");
      uMp3.flush();
      delay(5);
      if(foundUMp3Carrot()) podcastPlaying = true;
    }
    
    if(podcastContentSizeSoFar >= 4118322)
    {
      Serial.println("Closing file [/PODCAST.MP3]...");
      uMp3.println("FC C 1");
      uMp3.flush();
      xport.flush(100);
      kitStatus = PLAYING;
    }
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
  switch(kitStatus){
    case STOPPED:
      digitalWrite(STATE_LEDPIN, LOW);
      break;
    case CONNECTED:
      blinkStateLED();
      break; 
    case PLAYING:
      digitalWrite(STATE_LEDPIN, HIGH);
  }
}

void blinkStateLED(){
  if(millis() - timeOfLastBlink > blinkInterval){
    timeOfLastBlink = millis();
    ledBlinkState = (ledBlinkState == LOW ? HIGH : LOW);
    digitalWrite(STATE_LEDPIN, ledBlinkState);
  }
}

void debounce(int inputPin, int &pinState, int &lastPinState, long &lastDebounceTime){
  int reading = digitalRead(inputPin);
  if(reading != lastPinState) lastDebounceTime = millis();
  if ((millis() - lastDebounceTime) > debounceDelay) pinState = reading;
  lastPinState = reading;
}