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

  sense_t sensado;
  uint8_t sensor=0;
  uint16_t counter=0;


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

    if (sizeof(sensado) > call Send.maxPayloadLength())
      fatal_problem();
    if(TOS_NODE_ID==0)
	if (call SerialControl.start() != SUCCESS)
      	   fatal_problem();
    // This is how to set yourself as a root to the collection layer:
    if (TOS_NODE_ID == 0)
      call RootControl.setRoot();
    if(TOS_NODE_ID>0)
	call Timer.startPeriodic(SAMPLING_FREQUENCY);
  }

  event void SerialControl.startDone(error_t error) {
    if (error != SUCCESS)
      fatal_problem();
    else
	dbg("Serial","Serial control started. %s\n",sim_time_string());

    
  }

  event void RadioControl.stopDone(error_t error) { }
  event void SerialControl.stopDone(error_t error) { }

  event void Timer.fired() 
  {
    if(sensor==0)
     call X_Axis.read();
    else
     call Light.read();
  }

  event void X_Axis.readDone(error_t result, uint16_t data) 
  {
    if (result == SUCCESS){
        dbg("Sensado","Sensado Acc realizado en el nodo %d\n",TOS_NODE_ID); 
        call Leds.led2Toggle();
	sensado.id=TOS_NODE_ID;
	sensado.sensor_t=0;
	sensado.count=++counter;
	sensado.reading_acc=data;

     
    if (!sendbusy) {
	sense_t *o = (sense_t *)call Send.getPayload(&sendbuf, sizeof(sense_t));
	if (o == NULL) {
	  fatal_problem();
	  return;
	}
	memcpy(o, &sensado, sizeof(sensado));
	if (call Send.send(&sendbuf, sizeof(sensado)) == SUCCESS)
	  sendbusy = TRUE;
        else
          report_problem();
      }
   }
      
  
}

  event void Light.readDone(error_t result, uint8_t data) 
  {
    if (result == SUCCESS){
        dbg("Sensado","Sensado Light realizado en el nodo %d\n",TOS_NODE_ID); 
        call Leds.led1Toggle();
	sensado.id=TOS_NODE_ID;
	sensado.sensor_t=0;
	sensado.count=++counter;
	sensado.reading_light=data;

     
    if (!sendbusy) {
	sense_t *o = (sense_t *)call Send.getPayload(&sendbuf, sizeof(sense_t));
	if (o == NULL) {
	  fatal_problem();
	  return;
	}
	memcpy(o, &sensado, sizeof(sensado));
	if (call Send.send(&sendbuf, sizeof(sensado)) == SUCCESS)
	  sendbusy = TRUE;
        else
          report_problem();
      }
   }
      
  
}

  event void Send.sendDone(message_t* msg, error_t error) {
    if (error == SUCCESS){
      dbg("Collect","Collect iniciado por nodo %d\n",TOS_NODE_ID);
      report_sent();
   }

   else{
      dbg("Collect","Fallo en el collect iniciado por nodo %d\n",TOS_NODE_ID);
      report_problem();
      }

    sendbusy = FALSE;
  }


/* Parte correspondiente a la recepción de datos seriales*/

event message_t* SerialReceive.receive(message_t *msg, void *payload, uint8_t len){

dbg("Disseminate","Disseminate: Recepcion de datos por el serial\n");

atomic{

if(TOS_NODE_ID == 0){

changesensor_t *in = (changesensor_t *) payload;

call Update.change( in );

}

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


// Responde a la diseminación

  event void Value.changed() {
    const changesensor_t* newVal = call Value.get();
    if(((newVal->id) > 0) && ((newVal->id) == TOS_NODE_ID)){
    dbg("Disseminate", "Datos diseminados son actualizados por el nodo %d.\n",TOS_NODE_ID);
    sensor=newVal->sensor;  

    }
    
  }


// Depuración

  static void fatal_problem() { 
    call Leds.led0On(); 
    call Leds.led1On();
    call Leds.led2On();
    call Timer.stop();
  }

  static void report_problem() { call Leds.led0Toggle(); }

  static void report_sent() { call Leds.led1Toggle(); }

}

