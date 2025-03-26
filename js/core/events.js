/**
 * events.js - Event system for communication between game modules
 * This module creates a central event bus for the game components to communicate
 * without direct dependencies on each other.
 */

const EventSystem = (function() {
    // Private event registry
    const events = {};
    
    return {
        /**
         * Subscribe to an event
         * @param {string} eventName - Name of the event to subscribe to
         * @param {function} callback - Function to call when event is triggered
         * @returns {function} Unsubscribe function
         */
        subscribe: function(eventName, callback) {
            // Create event array if it doesn't exist
            if (!events[eventName]) {
                events[eventName] = [];
            }
            
            // Add callback to event array
            events[eventName].push(callback);
            
            // Return unsubscribe function
            return function() {
                events[eventName] = events[eventName].filter(
                    eventCallback => eventCallback !== callback
                );
            };
        },
        
        /**
         * Publish an event
         * @param {string} eventName - Name of the event to publish
         * @param {*} data - Data to pass to subscribers
         */
        publish: function(eventName, data) {
            // Check if event exists and has subscribers
            if (!events[eventName]) {
                return;
            }
            
            // Call each subscriber with the data
            events[eventName].forEach(callback => {
                callback(data);
            });
        },
        
        /**
         * Get all registered event names
         * @returns {string[]} Array of event names
         */
        getEvents: function() {
            return Object.keys(events);
        },
        
        /**
         * Clear all subscribers for an event
         * @param {string} eventName - Name of the event to clear
         */
        clear: function(eventName) {
            if (events[eventName]) {
                events[eventName] = [];
            }
        },
        
        /**
         * Clear all events and subscribers
         */
        clearAll: function() {
            for (const eventName in events) {
                events[eventName] = [];
            }
        }
    };
})();

// List of predefined game events for documentation and consistency
const GameEvents = {
    // Game state events
    GAME_INIT: 'game:init',
    GAME_START: 'game:start',
    GAME_PAUSE: 'game:pause',
    GAME_RESUME: 'game:resume',
    GAME_OVER: 'game:over',
    GAME_WIN: 'game:win',
    
    // Player events
    PLAYER_UPDATE: 'player:update',
    CURRENCY_CHANGE: 'player:currency:change',
    LIVES_CHANGE: 'player:lives:change',
    SCORE_CHANGE: 'player:score:change',
    
    // Sudoku events
    SUDOKU_GENERATED: 'sudoku:generated',
    SUDOKU_CELL_SELECTED: 'sudoku:cell:selected',
    SUDOKU_CELL_VALID: 'sudoku:cell:valid',
    SUDOKU_CELL_INVALID: 'sudoku:cell:invalid',
    SUDOKU_COMPLETE: 'sudoku:complete',
    
    // Tower events
    TOWER_SELECTED: 'tower:selected',
    TOWER_PLACED: 'tower:placed',
    TOWER_REMOVED: 'tower:removed',
    TOWER_ATTACK: 'tower:attack',
    TOWER_UPGRADE: 'tower:upgrade',
    
    // Enemy events
    ENEMY_SPAWN: 'enemy:spawn',
    ENEMY_MOVE: 'enemy:move',
    ENEMY_DAMAGE: 'enemy:damage',
    ENEMY_DEFEATED: 'enemy:defeated',
    ENEMY_REACHED_END: 'enemy:reached:end',
    
    // Wave events
    WAVE_START: 'wave:start',
    WAVE_COMPLETE: 'wave:complete',
    
    // UI events
    UI_UPDATE: 'ui:update',
    STATUS_MESSAGE: 'ui:status:message'
};

// Export objects for global use
window.EventSystem = EventSystem;
window.GameEvents = GameEvents;