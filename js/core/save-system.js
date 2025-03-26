/**
 * save-system.js - Handles saving and loading game data using localStorage
 * This module provides functionality to store player scores and other game data persistently
 */

const SaveSystem = (function() {
    // Storage keys
    const STORAGE_KEYS = {
        HIGH_SCORE: 'sudoku_td_high_score',
        CURRENT_SCORE: 'sudoku_td_current_score',
        LAST_LEVEL: 'sudoku_td_last_level',
        LAST_WAVE: 'sudoku_td_last_wave',
        DIFFICULTY: 'sudoku_td_difficulty'
    };
    
    /**
     * Save data to localStorage
     * @param {string} key - Storage key
     * @param {string|number} value - Value to store
     */
    function saveData(key, value) {
        try {
            localStorage.setItem(key, String(value));
            console.log(`Data saved: ${key}=${value}`);
        } catch (error) {
            console.error(`Error saving data: ${error.message}`);
        }
    }
    
    /**
     * Load data from localStorage
     * @param {string} key - Storage key
     * @param {string|number} defaultValue - Default value if key not found
     * @returns {string} Stored value or default
     */
    function loadData(key, defaultValue = '') {
        try {
            const value = localStorage.getItem(key);
            return value !== null ? value : defaultValue;
        } catch (error) {
            console.error(`Error loading data: ${error.message}`);
            return defaultValue;
        }
    }
    
    /**
     * Save current score
     * Updates both current score and high score if needed
     */
    function saveScore() {
        if (!window.PlayerModule) {
            console.error("PlayerModule not available for saving score");
            return;
        }
        
        const currentScore = PlayerModule.getState().score;
        const highScore = getHighScore();
        
        // Save current score
        saveData(STORAGE_KEYS.CURRENT_SCORE, currentScore);
        
        // Update high score if current score is higher
        if (currentScore > highScore) {
            saveData(STORAGE_KEYS.HIGH_SCORE, currentScore);
            console.log(`New high score saved: ${currentScore}`);
            
            // Show notification for new high score
            showSaveNotification(`New high score: ${currentScore}!`);
        } else {
            // Show regular save notification
            showSaveNotification('Game progress saved');
        }
        
        // Save level and wave info
        if (window.LevelsModule) {
            saveData(STORAGE_KEYS.LAST_LEVEL, LevelsModule.getCurrentLevel());
            saveData(STORAGE_KEYS.LAST_WAVE, LevelsModule.getCurrentWave());
            saveData(STORAGE_KEYS.DIFFICULTY, LevelsModule.getDifficulty());
        }
    }
    
    /**
     * Get high score
     * @returns {number} High score
     */
    function getHighScore() {
        const highScore = loadData(STORAGE_KEYS.HIGH_SCORE, '0');
        return parseInt(highScore) || 0;
    }
    
    /**
     * Get last saved state
     * @returns {Object} Last saved state
     */
    function getLastSavedState() {
        return {
            highScore: getHighScore(),
            currentScore: parseInt(loadData(STORAGE_KEYS.CURRENT_SCORE, '0')) || 0,
            lastLevel: parseInt(loadData(STORAGE_KEYS.LAST_LEVEL, '1')) || 1,
            lastWave: parseInt(loadData(STORAGE_KEYS.LAST_WAVE, '1')) || 1,
            difficulty: loadData(STORAGE_KEYS.DIFFICULTY, 'medium')
        };
    }
    
    /**
     * Clear all saved data
     */
    function clearSavedData() {
        try {
            localStorage.removeItem(STORAGE_KEYS.HIGH_SCORE);
            localStorage.removeItem(STORAGE_KEYS.CURRENT_SCORE);
            localStorage.removeItem(STORAGE_KEYS.LAST_LEVEL);
            localStorage.removeItem(STORAGE_KEYS.LAST_WAVE);
            localStorage.removeItem(STORAGE_KEYS.DIFFICULTY);
            console.log("All saved game data cleared");
            
            // Show notification for data cleared
            showSaveNotification('Game data reset');
        } catch (error) {
            console.error(`Error clearing data: ${error.message}`);
        }
    }
    
    /**
     * Create save notification element if it doesn't exist
     * @returns {HTMLElement} The notification element
     */
    function createSaveNotification() {
        let notification = document.getElementById('save-notification');
        if (!notification) {
            notification = document.createElement('div');
            notification.id = 'save-notification';
            notification.className = 'save-notification';
            document.body.appendChild(notification);
            
            // Add CSS if not already in stylesheet
            if (!document.getElementById('save-notification-styles')) {
                const style = document.createElement('style');
                style.id = 'save-notification-styles';
                style.textContent = `
                    .save-notification {
                        position: fixed;
                        bottom: 20px;
                        right: 20px;
                        background-color: rgba(0, 0, 0, 0.7);
                        color: white;
                        padding: 10px 15px;
                        border-radius: 5px;
                        font-size: 0.9rem;
                        opacity: 0;
                        transform: translateY(20px);
                        transition: opacity 0.3s, transform 0.3s;
                        z-index: 1000;
                    }
                    .save-notification.visible {
                        opacity: 1;
                        transform: translateY(0);
                    }
                `;
                document.head.appendChild(style);
            }
        }
        return notification;
    }
    
    /**
     * Show a save notification
     * @param {string} message - Message to show
     */
    function showSaveNotification(message = 'Game saved') {
        const notification = createSaveNotification();
        notification.textContent = message;
        notification.classList.add('visible');
        
        // Hide notification after a delay
        setTimeout(() => {
            notification.classList.remove('visible');
        }, 2000);
    }
    
    /**
     * Initialize event listeners for automatic saving
     */
    function initEventListeners() {
        // Save on score change
        EventSystem.subscribe(GameEvents.SCORE_CHANGE, function(newScore) {
            saveData(STORAGE_KEYS.CURRENT_SCORE, newScore);
            
            // Update high score if needed
            const highScore = getHighScore();
            if (newScore > highScore) {
                saveData(STORAGE_KEYS.HIGH_SCORE, newScore);
                showSaveNotification(`New high score: ${newScore}!`);
            }
        });
        
        // Save on wave completion
        EventSystem.subscribe(GameEvents.WAVE_COMPLETE, saveScore);
        
        // Save on game over
        EventSystem.subscribe(GameEvents.GAME_OVER, saveScore);
        
        // Save when window is closed
        window.addEventListener('beforeunload', saveScore);
        
        // Also save periodically (every 30 seconds)
        setInterval(saveScore, 30000);
    }
    
    /**
     * Check if local storage is available
     * @returns {boolean} Whether localStorage is available
     */
    function isStorageAvailable() {
        try {
            const test = '__storage_test__';
            localStorage.setItem(test, test);
            localStorage.removeItem(test);
            return true;
        } catch (e) {
            return false;
        }
    }
    
    // Initialize with storage check
    const storageAvailable = isStorageAvailable();
    if (!storageAvailable) {
        console.warn("localStorage is not available. Game progress will not be saved.");
    } else {
        // Initialize event listeners if storage is available
        initEventListeners();
    }
    
    // Public API
    return {
        saveScore,
        getHighScore,
        getLastSavedState,
        clearSavedData,
        isStorageAvailable: function() { return storageAvailable; },
        showSaveNotification
    };
})();

// Make the module globally available
window.SaveSystem = SaveSystem;