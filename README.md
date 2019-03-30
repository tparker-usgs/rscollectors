rsCollectors
============
[![Build Status](https://travis-ci.org/tparker-usgs/rsCollectors.svg?branch=master)](https://travis-ci.org/tparker-usgs/rsCollectors)
[![Code Climate](https://codeclimate.com/github/tparker-usgs/rsCollectors/badges/gpa.svg)](https://codeclimate.com/github/tparker-usgs/rsCollectors)

Docker container to collect remote sensing data at AVO

Environment variables
---------------------
I look to the environment for my bootstrap config. I require two enironrment variables.
  * _MIRROR_GINA_CONFIG_ Local filesystem path of the configuration file.
  * _CU_CONFIG_URL_ URL to a configupdater configuration file.

If a authentication is required to retrieve the configupdater configuration, it can be specified in the environment.
  * _CU_USER_ Username, if required to retrieve configupdater config file.
  * _CU_PASSWORD_ Password, if required to retrieve configupdater config file.

I will email logged errors if desired.
  * _CU_CONTEXT_NAME_ Displayed in the subject of any email generated by configupdater.
  * _MAILHOST_ Who can forward mail for me?
  * _LOG_SENDER_ From: address
  * _LOG_RECIPIENT_ To: address

docker-compose
--------------
Here is an example service stanza for use with docker-compose.

    collectors:
      image: "tparkerusgs/rscollectors:release-2.0.2"
      user: "2001"
      environment:
        - MIRROR_GINA_CONFIG=/tmp/mirrorGina.yaml
        - PYTHONUNBUFFERED=1
        - MAILHOST=smtp.usgs.gov
        - LOG_SENDER=avoauto@usgs.gov
        - LOG_RECIPIENT=tparker@usgs.gov
        - CU_CONFIG_URL=https://avomon01.wr.usgs.gov/svn/docker/rsprocessing/configupdater-collectors.yaml
        - CU_CONTEXT_NAME=collectors
        - CU_USER=user
        - CU_PASSWORD=password
      restart: always
      logging:
        driver: json-file
        options:
          max-size: 10m
      volumes:
        - type: volume
          source: rsdata
          target: /rsdata
          volume:
            nocopy: true
