generic configuration SensorAccC(uint16_t value) {
  provides interface Read<uint16_t> as X_Axis;
}
implementation {
  components new ConstantSensorC(uint16_t,value) as Sensor;

  X_Axis = Sensor;
}

