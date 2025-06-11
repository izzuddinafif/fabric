package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/go-redis/redis/v8"
)

// RedisConfig holds Redis connection configuration
type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
}

var RDB *redis.Client
var Ctx = context.Background()

// ConnectRedis establishes connection to Redis using go-redis client
func ConnectRedis(cfg RedisConfig) *redis.Client {
	// Build Redis address
	addr := fmt.Sprintf("%s:%s", cfg.Host, cfg.Port)

	// Create Redis client options
	options := &redis.Options{
		Addr:         addr,
		Password:     cfg.Password, // Empty string if no password
		DB:           cfg.DB,       // Default DB is 0
		DialTimeout:  10 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		PoolSize:     10,
		MinIdleConns: 5,
	}

	// Create Redis client
	rdb := redis.NewClient(options)

	// Test the connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pong, err := rdb.Ping(ctx).Result()
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}

	log.Printf("Redis connection established successfully. Response: %s", pong)

	// Set global Redis client
	RDB = rdb
	return RDB
}

// CloseRedis closes the Redis connection
func CloseRedis() error {
	if RDB != nil {
		return RDB.Close()
	}
	return nil
}

// GetRedis returns the global Redis client instance
func GetRedis() *redis.Client {
	return RDB
}

// SetWithExpiration sets a key-value pair with expiration time
func SetWithExpiration(key string, value interface{}, expiration time.Duration) error {
	if RDB == nil {
		return fmt.Errorf("redis client not initialized")
	}
	return RDB.Set(Ctx, key, value, expiration).Err()
}

// Get retrieves a value by key
func Get(key string) (string, error) {
	if RDB == nil {
		return "", fmt.Errorf("redis client not initialized")
	}
	return RDB.Get(Ctx, key).Result()
}

// Delete removes a key
func Delete(key string) error {
	if RDB == nil {
		return fmt.Errorf("redis client not initialized")
	}
	return RDB.Del(Ctx, key).Err()
}

// Exists checks if a key exists
func Exists(key string) (bool, error) {
	if RDB == nil {
		return false, fmt.Errorf("redis client not initialized")
	}
	result, err := RDB.Exists(Ctx, key).Result()
	return result > 0, err
}
