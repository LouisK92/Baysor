FROM ubuntu:latest

RUN apt-get update && apt-get install -y build-essential
RUN apt-get install -y wget

RUN wget https://github.com/kharchenkolab/Baysor/releases/download/v0.6.2/baysor-x86_x64-linux-v0.6.2_build.zip
RUN apt-get install -y zip unzip
RUN unzip baysor-x86_x64-linux-v0.6.2_build.zip
RUN ln -s /bin/baysor/bin/baysor /usr/local/bin/baysor

RUN apt-get install -y python3 python3-pip vim
RUN pip3 install pandas

ENTRYPOINT ["/bin/bash"]