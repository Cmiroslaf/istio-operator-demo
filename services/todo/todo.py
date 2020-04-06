#!/usr/bin/python3
import functools
import json
import logging
import os
import typing

import flask
import sqlalchemy as sa
import sqlalchemy.ext.declarative
import sqlalchemy.orm

app = flask.Flask(__name__)

db_url = 'postgresql://{usr}:{pswd}@database:5432/{db}'.format(
    usr=os.getenv("POSTGRES_USER"),
    pswd=os.getenv("POSTGRES_PASSWORD"),
    db=os.getenv("POSTGRES_DB")
)
engine = sa.create_engine(db_url)
logger = logging.getLogger()

Session: typing.Type[sa.orm.Session] = typing.cast(typing.Type[sa.orm.Session], sa.orm.sessionmaker(bind=engine))
Base = sa.ext.declarative.declarative_base()


class List(Base):
    __tablename__ = 'list'
    id = sa.Column(sa.Integer, primary_key=True)

    name = sa.Column(sa.String)

    items = sa.orm.relationship('Item')

    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'name': self.name,
            'items': self.items
        }


class Item(Base):
    __tablename__ = 'item'
    id = sa.Column(sa.Integer, primary_key=True)

    fk_list = sa.Column(sa.Integer, sa.ForeignKey('list.id'), nullable=False)

    content = sa.Column(sa.String)

    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'name': self.content
        }


def debug(fn):
    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        if flask.request.data:
            logger.error("Handling incoming request: {}".format(json.loads(flask.request.data)))
        result: flask.Response = fn(*args, **kwargs)
        logger.error("Returning: {}".format(result))
        return result

    return wrapper


@app.route('/list', methods=['POST'])
@debug
def create_list():
    data = json.loads(flask.request.data)
    if 'name' not in data:
        return "Missing required 'name' from input JSON data", 400

    session = Session()

    todo_list = List(name=data['name'])
    session.add(todo_list)
    session.commit()

    session.refresh(todo_list)
    response: flask.Response = flask.jsonify({
        'id': todo_list.id,
        'name': todo_list.name,
        'items': []
    })
    response.status_code = 201

    session.close()
    return response


@app.route('/list/<lid>/item', methods=['POST'])
@debug
def create_item(lid: int):
    data = json.loads(flask.request.data)
    if 'content' not in data:
        return "Missing required 'content' from input JSON data", 400

    session = Session()

    list_ = session.query(List).get(lid)
    list_.items.append(Item(content=data['content']))
    session.commit()

    response: flask.Response = flask.jsonify([{
        'id': list_.id,
        'name': list_.name,
        'items': [
            {
                'id': item.id,
                'content': item.content,
                'fk_list': item.fk_list
            }
            for item in list_.items
        ],
    } for list_ in session.query(List)])
    response.status_code = 201

    session.close()
    return response


@app.route('/list', methods=['GET'])
@debug
def get_lists():
    session = Session()

    lists = session.query(List).all()
    response: flask.Response = flask.jsonify([{
        'id': lst.id,
        'name': lst.name,
        'items': [
            {
                'id': item.id,
                'content': item.content,
                'fk_list': item.fk_list
            }
            for item in lst.items
        ],
    } for lst in lists])
    response.status_code = 200

    session.close()
    return response


if __name__ == '__main__':
    Base.metadata.create_all(engine)
    app.run("localhost", "9080")
