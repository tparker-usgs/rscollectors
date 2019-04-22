avoviirscollector
=================
[![Build Status](https://travis-ci.org/tparker-usgs/avoviirscollector.svg?branch=master)](https://travis-ci.org/tparker-usgs/avoviirscollector)
[![Code Climate](https://codeclimate.com/github/tparker-usgs/avoviirscollector/badges/gpa.svg)](https://codeclimate.com/github/tparker-usgs/avoviirscollector)

Docker container to collect viirs data at AVO

**I'm still under development. Some of what you see below is outdated, while other parts may be aspirational. Talk to Tom 
before doing anything that matters.**


Overview
--------
I gather VIIRS data files and present a stream of products to generate on a ZeroMQ REP socket on port.

Daemons:
  * supervisord - launches all other deamons and keeps them running
  * supercronic - a cron daemon which Launches periodic tasks
  * nameserver - keeps track of active publishers on the internal messaging system
  * trollstalker - kicks things off once a file has been downloaded
  * segment_gatherer - listens to trollstalker and assembles files into a complete granule
  * task_broker - collects messages from segment_gatherer and provides tasks to 
                  [viirsprocessors](https://github.com/tparker-usgs/avoviirsprocessor)
  * msg_publisher - publishes Pytroll messages from internal processesing
  
Cron taks:
  * mirror_gina - searches GINA for recent images and retrieves any found
  * cleanup - remove old images

Filesystem
----------

I'll do all of my work under /viirs. When you run the docker image, mount a volume there.


Update Publisher
----------------
As new files are received, I will publish updates in [Posttroll](https://posttroll.readthedocs.io/en/latest/) messages.

example subscriber:

    #!/usr/bin/env python3

    import json

    import zmq
    from posttroll.message import Message

    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.setsockopt_string(zmq.SUBSCRIBE, 'pytroll://AVO/viirs/sdr')
    socket.connect("tcp://avoworker2:29092")

    while True:
      msg = Message.decode(socket.recv())
      print(json.dumps(msg.data, sort_keys=True, indent=4, default=str))

output:

    gilbert [6:59pm] % ./pubtest.py
    {
        "end_time": "2019-04-22 18:29:59",
        "orbit_number": 38780,
        "orig_platform_name": "npp",
        "platform_name": "Suomi-NPP",
        "proctime": "2019-04-22 18:39:26.285541",
        "segment": "SVM16",
        "sensor": [
            "viirs"
        ],
        "start_time": "2019-04-22 18:28:34.800000",
        "uid": "SVM16_npp_d20190422_t1828348_e1829590_b38780_c20190422183926285541_cspp_dev.h5",
        "uri": "/viirs/sdr/SVM16_npp_d20190422_t1828348_e1829590_b38780_c20190422183926285541_cspp_dev.h5"
    }



Environment Variables
---------------------

**general**
  * VIIRS_RETENTION - if this is defined, files in /viirs will be cleaned up after this many days.


**mirror_gina**
  * NUM_GINA_CONNECTIONS - files will be retrieved in segments using this many connections in parallel
  * GINA_BACKFILL_DAYS - data will be made complete over this many days
  * VIIRS_FACILITY - use data received at UAF or Gilmore Creek?


**logs** 

I will email errors generated by mirror_gina and task_broker if these are provided.
  * MAILHOST - who can forward mail for me?
  * LOG_SENDER - From: address
  * LOG_RECIPIENT - To: address


Logs
----

All logs are written to viirs/log/avoviirscollector. Daemons will have their own logs, but mirror_gina will show up in 
the supercronic logs. Unfortunatle, supervisord creates the logs with very restrictive perms. There's an open
[issue](https://github.com/Supervisor/supervisor/issues/123) on it.

Supervisord logs are also a bit sluggish. It can take upwards of 15 seconds for messages to be flushed to the logs.


supervisord
-----------
Launch deamons and keep them running. Additional info on supervisord is available at <http://supervisord.org/>. Check 
the supervisord log to see how stable the daemons are. When everything is going well this is a short boring log.


supercronic
-----------
Launch mirror_gina and cleanup. Additional info on supercronic is available at <https://github.com/aptible/supercronic>.
The supercronic logs will capture anything interesting from mirror_gina.


nameserver
----------
nameserver is part of the PyTroll posttroll project. Additional info on posttrol is available at
<https://github.com/pytroll/posttroll>. nameserver keeps track of topics learned from messages broadcasted 
by publishers and responds to queries from listeners looking for a topic. It has no configuration file and rarely causes
trouble. This is how task_broker learns about running segment_gatherers.


trollstalker
------------
trollstalker is part of the PyTroll pytroll-collectors project. Additional info on pytroll-collectors is available at
<https://github.com/pytroll/pytroll-collectors>. 

trollstalker uses inotify to watch for new files and publishes messages 
to start processing. This means things will only run on Linux. Additionally, it's important to think about inotify's 
scope. A NFS filesystem with a remote file writer won't work, as inotify wouldn't see the I/O.


segment_gatherer
----------------
segment_gatherer is part of the PyTroll pytroll-collectors project. Additional info on pytroll-collectors is available
at <https://github.com/pytroll/pytroll-collectors>. 

segment_gatherer listens to messages published by trollstalker and publishes a message once sufficient data is available 
to create a product. One instance of segment_gatherer runs for each product and sends messasges tagged with the product
to be creted. These messages become the tasks distributed by task_broker.

task_broker
----------
Distribute product generation tasks. Tasks are encoded as UTF-8 encoded strings, suitable for parsing by 
posttroll.message.Message.decode(). task_broker tries to avoid assigning the same task twice. If a message
arrives which matches one already in the queue, that queued task will maintain its queue postition and be 
updated with the new message. Duplicate tasks are determined with a 3-tupple of message.subject, 
message.platform_name, and message.orbit_number.

msg_publisher
-------------
Publish messages from internal processing. Messages are encoded as UTF-8 encoded strings, suitable for parsing by 
posttroll.message.Message.decode(). They're also pretty simple to parse by hand.

mirror_gina
-----------
Searches GINA NRT with parameters provided in the environemnt and retrieves any new files found. mirror_gina doesn't
write its own logs, look for output in the supercronic logs.


cleanup
-------
Nightly I'll cleanup files in /viirs, removing any that are older than $VIIRS_RETENTION days. All
files, even ones you might not think of.


docker-compose
--------------
Here is an example service stanza for use with docker-compose.

    viirscollector:
      image: "tparkerusgs/avoviirscollector:release-2.0.2"
      ports:
        - 19091:19091
        - 29092:29092

      user: "2001"
      environment:
        - VIIRS_RETENTION=7
        - NUM_GINA_CONNECTIONS=4
        - GINA_BACKFILL_DAYS=2
        - VIIRS_FACILITY=gilmore
        - PYTHONUNBUFFERED=1
        - MAILHOST=smtp.address.com
        - LOG_SENDER=worker@address.com
        - LOG_RECIPIENT=email@address.com
      restart: always
      logging:
        driver: json-file
        options:
          max-size: 10m
      volumes:
        - type: volume
          source: viirs
          target: /viirs
          volume:
            nocopy: true
