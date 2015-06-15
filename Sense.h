#ifndef SENSE_H
#define SENSE_H

enum {
  DEFAULT_INTERVAL = 500,
  AM_SENSE = 0x93,
  AM_CHANGESENSOR = 0x93
};

typedef nx_struct sense {
  nx_uint16_t id; /* Mote id of sending mote. */
  nx_uint8_t sensor_t;
  nx_uint16_t count; 
  nx_uint16_t reading_acc;
  nx_uint8_t reading_light;

} sense_t;

typedef nx_struct changesensor {
  nx_uint16_t id;
  nx_uint16_t sensor;
} changesensor_t;



#endif
