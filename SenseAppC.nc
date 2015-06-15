/*
 * Copyright (c) 2006, Technische Universitaet Berlin
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 * - Neither the name of the Technische Universitaet Berlin nor the names
 *   of its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Revision -------------------------------------------------------------
 * $Revision: 1.4 $
 * $Date: 2006-12-12 18:22:49 $
 * @author: Jan Hauer
 * ========================================================================
 */

/**
 * 
 * Sensing demo application. See README.txt file in this directory for usage
 * instructions and have a look at tinyos-2.x/doc/html/tutorial/lesson5.html
 * for a general tutorial on sensing in TinyOS.
 * 
 * @author Jan Hauer
 */

#include "Sense.h"

configuration SenseAppC 
{ 
} 
implementation { 
  
/*  components SenseC, MainC, LedsC, new TimerMilliC(), new Accel202C() as SensorAcc, new Taos2550C() as SensorLight;
*/
  components SenseC, MainC, LedsC, new TimerMilliC();

  // Fake sensors for simulation purposes
  components new SensorAccC(0xaaaa) as SensorAcc;
  components new SensorLightC(0xbb) as SensorLight;

  SenseC.Boot -> MainC;
  SenseC.Leds -> LedsC;
  SenseC.Timer -> TimerMilliC;
  SenseC.X_Axis -> SensorAcc.X_Axis;
  SenseC.Light -> SensorLight.VisibleLight;

  components CollectionC as Collector,  // Collection layer
    ActiveMessageC,                         // AM layer
    new CollectionSenderC(AM_SENSE), // Sends multihop RF
    SerialActiveMessageC,                   // Serial messaging
    new SerialAMSenderC(AM_SENSE);   // Sends to the serial port

  SenseC.RadioControl -> ActiveMessageC;
  SenseC.SerialControl -> SerialActiveMessageC;
  SenseC.RoutingControl -> Collector;

  SenseC.Send -> CollectionSenderC;
  SenseC.CollReceive -> Collector.Receive[AM_SENSE];
  SenseC.RootControl -> Collector;


  components new PoolC(message_t, 10) as UARTMessagePoolP,
  new QueueC(message_t*, 10) as UARTQueueP;

  SenseC.SerialSend -> SerialAMSenderC.AMSend;
  SenseC.SerialReceive-> SerialActiveMessageC.Receive[AM_SENSE];
  SenseC.UARTMessagePool -> UARTMessagePoolP;
  SenseC.UARTQueue -> UARTQueueP;
  
  components DisseminationC;
  components new DisseminatorC(changesensor_t,0x1234) as ChangerC;
  
  SenseC.DisseminationControl-> DisseminationC;
  SenseC.Value -> ChangerC;
  SenseC.Update -> ChangerC;
}
