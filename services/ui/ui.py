#!/usr/bin/python3
import flask

app = flask.Flask(__name__, template_folder='templates/')


@app.route('/', methods=['GET'])
def create_list():
    return flask.render_template('index.html')


if __name__ == '__main__':
    app.run("localhost", "8080")
