#!/usr/bin/python3
import os

from flask import Flask

app = Flask(__name__)


@app.route('/todo')
def hello_world():
    return 'Hello, World!\nUser: {}\nPassword: {}'.format(os.getenv("POSTGRES_USER"), os.getenv("POSTGRES_PASSWORD"))


if __name__ == '__main__':
    app.run("localhost", "8080")
