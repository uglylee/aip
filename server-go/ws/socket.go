package ws

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
)

type Client struct {
	Conn   *websocket.Conn
	UserID string
	Rooms  map[string]bool
}

type Hub struct {
	clients    map[*Client]bool
	userConns  map[string][]*Client
	roomConns  map[string][]*Client
	mu         sync.RWMutex
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
	for _, c := range h.userConns[userID] {
		c.Conn.WriteJSON(fiber.Map{"event": event, "data": data})
	}
}

func (h *Hub) EmitToRoom(room string, event string, data interface{}) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, c := range h.roomConns[room] {
		c.Conn.WriteJSON(fiber.Map{"event": event, "data": data})
	}
}

func (h *Hub) EmitToAll(event string, data interface{}) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		c.Conn.WriteJSON(fiber.Map{"event": event, "data": data})
	}
}

func HandleConnection(c *websocket.Conn) {
	client := &Client{
		Conn:  c,
		Rooms: make(map[string]bool),
	}
	H.Register(client)
	defer H.Unregister(client)

	log.Println("WS connected:", c.RemoteAddr())

	for {
		_, msg, err := c.ReadMessage()
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
		case "join":
			if data, ok := event.Data.(map[string]interface{}); ok {
				if userID, ok := data["userId"].(string); ok {
					H.JoinUser(client, userID)
				}
			}
		case "join_group":
			if data, ok := event.Data.(map[string]interface{}); ok {
				if groupID, ok := data["groupId"].(string); ok {
					H.JoinRoom(client, "group:"+groupID)
				}
			}
		case "leave_group":
			if data, ok := event.Data.(map[string]interface{}); ok {
				if groupID, ok := data["groupId"].(string); ok {
					H.LeaveRoom(client, "group:"+groupID)
				}
			}
		}
	}
	log.Println("WS disconnected:", c.RemoteAddr())
}
