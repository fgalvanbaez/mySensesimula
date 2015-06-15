/*									tab:4
 * Copyright (c) 2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

/**
 * Java-side application for testing serial port communication.
 * 
 *
 * @author Phil Levis <pal@cs.berkeley.edu>
 * @date August 12 2005
 */

import java.io.IOException;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

public class ControlNewSense {

  private MoteIF moteIF;
  private short sensortoactivate=0;
  private short id=1;
  
    public ControlNewSense(MoteIF moteIF,short parsedid, short parsedsensor) {
    this.moteIF = moteIF;
    this.sensortoactivate=parsedsensor;
    this.id=parsedid;

  }

  public void sendPackets() {


    DisseminateMsg payload = new DisseminateMsg();
    
    try {

	System.out.println("Sending packet for node " + id );
	System.out.println("Activating sensor  " + sensortoactivate );
	payload.set_id(id);
	payload.set_sensor(sensortoactivate);
	moteIF.send(0, payload);
	try {Thread.sleep(1000);}
	catch (InterruptedException exception) {}
       
      
    }
    catch (IOException exception) {
      System.err.println("Exception thrown when sending packets. Exiting.");
      System.err.println(exception);
    }
  }

  
  private static void usage() {
    System.err.println("usage: ControlNewSense [-comm <source>] moteid sensortoactivate");
  }
  
  public static void main(String[] args) throws Exception {
    String source = null;
    short parsedsensor=0;
    short parsedid=1;
    if (args.length == 4) {
      if (!args[0].equals("-comm")) {
	usage();
	System.exit(1);
      }
      source = args[1];
      try{
	  parsedsensor = Short.parseShort(args[3]);
	  parsedid = Short.parseShort(args[2]);
      }
      catch(NumberFormatException e){
	  System.err.println("Error parsing sensor number");
      }

    }
    else if (args.length != 0) {
      usage();
      System.exit(1);
    }
    
    PhoenixSource phoenix;

    
    if (source == null) {
      phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
    }
    else {
      phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
    }

    MoteIF mif = new MoteIF(phoenix);
    ControlNewSense serial = new ControlNewSense(mif,parsedid,parsedsensor);
    serial.sendPackets();
    PacketSource puerto = phoenix.getPacketSource();
    phoenix.awaitStartup();
    Thread.sleep(8000);
    //puerto.close();
    System.exit(0);
  }


}
