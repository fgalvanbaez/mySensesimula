# -*- coding: utf-8 -*-
#Imports:

# Acceso a sys.stdout
import sys

# La librería TOSSIM se obtiene de la compilación,
# Representa el simulador:
from TOSSIM import *

# Las librería SensorMsg y DisseminateMsg las obtenemos con la herramienta
# mig (ver Makefile) a partir de las estructuras de datos
# definidas en Sense.h

from SensorMsg import *
from DisseminateMsg import *

#El simulador
t=Tossim([]) 

# Instancioamos en el simulador el sistema de comunicaciones.        
r=t.radio()

# Instanciamos  un serialforwarder: sirve
# para simular la comunicación serial
sf=SerialForwarder(9001)

# Instanciamos en el simulador un throttle que regula la velocidad de la
# simulación
 
throttle=Throttle(t,10)

# En esta parte cargamos y usamos el fichero de topología topo.txt
# El sistema de radio es el afectado:

f=open("topo.txt","r")


lines=f.readlines() #lee el fichero linea por linea
for line in lines:
 s=line.split()  #separa la linea en trozos
 if (len(s)>0):
  print " ",s[0]," ",s[1]," ",s[2];
  r.add(int(s[0]),int(s[1]),float(s[2])) 


# Incluimos en la simulación un modelo de ruido electrónico que afecta
# a los motes.
# Partimos de datos de medidas en el fichero noise.txt:

# Primera fase: incorporamos los datos de ruido a cada mote

noise=open("noise.txt","r")
lines=noise.readlines()
for line in lines:
 str=line.strip()
 if (str!= ""):
  val=int(str)
  for i in range(0,3): #indica el numero de nodos, en este caso 4
   t.getNode(i).addNoiseTraceReading(val) 

# Segunda fase: se calcula el modelo de ruido para cada mote:
for i in range(0,3):
 t.getNode(i).createNoiseModel()

# ----------------------------------------------------------------
# Añadimos canales de depuración, es decir:
# definimos qué líneas dbg incluidas en el código fuente de la aplicación
# van a ejecutarse durante la simulación

t.addChannel("Boot",sys.stdout)
t.addChannel("Radiostart",sys.stdout)
t.addChannel("Serial",sys.stdout)
#t.addChannel("Sensado",sys.stdout)
#t.addChannel("Collect",sys.stdout)
t.addChannel("Disseminate",sys.stdout)
t.addChannel("Error",sys.stderr);

# Algunos ejemplos de líneas de depuración que puedes incluir en el código
# del componente:

# dbg("Boot", "System started in node %d.\n",TOS_NODE_ID);
# dbg("Sense", "Valor del contador es %d\n",counter);
# Nota: counter sería una variable de tu programa.
# dbg("Miserial","Serial control started. %s\n",sim_time_string());
# Nota: la función sim_time_string() da una cadena que representa el tiempo
# de simulación.

#------------------------------------------------------------------

# Fase de preparación de la simulación:

# El tiempo en TOSSIM se mide en ticks de simulación. Para
# tener más clara su relación con la escala temporal real
# obtenemos el número de ticks por segundo:

T=t.ticksPerSecond();

# Definimos el instante de arranque para los motes. La documentación
# de TOSSIM recomienda que estos tiempos no sean exactamente iguales.
D1=0
D2=T/4;
D3=T/3;

# Incializamos el throttle


# Instanciamos los nodos de la red y configuramos el momento de arranque.
# Al configurar esto creamos eventos pendientes en la cola de eventos 
# del simulador

n1=t.getNode(0);
n2=t.getNode(1);
n3=t.getNode(2);

n1.bootAtTime(D1);
n2.bootAtTime(D2);
n3.bootAtTime(D3);

# Avanzamos la simulación hasta que los tres motes estén realmente
# arrancados:

sf.process()
throttle.initialize()

# Las lineas throttle.checkThrottle() en los bucles de simulación por
# eventos están comentadas. Si se activan la simulación irá
# aproximadamente en tiempo real. 

while not (n1.isOn() and n2.isOn() and n3.isOn()):
  #throttle.checkThrottle();
  t.runNextEvent();
  sf.process();

print "Los motes han arrancado"

# Vamos a inyectar un paquete en la entrada serial:


msg1=DisseminateMsg()
msg1.set_id(1)
msg1.set_sensor(0)
serialpkt1=t.newSerialPacket()
serialpkt1.setData(msg1.data)
serialpkt1.setType(msg1.get_amType())
serialpkt1.setDestination(0)
serialpkt1.deliver(0,t.time()+5*T)

print "Creado el paquete serial con AM_TYPE %d " % (serialpkt1.type())

# Tiempo de simulación:

Tsim=30*T # Debemos expresarlo en ticks de simulación

# Simulamos hasta la finalización del tiempo de simulación
while(t.time()<30*T):
 #throttle.checkThrottle();
 t.runNextEvent()
 sf.process()
