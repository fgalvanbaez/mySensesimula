COMPONENT=SenseAppC

BUILD_EXTRA_DEPS += SensorMsg.class
BUILD_EXTRA_DEPS += DisseminateMsg.class
BUILD_EXTRA_DEPS += DisseminateMsg.py

CFLAGS += -I$(TOSDIR)/lib/net/ -I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/net/4bitle -I%T/lib/net/drip

SensorMsg.class: SensorMsg.java
	javac -target 1.4 -source 1.4 SensorMsg.java

DisseminateMsg.class: DisseminateMsg.java
	javac -target 1.4 -source 1.4 DisseminateMsg.java

SensorMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=SensorMsg Sense.h sense -o $@

DisseminateMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=DisseminateMsg Sense.h changesensor -o $@

DisseminateMsg.py:
	mig python -target=null $(CFLAGS) -python-classname=DisseminateMsg Sense.h changesensor -o $@


include $(MAKERULES)