#!/usr/bin/python3
import logging

import flask
import opencensus.ext.flask.flask_middleware
import opencensus.ext.requests.trace
import opencensus.ext.zipkin.trace_exporter
import opencensus.trace.samplers
import opencensus.trace.tracer
import requests

app = flask.Flask(__name__, template_folder='templates/')
todo_url = "http://todo:9080"
logger = logging.getLogger("App")
logging.basicConfig(
    level=logging.DEBUG
)
trace_exporter = opencensus.ext.zipkin.trace_exporter.ZipkinExporter(
    service_name="UI",
    host_name="zipkin.istio-system.svc.cluster.local",
    port=9411,
)
trace_sampler = opencensus.trace.samplers.ProbabilitySampler(1)
tracer = opencensus.trace.tracer.Tracer(
    sampler=trace_sampler,
    exporter=trace_exporter,
)
opencensus.ext.requests.trace.trace_integration(tracer)
opencensus.ext.flask.flask_middleware.FlaskMiddleware(app, sampler=trace_sampler, exporter=trace_exporter)


@app.route('/', methods=['GET'])
def home():
    response = requests.get(todo_url + "/list")
    if not response.ok:
        return flask.make_response(response.reason, response.status_code)
    response = response.json()

    logger.info("Home: Rendering: {}".format(response))
    return flask.render_template('index.html', todo_lists=response)


@app.route('/list', methods=['POST'])
def create_list():
    request = flask.request.form.to_dict()
    logger.info("CreateList: Creating new list: {}".format(request))
    response = requests.post(todo_url + "/list", json=request)
    if not response.ok:
        return flask.make_response(response.reason, response.status_code)
    response = response.json()

    logger.info("CreateList: Rendering: {}".format(response))
    return flask.render_template('index.html', todo_lists=response)


@app.route('/list/<lid>/item', methods=['POST'])
def create_item(lid: int):
    request = flask.request.form.to_dict()
    logger.info("CreateItem: Creating new item: {}".format(request))
    response = requests.post(todo_url + "/list/{}/item".format(lid), json=request)
    if not response.ok:
        return flask.make_response(response.reason, response.status_code)
    response = response.json()

    logger.info("CreateItem: Rendering: {}".format(response))
    return flask.render_template('index.html', todo_lists=response)


@app.route('/healthz', methods=['GET'])
def healthz():
    response = flask.jsonify({})
    response.status_code = 200
    return response


if __name__ == '__main__':
    app.run("localhost", "9080")
