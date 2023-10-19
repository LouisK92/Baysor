FROM ubuntu:latest
### debian:latest ### ubuntu:19.04

RUN apt-get update && apt-get install -y build-essential
RUN apt-get install -y git
RUN apt-get install -y wget

RUN git clone https://github.com/LouisK92/Baysor.git
RUN git checkout -b v0_6_2
RUN cd Baysor/bin && make
RUN cd Baysor && chmod -R 775 .

RUN apt-get install -y python3 python3-pip vim

RUN pip3 install pandas
