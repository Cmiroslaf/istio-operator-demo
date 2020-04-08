package main

import (
	"encoding/json"
	"github.com/go-pg/pg/v9"
	"github.com/go-pg/pg/v9/orm"
	"log"
	"net/http"
	"os"
)

type Item struct {
	Id      int32
	Content string
}

type List struct {
	Id    int64
	Name  string
	Items []*Item
}

func getDB() *pg.DB {
	return pg.Connect(&pg.Options{
		Addr:     "database:5432",
		User:     os.Getenv("POSTGRES_USER"),
		Password: os.Getenv("POSTGRES_PASSWORD"),
		Database: os.Getenv("POSTGRES_DB"),
	})
}

func writeResponse(db *pg.DB, w http.ResponseWriter) {
	var lists []List

	err := db.Model(&lists).Select()
	if err != nil {
		http.Error(w, "Failed to marshal response", http.StatusInternalServerError)
	}

	response, err := json.Marshal(lists)
	if err != nil {
		http.Error(w, "Failed to marshal response", http.StatusInternalServerError)
	}

	w.Header().Set("Content-Type", "application/json")

	_, err = w.Write(response)
	if err != nil {
		http.Error(w, "Failed to write response", http.StatusInternalServerError)
	}
}

func listHandler(w http.ResponseWriter, r *http.Request) {
	db := getDB()
	defer db.Close()

	if r.Method == "POST" {
		var list List

		err := json.NewDecoder(r.Body).Decode(&list)
		if err != nil {
			http.Error(w, "Failed to decode json", http.StatusInternalServerError)
		}

		err = db.Insert(list)
		if err != nil {
			http.Error(w, "Failed to create new list", http.StatusInternalServerError)
		}

		writeResponse(db, w)
	} else if r.Method == "GET" {
		writeResponse(db, w)
	} else {
		http.Error(w, "Unknown method", http.StatusBadRequest)
	}
}

func createItem(w http.ResponseWriter, r *http.Request) {
	db := getDB()
	defer db.Close()

	if r.Method == "POST" {
		var item Item

		err := json.NewDecoder(r.Body).Decode(&item)
		if err != nil {
			http.Error(w, "Failed to decode json", http.StatusInternalServerError)
		}

		err = db.Insert(item)
		if err != nil {
			http.Error(w, "Failed to create new item", http.StatusInternalServerError)
		}

		writeResponse(db, w)
	} else {
		http.Error(w, "Unknown method", http.StatusBadRequest)
	}
}

func createSchema(db *pg.DB) error {
	for _, model := range []interface{}{(*Item)(nil), (*List)(nil)} {
		err := db.CreateTable(model, &orm.CreateTableOptions{
			Temp: true,
		})
		if err != nil {
			return err
		}
	}
	return nil
}

func main() {
	db := getDB()
	defer db.Close()

	err := createSchema(db)
	if err != nil {
		panic(err)
	}

	http.HandleFunc("/list", listHandler)
	http.HandleFunc("/list/:lid/item", createItem)

	log.Fatal(http.ListenAndServe(":9080", nil))
}
