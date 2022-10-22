FROM ubuntu:latest
### debian:latest ### ubuntu:19.04

RUN apt-get update && apt-get install -y build-essential
RUN apt-get install -y git
RUN apt-get install -y wget

RUN git clone https://github.com/LouisK92/Baysor.git
RUN cd Baysor/bin && make
RUN cd Baysor && chmod -R 775 .
#RUN make

#RUN baysor --help

### Jupyter
#
#apt-get install -y python3 python3-pip vim
#
#pip3 install numpy scipy matplotlib seaborn pandas sklearn scikit-image anndata
#
#baysor --help