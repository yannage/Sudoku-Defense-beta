/**
 * player.js - Handles player state and actions
 * This module manages player resources, score, and lives
 */

const PlayerModule = (function() {
    // Private player state
    let state = {
        lives: 3,
        score: 0,
        currency: 150,
        selectedTower: null
    };
    
    /**
     * Initialize the player state
     * @param {Object} options - Initialization options
     */
    function init(options = {}) {
        state = {
            lives: options.lives || 3,
            score: options.score || 0,
            currency: options.currency || 150,
            selectedTower: null
        };
        
        console.log("PlayerModule initialized with currency:", state.currency);
        
        // Publish initial state
        publishState();
    }
    
    /**
     * Publish the current player state
     */
    function publishState() {
        console.log("Publishing player state: Lives=" + state.lives + ", Currency=" + state.currency);
        
        // Publish complete state
        EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
        
        // Also publish individual state components for direct updates
        EventSystem.publish(GameEvents.LIVES_CHANGE, state.lives);
        EventSystem.publish(GameEvents.SCORE_CHANGE, state.score);
        EventSystem.publish(GameEvents.CURRENCY_CHANGE, state.currency);
    }
    
    /**
     * Add currency to the player
     * @param {number} amount - Amount to add
     */
    function addCurrency(amount) {
        state.currency += amount;
        console.log("Currency added: " + amount + ", New balance: " + state.currency);
        
        // Update UI
        updateCurrencyDisplay();
        
        // Publish event
        EventSystem.publish(GameEvents.CURRENCY_CHANGE, state.currency);
        EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
    }
    
    /**
     * Spend currency
     * @param {number} amount - Amount to spend
     * @returns {boolean} Whether the transaction was successful
     */
    function spendCurrency(amount) {
        if (state.currency >= amount) {
            state.currency -= amount;
            console.log("Currency spent: " + amount + ", New balance: " + state.currency);
            
            // Update UI
            updateCurrencyDisplay();
            
            // Publish event
            EventSystem.publish(GameEvents.CURRENCY_CHANGE, state.currency);
            EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
            return true;
        }
        
        console.log("Not enough currency to spend: " + amount + ", Current balance: " + state.currency);
        return false;
    }
    
    /**
     * Add score to the player
     * @param {number} points - Points to add
     */
    function addScore(points) {
        state.score += points;
        console.log("Score added: " + points + ", New score: " + state.score);
        
        // Update UI
        updateScoreDisplay();
        
        // Publish event
        EventSystem.publish(GameEvents.SCORE_CHANGE, state.score);
        EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
    }
    
    /**
     * Lose a life
     * @returns {boolean} Whether the player still has lives
     */
    function loseLife() {
        state.lives--;
        console.log("Life lost, Remaining lives: " + state.lives);
        
        // Update UI
        updateLivesDisplay();
        
        // Publish event
        EventSystem.publish(GameEvents.LIVES_CHANGE, state.lives);
        EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
        
        // Check for game over
        if (state.lives <= 0) {
            console.log("Game over triggered");
            EventSystem.publish(GameEvents.GAME_OVER, {
                score: state.score
            });
            return false;
        }
        return true;
    }
    
    /**
     * Add a life to the player
     * @param {number} count - Number of lives to add
     */
    function addLife(count = 1) {
        state.lives += count;
        console.log("Lives added: " + count + ", New lives: " + state.lives);
        
        // Update UI
        updateLivesDisplay();
        
        // Publish event
        EventSystem.publish(GameEvents.LIVES_CHANGE, state.lives);
        EventSystem.publish(GameEvents.PLAYER_UPDATE, { ...state });
    }
    
    /**
     * Set the selected tower
     * @param {string|number|null} towerType - Type of tower selected or null to deselect
     */
    function selectTower(towerType) {
        console.log("Selecting tower type:", towerType);
        state.selectedTower = towerType;
        EventSystem.publish(GameEvents.TOWER_SELECTED, towerType);
    }
    
    /**
     * Get the selected tower
     * @returns {string|number|null} The selected tower type
     */
    function getSelectedTower() {
        return state.selectedTower;
    }
    
    /**
     * Get the current state
     * @returns {Object} Current player state
     */
    function getState() {
        return { ...state };
    }
    
    /**
     * Reset the player state
     */
    function reset() {
        console.log("PlayerModule reset");
        init();
    }
    
    /**
     * Update the currency display in the UI
     */
    function updateCurrencyDisplay() {
        const currencyElement = document.getElementById('currency-value');
        if (currencyElement) {
            currencyElement.textContent = state.currency;
        }
    }
    
    /**
     * Update the score display in the UI
     */
    function updateScoreDisplay() {
        const scoreElement = document.getElementById('score-value');
        if (scoreElement) {
            scoreElement.textContent = state.score;
        }
    }
    
    /**
     * Update the lives display in the UI
     */
    function updateLivesDisplay() {
        const livesElement = document.getElementById('lives-value');
        if (livesElement) {
            livesElement.textContent = state.lives;
        }
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for game initialization
        EventSystem.subscribe(GameEvents.GAME_INIT, function() {
            reset();
        });
        
        // Listen for new game
        EventSystem.subscribe(GameEvents.GAME_START, function() {
            reset();
        });
        
        // Listen for enemy defeated to add currency and score
        EventSystem.subscribe(GameEvents.ENEMY_DEFEATED, function(data) {
            // Use the points and currency from the event data if available
            const pointsToAdd = data.points || data.enemy.points || 5;
            const currencyToAdd = data.currency || data.enemy.reward || 10;
            
            addCurrency(currencyToAdd);
            addScore(pointsToAdd);
        });
        
        // Listen for enemy reaching the end to lose a life
        EventSystem.subscribe(GameEvents.ENEMY_REACHED_END, function() {
            loseLife();
        });
        
        // Listen for wave completion to reward the player
        EventSystem.subscribe(GameEvents.WAVE_COMPLETE, function(data) {
            const waveBonus = data.waveNumber * 20;
            addCurrency(waveBonus);
            addScore(waveBonus * 2);
            EventSystem.publish(GameEvents.STATUS_MESSAGE, `Wave completed! Bonus: ${waveBonus} currency`);
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        addCurrency,
        spendCurrency,
        addScore,
        loseLife,
        addLife,
        selectTower,
        getSelectedTower,
        getState,
        reset
    };
})();

// Make module available globally
window.PlayerModule = PlayerModule;

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    if (window.PlayerModule) {
        PlayerModule.init();
    }
});