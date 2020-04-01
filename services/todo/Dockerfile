FROM python:3.8

RUN apt-get update && apt-get install -yy python3-pip

ADD requirements.txt /requirements.txt
RUN /usr/bin/python3 -m pip install -r /requirements.txt

ADD todo.py /todo.py
ENTRYPOINT ["/usr/bin/python3", "/todo.py"]
