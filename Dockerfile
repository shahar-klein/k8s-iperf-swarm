FROM ubuntu:18.04

USER root


# get a reasonable version of openvswitch
RUN apt-get update --fix-missing
RUN apt-get install -y apt bash iputils-ping tcpdump ssh
RUN apt-get update
RUN apt-get install -y netcat net-tools 


