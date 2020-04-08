#FROM golang
#
#WORKDIR /app
#ADD . /app
#
#RUN go build
#
#ENTRYPOINT ["/app/todo"]

FROM python:3.8

RUN apt-get update && apt-get install -yy python3-pip

ADD requirements.txt /app/requirements.txt
RUN /usr/bin/python3 -m pip install -r /app/requirements.txt

ADD todo.py /app/todo.py

ENTRYPOINT ["/usr/bin/python3", "/app/todo.py"]
