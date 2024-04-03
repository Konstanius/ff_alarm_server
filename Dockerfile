FROM ubuntu:latest
LABEL authors="Konstantin Dubnack"

# Copy the resources
COPY ./resources /ff/resources

# Move the main.exe from the resources folder to the /ff folder
RUN mv /ff/resources/main.exe /ff/main.exe

# make the entire resources folder a volume named resources
VOLUME /ff/resources

# set workdir
WORKDIR /ff/resources

ENV DARGON2_LIB_PATH=/ff/resources/libargon2.so.1

RUN apt-get update

# install java
RUN apt-get install -y openjdk-18-jre-headless

# change the timezone to Europe/Berlin
RUN apt-get install -y tzdata
RUN ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime
RUN dpkg-reconfigure --frontend noninteractive tzdata

# run main.exe that is currently in the resources folder
ENTRYPOINT ["./../main.exe"]
