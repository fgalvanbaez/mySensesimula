generic configuration SensorLightC(uint8_t value) {
  provides interface Read<uint8_t> as VisibleLight;
}
implementation {
  components new ConstantSensorC(uint8_t,value) as Sensor;

  VisibleLight = Sensor;
}