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
Base = sa.ext.declarative.declarative_base()
Session: typing.Type[sa.orm.Session] = typing.cast(typing.Type[sa.orm.Session], sa.orm.sessionmaker(bind=engine))
logger = logging.getLogger()


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
        result = fn(*args, **kwargs)
        logger.error("Returning: {}".format(result))
        return result

    return wrapper


@app.route('/list', methods=['POST'])
@debug
def create_list():
    data = json.loads(flask.request.data)
    if 'name' not in data:
        return 400, "Missing required 'name' from input JSON data"

    session = Session()

    todo_list = List(name=data['name'])
    session.add(todo_list)
    session.commit()

    session.refresh(todo_list)
    response = {
        'id': todo_list.id,
        'name': todo_list.name,
    }

    session.close()
    return flask.make_response(flask.jsonify(response), 201)


@app.route('/list/<lid>/item', methods=['POST'])
@debug
def create_item(lid: int):
    data = json.loads(flask.request.data)
    if 'content' not in data:
        return 400, "Missing required 'content' from input JSON data"

    session = Session()

    todo_item = Item(content=data['content'])
    todo_item.fk_list = lid
    session.add(todo_item)
    session.commit()

    session.refresh(todo_item)
    response = {
        'id': todo_item.id,
        'content': todo_item.content,
        'fk_list': todo_item.fk_list
    }

    session.close()
    return flask.make_response(flask.jsonify(response), 201)


@app.route('/list/<lid>/item', methods=['GET'])
@debug
def get_items(lid: int):
    session = Session()

    items = session.query(Item).filter(Item.fk_list == lid).all()
    response = flask.jsonify([{
        'id': item.id,
        'content': item.content,
        'fk_list': item.fk_list
    } for item in items])

    session.close()
    return flask.make_response(response, 200)


if __name__ == '__main__':
    Base.metadata.create_all(engine)
    app.run("localhost", "9080")
