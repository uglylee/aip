package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"sync/atomic"

	"aip-server/config"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"go.mongodb.org/mongo-driver/v2/bson"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Client struct {
	Conn      *websocket.Conn
	UserID    string
	Rooms     map[string]bool
	Send      chan []byte
	closed    atomic.Bool
}

type Hub struct {
	clients   map[*Client]bool
	userConns map[string][]*Client
	roomConns map[string][]*Client
	mu        sync.RWMutex
}

var H *Hub

func NewHub() *Hub {
	H = &Hub{
		clients:   make(map[*Client]bool),
		userConns: make(map[string][]*Client),
		roomConns: make(map[string][]*Client),
	}
	return H
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[c] = true
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.clients[c] {
		return
	}
	delete(h.clients, c)

	if c.UserID != "" {
		conns := h.userConns[c.UserID]
		for i, conn := range conns {
			if conn == c {
				h.userConns[c.UserID] = append(conns[:i], conns[i+1:]...)
				break
			}
		}
	}
	for room := range c.Rooms {
		h.removeFromRoom(c, room)
	}

	if c.closed.CompareAndSwap(false, true) {
		close(c.Send)
	}
	c.Conn.Close()
}

func (h *Hub) JoinUser(c *Client, userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	c.UserID = userID
	h.userConns[userID] = append(h.userConns[userID], c)
}

func (h *Hub) JoinRoom(c *Client, room string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	c.Rooms[room] = true
	h.roomConns[room] = append(h.roomConns[room], c)
}

func (h *Hub) LeaveRoom(c *Client, room string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(c.Rooms, room)
	h.removeFromRoom(c, room)
}

func (h *Hub) removeFromRoom(c *Client, room string) {
	conns := h.roomConns[room]
	for i, conn := range conns {
		if conn == c {
			h.roomConns[room] = append(conns[:i], conns[i+1:]...)
			return
		}
	}
}

func (h *Hub) EmitToUser(userID string, event string, data interface{}) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	msg, _ := json.Marshal(fiber.Map{"event": event, "data": data})
	for _, c := range h.userConns[userID] {
		if !c.closed.Load() {
			select {
			case c.Send <- msg:
			default:
			}
		}
	}
}

func (h *Hub) EmitToRoom(room string, event string, data interface{}) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	msg, _ := json.Marshal(fiber.Map{"event": event, "data": data})
	for _, c := range h.roomConns[room] {
		if !c.closed.Load() {
			select {
			case c.Send <- msg:
			default:
			}
		}
	}
}

func (h *Hub) EmitToAll(event string, data interface{}) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	msg, _ := json.Marshal(fiber.Map{"event": event, "data": data})
	for c := range h.clients {
		if !c.closed.Load() {
			select {
			case c.Send <- msg:
			default:
			}
		}
	}
}

type jwtClaims struct {
	UserID string `json:"userId"`
	jwt.RegisteredClaims
}

func HandleConnectionHTTP(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("WS panic recovered: %v", r)
		}
	}()

	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		http.Error(w, "missing token", 401)
		return
	}

	claims := &jwtClaims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		return []byte(config.C.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		log.Println("WS auth failed:", err)
		http.Error(w, "invalid token", 401)
		return
	}

	userID, _ := bson.ObjectIDFromHex(claims.UserID)
	if userID.IsZero() {
		log.Println("WS invalid userId:", claims.UserID)
		http.Error(w, "invalid userId", 401)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WS upgrade error:", err)
		return
	}

	client := &Client{
		Conn:   conn,
		Rooms:  make(map[string]bool),
		UserID: userID.Hex(),
		Send:   make(chan []byte, 256),
	}
	H.Register(client)
	H.JoinUser(client, userID.Hex())

	log.Println("WS connected:", conn.RemoteAddr(), "user:", userID.Hex())

	go writePump(client)
	readPump(client)
}

func writePump(c *Client) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("writePump panic: %v", r)
		}
		H.Unregister(c)
	}()
	for msg := range c.Send {
		if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}

func readPump(c *Client) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("readPump panic: %v", r)
		}
		H.Unregister(c)
	}()
	c.Conn.SetReadLimit(65536)
	for {
		_, msg, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}

		var event struct {
			Type string      `json:"type"`
			Data interface{} `json:"data"`
		}
		if err := json.Unmarshal(msg, &event); err != nil {
			continue
		}

		switch event.Type {
		case "join_group":
			if data, ok := event.Data.(map[string]interface{}); ok {
				if groupID, ok := data["groupId"].(string); ok {
					H.JoinRoom(c, "group:"+groupID)
				}
			}
		case "leave_group":
			if data, ok := event.Data.(map[string]interface{}); ok {
				if groupID, ok := data["groupId"].(string); ok {
					H.LeaveRoom(c, "group:"+groupID)
				}
			}
		}
	}
	log.Println("WS disconnected:", c.Conn.RemoteAddr())
}
