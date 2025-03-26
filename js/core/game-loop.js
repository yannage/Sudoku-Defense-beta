/**
 * game-loop.js - Manages the main game loop and initialization
 * This module handles the core game lifecycle including initialization,
 * the game loop, pausing, resuming, and resetting.
 */

const GameLoop = (function() {
    // Private variables
    let isInitialized = false;
    let isRunning = false;
    let isPaused = false;
    let lastUpdateTime = 0;
    let boardElement = null;
    let cellSize = 0;
    
    /**
     * Initialize the game
     */
    function init() {
        if (isInitialized) {
            return;
        }
        
        console.log("Game initialization started");
        
        // Get the board element
        boardElement = document.getElementById('sudoku-board');
        
        // Calculate cell size based on board size
        const boardWidth = boardElement.clientWidth;
        cellSize = Math.floor(boardWidth / 9);
        
        // Initialize other modules with game settings
        const gameSettings = {
            cellSize: cellSize
        };
        
        // Publish initialization event
        EventSystem.publish(GameEvents.GAME_INIT, gameSettings);
        
        // Make sure UI is updated with initial values
        updateUI();
        
        // Start the game loop
        isInitialized = true;
        start();
        
        console.log("Game initialization completed");
    }
    
    /**
     * Start the game
     */
    function start() {
        if (isRunning) {
            return;
        }
        
        isRunning = true;
        isPaused = false;
        lastUpdateTime = performance.now();
        
        // Publish game start event
        EventSystem.publish(GameEvents.GAME_START);
        
        // Start game loop
        requestAnimationFrame(gameLoop);
    }
    
    /**
     * Pause the game
     */
    function pause() {
        if (!isRunning || isPaused) {
            return;
        }
        
        isPaused = true;
        
        // Publish game pause event
        EventSystem.publish(GameEvents.GAME_PAUSE);
    }
    
    /**
     * Resume the game
     */
    function resume() {
        if (!isRunning || !isPaused) {
            return;
        }
        
        isPaused = false;
        lastUpdateTime = performance.now();
        
        // Publish game resume event
        EventSystem.publish(GameEvents.GAME_RESUME);
        
        // Resume game loop
        requestAnimationFrame(gameLoop);
    }
    
    /**
     * Stop the game
     */
    function stop() {
        isRunning = false;
        isPaused = false;
    }
    
    /**
     * Reset the game
     */
    function reset() {
        console.log("Game reset started");
        
        // Stop the game loop
        stop();
        
        // Reset all modules explicitly
        if (window.PlayerModule) PlayerModule.reset();
        if (window.SudokuBoard) SudokuBoard.reset();
        if (window.EnemiesModule) EnemiesModule.init();
        if (window.TowersModule) TowersModule.init();
        
        // Force full re-initialization
        isInitialized = false;
        init();
        
        // Update UI with initial values
        updateUI();
        
        EventSystem.publish(GameEvents.STATUS_MESSAGE, "New game started!");
        
        console.log("Game reset completed");
    }
    
    /**
     * Main game loop
     * @param {number} timestamp - Current timestamp
     */
    function gameLoop(timestamp) {
        if (!isRunning || isPaused) {
            return;
        }
        
        // Calculate delta time
        const deltaTime = (timestamp - lastUpdateTime) / 1000; // Convert to seconds
        lastUpdateTime = timestamp;
        
        // Update game state
        update(deltaTime);
        
        // Render game state
        render();
        
        // Continue loop
        requestAnimationFrame(gameLoop);
    }
    
    /**
     * Update game state
     * @param {number} deltaTime - Time elapsed since last update
     */
    function update(deltaTime) {
        try {
            // Update enemies
            if (window.EnemiesModule && typeof EnemiesModule.update === 'function') {
                EnemiesModule.update(deltaTime);
            }
            
            // Update towers
            if (window.TowersModule && typeof TowersModule.update === 'function') {
                TowersModule.update(deltaTime);
            }
            
            // Check for completed Sudoku units
            if (window.SudokuCompletion && typeof SudokuCompletion.checkCompletions === 'function') {
                SudokuCompletion.checkCompletions();
            }
            
            // Update completion bonus system
            if (window.CompletionBonusModule && 
                typeof CompletionBonusModule.checkBoardCompletions === 'function') {
                CompletionBonusModule.checkBoardCompletions();
            }
        } catch (error) {
            console.error("Error in game update:", error);
        }
    }
    
    /**
     * Render game state
     */
    function render() {
        // Render the game elements
        if (window.BoardRenderer && typeof BoardRenderer.renderEnemies === 'function') {
            BoardRenderer.renderEnemies();
        }
    }
    
    /**
     * Update UI elements with current game state
     */
    function updateUI() {
        // Get current player state
        if (window.PlayerModule) {
            const playerState = PlayerModule.getState();
            
            // Update UI elements directly
            document.getElementById('score-value').textContent = playerState.score;
            document.getElementById('lives-value').textContent = playerState.lives;
            document.getElementById('currency-value').textContent = playerState.currency;
        }
        
        // Update wave number
        if (window.EnemiesModule) {
            document.getElementById('wave-value').textContent = EnemiesModule.getWaveNumber();
        }
        
        // Update high score if available
        if (window.SaveSystem && typeof SaveSystem.getHighScore === 'function') {
            const highScore = SaveSystem.getHighScore();
            const highScoreElement = document.getElementById('high-score-value');
            
            if (highScoreElement) {
                highScoreElement.textContent = highScore;
            }
        }
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for DOM content loaded to initialize the game
        document.addEventListener('DOMContentLoaded', function() {
            console.log("DOMContentLoaded event received");
            init();
        });
        
        // Subscribe to events for UI updates
        EventSystem.subscribe(GameEvents.PLAYER_UPDATE, updateUI);
        EventSystem.subscribe(GameEvents.CURRENCY_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.LIVES_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.SCORE_CHANGE, updateUI);
        EventSystem.subscribe(GameEvents.UI_UPDATE, updateUI);
        
        // Listen for window resize to adjust cell size
        window.addEventListener('resize', function() {
            if (!boardElement) return;
            
            const boardWidth = boardElement.clientWidth;
            cellSize = Math.floor(boardWidth / 9);
            
            // Update cell size in other modules
            if (window.EnemiesModule) EnemiesModule.setCellSize(cellSize);
            if (window.TowersModule) TowersModule.setCellSize(cellSize);
            
            // Update board display
            if (window.BoardRenderer) BoardRenderer.updateBoard();
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        start,
        pause,
        resume,
        stop,
        reset,
        updateUI,
        getCellSize: function() { return cellSize; },
        isPaused: function() { return isPaused; },
        isActive: function() { return isRunning && !isPaused; }
    };
})();

// Make module available globally
window.GameLoop = GameLoop;