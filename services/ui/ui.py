#!/usr/bin/python3
import flask
import requests

app = flask.Flask(__name__, template_folder='templates/')
todo_url = "todo:9080"


@app.route('/', methods=['GET'])
def create_list():
    response = requests.get(todo_url + "/list")
    return flask.render_template('index.html', URL=todo_url, todo_lists=response.json())


if __name__ == '__main__':
    app.run("localhost", "9080")
