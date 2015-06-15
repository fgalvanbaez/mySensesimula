# mySensesimula
Aplicación para la manipulación de dispositivos con diferentes sensores. El flujo normal de uso es: 

1: Lectua con app movil de la tarjeta RFID colocada en el mote donde obtendremos el id del mismo
2: Envio a servidor nodejs la petición con datos de id del mote y sensor a cambiar
3: Una vez la petición sea procesada el servidor ejecutará un comando por puerto serie.
4: El comando ejecutado por el servidor será obtenido por la estación base de los mote, la cual, diseminará el paquete a la red de mote.
5: Cuando el paquete llegue el mote indicado este comnezará a usar el sensor que hemos solicitado.
