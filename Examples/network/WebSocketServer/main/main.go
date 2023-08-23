package main

import (
  "fmt"
  "github.com/gorilla/websocket"
  "log"
  "net/http"
  "time"
)

func PrintInfoWithTime() {
  fmt.Print("[" + time.Now().Format("2006 01 02 15 04 05") + "]")
}

func MyPrint(a ...interface{}) {
  PrintInfoWithTime()
  fmt.Println(a)
}

var upgrader = websocket.Upgrader{
  CheckOrigin: func(r *http.Request) bool {
    return true
  },
}

var a = 0

func StringHandler(w http.ResponseWriter, r *http.Request) {
  MyPrint("Header begin")
  for k, v := range r.Header {
    MyPrint(k, v)
  }
  MyPrint(r.Method)

  conn, err := upgrader.Upgrade(w, r, nil)
  if err != nil {
    log.Println("Error during connection upgrade: ", err)
    return
  }
  defer conn.Close()

  for {
    messageType, message, err := conn.ReadMessage()
    if err != nil {
      log.Println("Error during read message: ", err)
      break
    }
    log.Printf("Recv from Client: %s %d", message, messageType)
    err = conn.WriteMessage(websocket.TextMessage, []byte(message))
    if err != nil {
      log.Println("Error during write: ", err)
      break
    }
    conn.SetCloseHandler(func(code int, text string) error {
      log.Printf("Close Info: %s %d", text, code)
      return nil
    })

    a += 1
    if a > 400000 {
      conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseGoingAway, "GoAway"))
      log.Println("a = ", a)
      conn.Close()
    }
  }
}

func BinaryHandler(w http.ResponseWriter, r *http.Request) {
  MyPrint("Header begin")
  for k, v := range r.Header {
    MyPrint(k, v)
  }
  MyPrint(r.Method)

  conn, err := upgrader.Upgrade(w, r, nil)
  if err != nil {
    log.Println("Error during connection upgrade: ", err)
    return
  }
  defer conn.Close()

  for {
    messageType, message, err := conn.ReadMessage()
    if err != nil {
      log.Println("Error during read message: ", err)
      break
    }
    log.Printf("Recv from Client: %s %d", message, messageType)
    err = conn.WriteMessage(websocket.BinaryMessage, []byte("BinaryHandler"))
    if err != nil {
      log.Println("Error during write: ", err)
      break
    }
    conn.SetCloseHandler(func(code int, text string) error {
      log.Printf("Close Info: %s %d", text, code)
      return nil
    })

    a += 1
    if a > 400000 {
      conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseGoingAway, "GoAway"))
      log.Println("a = ", a)
      conn.Close()
    }
  }
}

func home(w http.ResponseWriter, r *http.Request) {
  MyPrint("Header begin")
  for k, v := range r.Header {
    MyPrint(k, v)
  }
  w.Header().Add("Content-Type", "application/octet-stream")
  _, err := w.Write([]byte("Hello Binary"))
  if err != nil {
    return
  }
  MyPrint(r.Method)
}

func main() {
  http.HandleFunc("/binary", BinaryHandler)
  http.HandleFunc("/string", StringHandler)
  http.HandleFunc("/", home)
  go func() {
    err := http.ListenAndServe("0.0.0.0:80", nil)
    if err != nil {
      panic(err)
    }
  }()
  log.Fatal(http.ListenAndServeTLS("0.0.0.0:443", "server.crt", "server.key", nil))
}
