#include <WaspWIFI_PRO.h>
#include <WaspSensorGas_Pro.h>
#include <WaspFrame.h>


// gas and meteo sensor classes
Gas O3(SOCKET_A);
Gas NO2(SOCKET_B);
Gas meteo(SOCKET_E);

// initialize variables
//uint8_t isdir;
//uint8_t dummy;
uint8_t sd_answer;

//unsigned long machID;
uint8_t error;
uint8_t status;
uint16_t socket_handle = 0;
//unsigned long previous;

char file[50];
char fpath[200];
char tmppath[200];
char arcpath[200];
// buffer to write into Sd File
char toWrite[250];

uint8_t res;
float temperature;
float humidity;
float pressure;
float tempO3;
float tempNO2;
float NO2_conc;
float O3_conc;
float diskSize;

char ESSID[] = "[ESSID]";
char pass[] = "[Pass]";

// choose TCP server settings
char HOST[]        = "[x.x.x.x]";
char REMOTE_PORT[] = "[port]";
char LOCAL_PORT[]  = "[port]";
///////////////////////////////////////


void setup()
{

 // open USB port
 USB.ON();
 // open RTC 
 RTC.ON();

 //// Setting the Wifi //////////
 USB.println(F("1. Setting up Wifi"));
 WIFI_PRO.ON(SOCKET0);
 WIFI_PRO.setESSID(ESSID);
 WIFI_PRO.setPassword(WPA2,pass);
 WIFI_PRO.softReset();
 // SYNCHRONIZE RTC TIME WITH WEB
 WIFI_PRO.setTimeServer(1, "ntp.grnet.gr");
 WIFI_PRO.setTimeServer(2, "hercules.eim.gr");
 WIFI_PRO.timeActivationFlag(true);
 //WIFI_PRO.setGMT(3);
 WIFI_PRO.setTimeFromWIFI();
// WIFI_PRO.OFF(SOCKET0);
 ///// WIFI END //////

 //// POWER ON SENSORS ////
 O3.ON();
 NO2.ON();
 meteo.ON();

 SD.ON();
 status = SD.mkdir("TEMP");
 status = SD.mkdir("ARCH");
 
 // SET WATCHDOG FOR PRECAUTION ////
// RTC.setWatchdog(10);
}


void loop()
{
  //USB.ON();
  WIFI_PRO.ON(SOCKET0);
  O3.ON();
  NO2.ON();
  meteo.ON();
  // check connectivity
  status =  WIFI_PRO.isConnected();
  if( status == true )
  { 
    USB.print(F("2. WiFi is connected OK"));
  }
  if( status == false )
  {
    // Turn ON WIFI //
    WIFI_PRO.ON(SOCKET0);
  }

  status =  WIFI_PRO.isConnected();
  if( status == true )
  { 
    USB.print(F("2. WiFi is connected OK"));
  }

////// TAKE MEASUREMENTS //////////////////////////////////
    
  // Reads the temperature sensor from the O3 AFE
  tempO3 = O3.getTemp(0);
  // Reads the temperature sensor from the NO2 AFE
  tempNO2 = NO2.getTemp(0);
  // Reads the BME280 sensor
  temperature = meteo.getTemp(1);
  // Reads the environmetal humidity from BME280 sensor
  humidity = meteo.getHumidity();
  // Reads the environmetal pressure from BME280 sensor
  pressure = meteo.getPressure();

  // Read NO2 concentration with ultra high resolution (18 bits)
  res = MCP3421_ULTRA_HIGH_RES ;
  NO2_conc = NO2.getConc(res);

  // Read O3 concentration with ultra high resolution (18 bits) and cross-reactivity correction
  O3_conc = O3.getConc(res, temperature, NO2_conc);
/////////////////////////////////////////////////////////

//////////// FILENAME FOR ARCHIVE ///////////////////////
  sprintf(tmppath,"TEMP/20%02d",RTC.year);
  sprintf(arcpath,"ARCH/20%02d",RTC.year);
  SD.mkdir(tmppath);
  SD.mkdir(arcpath);
  sprintf(file,"%02d%02d%02d.TXT",RTC.year,RTC.month,RTC.date);
  sprintf(fpath,"%s/%s",tmppath,file);
 
   //////////// FILENAME FOR ARCHIVE ///////////////////////

  USB.print("O3=");
  USB.print(O3_conc);
  USB.print("  NO2=");
  USB.print(NO2_conc);
  USB.print("  tc=");
  USB.print(temperature);
  USB.print("  hum=");
  USB.print(humidity);
  USB.print("  pres=");
  USB.print(pressure); 
  USB.print("\n");
    // Show the remaining battery level
  USB.print(F("Battery Level: "));
  USB.print(PWR.getBatteryLevel(),DEC);
  USB.print(F(" %"));
  
  // Show the battery Volts
  USB.print(F(" | Battery (Volts): "));
  USB.print(PWR.getBatteryVolts());
  USB.println(F(" V"));
  USB.print("\n");
/////////////////////////////////////////////////////////
//// CREATE FRAME AND SEND/SAVE MEASUREMENTS ////////////
/////////////////////////////////////////////////////////

// Create new frame (ASCII)
  frame.createFrame(ASCII,"Wasp_n01");

  // add frame fields
  frame.addSensor(SENSOR_STR, (char*) RTC.getTime());
  frame.addSensor(SENSOR_GASES_PRO_TC, temperature );
  frame.addSensor(SENSOR_GASES_PRO_HUM, humidity );
  frame.addSensor(SENSOR_GASES_PRO_PRES, pressure );
  frame.addSensor(SENSOR_GASES_PRO_NO2, NO2_conc );
  frame.addSensor(SENSOR_GASES_PRO_O3, O3_conc );
  frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel());
//  frame.showFrame(); 

/// IF WIFI CONNECTION EXISTS //////
  if( status == true )
  {   
//USB.print("wifi connected");
//////////////////////////////////////////////// 
// 3. Open TCP socket
////////////////////////////////////////////////
   error = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);
   socket_handle = WIFI_PRO._socket_handle;

//// SEND DATA /////
   error = WIFI_PRO.send( socket_handle, frame.buffer, frame.length);
  }
  
////////////////////////////////////////////////
////////// SAVE TO TEMPORARY FILE //////////////
   memset(toWrite, 0x00, sizeof(toWrite) ); 
  // Conversion from Binary to ASCII
   Utils.hex2str( frame.buffer, toWrite, frame.length);
   // create file if needed
   sd_answer = SD.create(fpath);
   sd_answer = SD.appendln(fpath, toWrite);
////////////////////////////////////////////////


   ////WATCHDOG////
//   RTC.unSetWatchdog();
   RTC.setWatchdog(7);
 // delay(60000);
  PWR.deepSleep("00:00:04:00",RTC_OFFSET,RTC_ALM1_MODE1,SENS_OFF);
}
