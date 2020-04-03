FROM python:3.8

RUN apt-get update && apt-get install -yy python3-pip

ADD requirements.txt /app/requirements.txt
RUN /usr/bin/python3 -m pip install -r /app/requirements.txt

ADD ui.py /app/ui.py
ADD templates /app/templates

ENTRYPOINT ["/usr/bin/python3", "/app/ui.py"]
