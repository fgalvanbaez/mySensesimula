#include "Timer.h"
#include "Sense.h"
module SenseC
{
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface SplitControl as SerialControl;
    interface StdControl as RoutingControl;
    
    // Interfaces for communication, multihop 
    interface Send;
    interface Receive as CollReceive;
    interface CollectionPacket;
    interface RootControl;

    // Interfaces para implementar la comunicación serial, con una cola

    interface AMSend as SerialSend;
    interface Receive as SerialReceive;
    interface Queue<message_t *> as UARTQueue;
    interface Pool<message_t> as UARTMessagePool;

    // Interfaces para diseminar
    
    interface StdControl as DisseminationControl;

    interface DisseminationValue<changesensor_t> as Value;
    interface DisseminationUpdate<changesensor_t> as Update;


    interface Leds;
    interface Timer<TMilli>;
    interface Read<uint16_t> as X_Axis;
    interface Read<uint8_t> as Light;
  }
}
implementation
{
  // sampling frequency in binary milliseconds
  #define SAMPLING_FREQUENCY 5000

  task void uartSendTask();
  static void fatal_problem();
  static void report_problem();
  static void report_sent();
  static void report_changed();

  sense_t local;  //Variable tipo sense_t para que el mote base reciba información
  uint16_t type_sensor=0;  //Variable que indica el tipo de sensor que esta activo 
  uint16_t count=0; //Contador de paquetes enviados por el mote
  
  uint16_t count_request=0; //Contador de paquetes enviados por el mote


  message_t sendbuf;
  bool sendbusy=FALSE;

  // Variables relacionadas con la UART

  message_t uartbuf;
  bool uartbusy=FALSE;
  uint8_t uartlen;


  event void Boot.booted() {
    dbg("Boot", "System started in node %d.\n",TOS_NODE_ID);

    if (call RadioControl.start() != SUCCESS){
      dbg("Error","Error en la inicialización de la radio");
      fatal_problem();}
    
    if (call RoutingControl.start() != SUCCESS){
      dbg("Error","Error en la inicialización de la recolección");
      fatal_problem();}

    if (call DisseminationControl.start() != SUCCESS){
       dbg("Error","Error en la inicialización de la diseminación");
       fatal_problem();
    }
  }

  event void RadioControl.startDone(error_t error) {
    if (error != SUCCESS)
      fatal_problem();
    else
       dbg("Radiostart", "Radio on in node  %d.\n",TOS_NODE_ID);

    if (sizeof(local) > call Send.maxPayloadLength())
      fatal_problem();
    if(TOS_NODE_ID==0)
	if (call SerialControl.start() != SUCCESS)
      	   fatal_problem();
    
    //Para arrancar los motes tenemos que ver si es el base o los esclavos
    if (TOS_NODE_ID > 0) //Si son los motes esclavos se arranca el timer periodico que irá leyendo cada x tiempo los datos y los enviará al base
      call Timer.startPeriodic(SAMPLING_FREQUENCY);
    
    
    if (TOS_NODE_ID == 0) //Si es el mote base se asigna como tal.
      call RootControl.setRoot();
      
  }

  event void SerialControl.startDone(error_t error) {
    if (error != SUCCESS)
      fatal_problem();
    else
	dbg("Serial","Serial control started. %s\n",sim_time_string());

    
  }

  event void RadioControl.stopDone(error_t error) { }
  event void SerialControl.stopDone(error_t error) { }

  
  //Según programación periodica del timer, una vez se dispare, dependiendo del tipo de sensor que este activo en ese momento se leera el estado del mismo
  event void Timer.fired() 
  {
    if(type_sensor==0)
     call X_Axis.read();
    else
     call Light.read();
  }

  //Evento que se ejecuta una vez el mote haya leido sus datos despues de el tiempo periódico
  event void X_Axis.readDone(error_t result, uint16_t data) 
  {
    if (result == SUCCESS) {	
	//Construyo el paquete para enviar
        call Leds.led0Toggle();
	local.id=TOS_NODE_ID;
	local.sensor_t=0;
	local.count=++count;
	local.reading_acc=data;

     
      if (!sendbusy) {
	  sense_t *o = (sense_t *)call Send.getPayload(&sendbuf, sizeof(sense_t));
	  if (o == NULL) {
	    fatal_problem();
	    return;
	  }
	  memcpy(o, &local, sizeof(local));
	  if (call Send.send(&sendbuf, sizeof(local)) == SUCCESS)
	    sendbusy = TRUE;
	  else
	    report_problem();
      }
   }
      
  }

  //Evento que realiza exactamente lo mismo que el evento X_Axis pero cambiado el tipo de sensor
  event void Light.readDone(error_t result, uint8_t data) 
  {
    if (result == SUCCESS){
        call Leds.led0Toggle();
	local.id=TOS_NODE_ID;
	local.sensor_t=1;
	local.count=++count;
	local.reading_light=data;

     
    if (!sendbusy) {
	sense_t *o = (sense_t *)call Send.getPayload(&sendbuf, sizeof(sense_t));
	if (o == NULL) {
	  fatal_problem();
	  return;
	}
	memcpy(o, &local, sizeof(local));
	if (call Send.send(&sendbuf, sizeof(local)) == SUCCESS)
	  sendbusy = TRUE;
        else
          report_problem();
      }
   }
  }

  //Función que actualiza los valores en el mote con identificador (id)
  event void Value.changed() {
    const changesensor_t* ChangedValue = call Value.get();
    if(((ChangedValue->id) > 0) && ((ChangedValue->id) == TOS_NODE_ID)){
      type_sensor=ChangedValue->sensor;
      
      if (type_sensor == 0) {
	call Leds.led2Off();
	call Leds.led1On();
      }
      else {
	call Leds.led1Off();
	call Leds.led2On();
      }
    }    
  }

  //Evento que una vez se haga una envio se ejecutara posteriormente
  event void Send.sendDone(message_t* msg, error_t error) { 

  sendbusy=FALSE;

 }


  //Evento que se ejecuta cuando el mote base recibe una señal por serial, diseminando el mensaje a los demas motes 
  event message_t* SerialReceive.receive(message_t *msg, void *payload, uint8_t len){
  
    changesensor_t* in;

    //Variable para diseminar el mensaje a los motes esclavos
      if(TOS_NODE_ID == 0) {
          call Leds.led0Toggle();
	++count_request;  ///Aumento la variable de peticiones recibidas por el mote base
	in = (changesensor_t*) payload;
	
	if (in->sensor == 0) {
	  call Leds.led2Off();
	  call Leds.led1On();
	}
	else {
	  call Leds.led1Off();
	  call Leds.led2On();
	}
	
	call Update.change( in );
      }
  }



/* Parte correspondiente al envio de datos seriales */

  event message_t*
  CollReceive.receive(message_t* msg, void *payload, uint8_t len) {

    sense_t* in = (sense_t*)payload;
    sense_t* out;

    dbg("Collect","Recepcion en el raiz de datos del nodo %d\n",in->id);
    if (uartbusy == FALSE) {
      out = (sense_t*)call SerialSend.getPayload(&uartbuf, sizeof(sense_t));
      if (len != sizeof(sense_t) || out == NULL) {
	return msg;
      }
      else {
	memcpy(out, in, sizeof(sense_t));
      }
      uartlen = sizeof(sense_t);
      post uartSendTask();
    } else {
      // The UART is busy; queue up messages and service them when the
      // UART becomes free.
      message_t *newmsg = call UARTMessagePool.get();
      if (newmsg == NULL) {
        // drop the message on the floor if we run out of queue space.
        report_problem();
        return msg;
      }

      //Serial port busy, so enqueue.
      out = (sense_t*)call SerialSend.getPayload(newmsg, sizeof(sense_t));
      if (out == NULL) {
	return msg;
      }
      memcpy(out, in, sizeof(sense_t));

      if (call UARTQueue.enqueue(newmsg) != SUCCESS) {
        // drop the message on the floor and hang if we run out of
        // queue space without running out of queue space first (this
        // should not occur).
        call UARTMessagePool.put(newmsg);
        fatal_problem();
        return msg;
      }
    }

    return msg;
  }

  task void uartSendTask() {
    if (call SerialSend.send(0xffff, &uartbuf, uartlen) != SUCCESS) {
      report_problem();
    } else {
      uartbusy = TRUE;
    }
  }

  event void SerialSend.sendDone(message_t *msg, error_t error) {
    uartbusy = FALSE;
    dbg("Serial","Datos eviados por el serial\n");
    if (call UARTQueue.empty() == FALSE) {
      // We just finished a UART send, and the uart queue is
      // non-empty.  Let's start a new one.
      message_t *queuemsg = call UARTQueue.dequeue();
      if (queuemsg == NULL) {
        fatal_problem();
        return;
      }
      memcpy(&uartbuf, queuemsg, sizeof(message_t));
      if (call UARTMessagePool.put(queuemsg) != SUCCESS) {
        fatal_problem();
        return;
      }
      post uartSendTask();
    }
  }




//Depuración

  static void fatal_problem() { 
    call Leds.led0On(); 
    call Leds.led1On();
    call Leds.led2On();
    call Timer.stop();
  }

  static void report_problem() { call Leds.led0Toggle(); }

  static void report_sent() { call Leds.led1Toggle(); }
  
  static void report_changed() { call Leds.led2Toggle(); }

}
