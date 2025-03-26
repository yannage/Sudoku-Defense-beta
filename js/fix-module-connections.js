/**
 * Module aliases and connections to fix the initialization issues
 * This file bridges the gaps between module references in the codebase
 */

// === Module Aliases ===
// Create proper aliases for modules that are referenced with inconsistent names
window.TowersModule = {
    // Connect to the actual implementation modules
    init: function(options) {
        console.log("Initializing Towers Module with bridge...");
        if (window.TowerPlacement) {
            TowerPlacement.init(options);
        }
    },
    getTowerAt: function(row, col) {
        return window.TowerPlacement ? TowerPlacement.getTowerAt(row, col) : null;
    },
    getTowerCost: function(towerType) {
        return window.TowerTypes ? TowerTypes.getTowerCost(towerType) : 0;
    },
    createTower: function(type, row, col) {
        return window.TowerPlacement ? TowerPlacement.createTower(type, row, col) : null;
    },
    update: function(deltaTime) {
        if (window.TowerAttacks) {
            TowerAttacks.update(deltaTime);
        }
    }
};

window.EnemiesModule = {
    // Connect to enemy implementation modules
    init: function(options) {
        console.log("Initializing Enemies Module with bridge...");
        if (window.EnemyMovement) {
            EnemyMovement.init(options);
        }
    },
    update: function(deltaTime) {
        if (window.EnemyWaves) {
            EnemyWaves.update(deltaTime);
        }
    },
    getEnemies: function() {
        return window.EnemyWaves ? EnemyWaves.getEnemies() : [];
    },
    damageEnemy: function(enemyId, damage) {
        return window.EnemyWaves ? EnemyWaves.damageEnemy(enemyId, damage) : false;
    },
    getWaveNumber: function() {
        return window.EnemyWaves ? EnemyWaves.getWaveNumber() : 1;
    },
    setCellSize: function(size) {
        if (window.EnemyMovement) {
            EnemyMovement.setCellSize(size);
        }
    },
    startWave: function() {
        if (window.EnemyWaves) {
            EnemyWaves.startWave();
        }
    }
};

// === Missing Player Module ===
// This is referenced but not found in the provided files
window.PlayerModule = (function() {
    // Player state
    let state = {
        score: 0,
        lives: 3,
        currency: 100
    };
    
    let selectedTower = null;
    
    /**
     * Initialize player state
     */
    function init(options = {}) {
        state = {
            score: options.score || 0,
            lives: options.lives || 3,
            currency: options.currency || 100
        };
        
        // Update UI with initial values
        EventSystem.publish(GameEvents.PLAYER_UPDATE, state);
    }
    
    /**
     * Get the current player state
     * @returns {Object} Player state
     */
    function getState() {
        return { ...state };
    }
    
    /**
     * Add points to score
     * @param {number} points - Points to add
     */
    function addScore(points) {
        state.score += points;
        EventSystem.publish(GameEvents.SCORE_CHANGE, state.score);
    }
    
    /**
     * Add currency
     * @param {number} amount - Currency to add
     */
    function addCurrency(amount) {
        state.currency += amount;
        EventSystem.publish(GameEvents.CURRENCY_CHANGE, state.currency);
    }
    
    /**
     * Spend currency if possible
     * @param {number} amount - Amount to spend
     * @returns {boolean} Whether the spending was successful
     */
    function spendCurrency(amount) {
        if (state.currency >= amount) {
            state.currency -= amount;
            EventSystem.publish(GameEvents.CURRENCY_CHANGE, state.currency);
            return true;
        }
        return false;
    }
    
    /**
     * Lose a life
     * @returns {boolean} Whether the player still has lives
     */
    function loseLife() {
        state.lives--;
        EventSystem.publish(GameEvents.LIVES_CHANGE, state.lives);
        
        // Check for game over
        if (state.lives <= 0) {
            EventSystem.publish(GameEvents.GAME_OVER, {
                score: state.score,
                highScore: window.SaveSystem ? SaveSystem.getHighScore() : 0
            });
            return false;
        }
        
        return true;
    }
    
    /**
     * Select a tower type
     * @param {string} towerType - Type of tower to select
     */
    function selectTower(towerType) {
        selectedTower = towerType;
    }
    
    /**
     * Get the selected tower type
     * @returns {string|null} Selected tower type
     */
    function getSelectedTower() {
        return selectedTower;
    }
    
    /**
     * Reset player state
     */
    function reset() {
        init();
    }
    
    // Initialize event listeners
    function initEventListeners() {
        // Listen for enemy defeat to gain points and currency
        EventSystem.subscribe(GameEvents.ENEMY_DEFEATED, function(data) {
            if (data.enemy) {
                addScore(data.points || 5);
                addCurrency(data.reward || 10);
            }
        });
        
        // Listen for enemy reaching the end to lose a life
        EventSystem.subscribe(GameEvents.ENEMY_REACHED_END, function() {
            loseLife();
        });
        
        // Initialize when game initializes
        EventSystem.subscribe(GameEvents.GAME_INIT, init);
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        getState,
        addScore,
        addCurrency,
        spendCurrency,
        loseLife,
        selectTower,
        getSelectedTower,
        reset
    };
})();

// === Board Renderer Completion ===
// The file appears to be cut off, add the missing event handlers
if (window.BoardRenderer) {
    // Add missing handleCellClick function
    BoardRenderer.handleCellClick = function(row, col) {
        console.log(`Cell clicked: (${row}, ${col})`);
        
        // Check if a tower type is selected
        if (window.TowerSelector && TowerSelector.getSelectedTowerType()) {
            const towerType = TowerSelector.getSelectedTowerType();
            
            // Attempt to place tower
            if (window.TowersModule) {
                TowersModule.createTower(towerType, row, col);
            }
        } else {
            // No tower selected, show message
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Select a tower type first!");
        }
    };
    
    // Add missing renderEnemies function
    BoardRenderer.renderEnemies = function() {
        if (!window.EnemiesModule) return;
        
        // Get the enemies container
        let enemyContainer = document.getElementById('enemy-container');
        
        // Create container if it doesn't exist
        if (!enemyContainer) {
            enemyContainer = document.createElement('div');
            enemyContainer.id = 'enemy-container';
            enemyContainer.style.position = 'absolute';
            enemyContainer.style.top = '0';
            enemyContainer.style.left = '0';
            enemyContainer.style.width = '100%';
            enemyContainer.style.height = '100%';
            enemyContainer.style.pointerEvents = 'none';
            enemyContainer.style.zIndex = '10';
            
            const board = document.getElementById('sudoku-board');
            if (board) {
                board.appendChild(enemyContainer);
            }
        }
        
        // Get current enemies
        const enemies = EnemiesModule.getEnemies();
        
        // Update existing enemies and create new ones
        enemies.forEach(enemy => {
            // Check if enemy element exists
            let enemyElement = document.getElementById(enemy.id);
            
            if (!enemyElement) {
                // Create new enemy element
                enemyElement = document.createElement('div');
                enemyElement.id = enemy.id;
                enemyElement.className = 'enemy';
                enemyElement.textContent = enemy.emoji;
                
                // Create health bar
                const healthBar = document.createElement('div');
                healthBar.className = 'enemy-health-bar';
                const healthFill = document.createElement('div');
                healthFill.className = 'enemy-health-fill';
                healthBar.appendChild(healthFill);
                enemyElement.appendChild(healthBar);
                
                enemyContainer.appendChild(enemyElement);
            }
            
            // Update position
            enemyElement.style.transform = `translate(${enemy.x}px, ${enemy.y}px)`;
            
            // Update health bar
            const healthFill = enemyElement.querySelector('.enemy-health-fill');
            if (healthFill) {
                const healthPercent = (enemy.health / enemy.maxHealth) * 100;
                healthFill.style.width = `${healthPercent}%`;
            }
        });
        
        // Remove elements for enemies that no longer exist
        const enemyElements = enemyContainer.querySelectorAll('.enemy');
        enemyElements.forEach(element => {
            const id = element.id;
            if (!enemies.some(enemy => enemy.id === id)) {
                element.remove();
            }
        });
    };
    
    // Complete the setupEventListeners function
    BoardRenderer.setupEventListeners = function() {
        // Listen for Sudoku generation to update the board
        EventSystem.subscribe(GameEvents.SUDOKU_GENERATED, function() {
            BoardRenderer.updateBoard();
        });
        
        // Listen for tower placement to update the board
        EventSystem.subscribe(GameEvents.TOWER_PLACED, function() {
            BoardRenderer.updateBoard();
        });
        
        // Listen for tower removal to update the board
        EventSystem.subscribe(GameEvents.TOWER_REMOVED, function() {
            BoardRenderer.updateBoard();
        });
        
        // Add click handler for the start wave button
        const startWaveButton = document.getElementById('start-wave');
        if (startWaveButton) {
            startWaveButton.addEventListener('click', function() {
                if (window.EnemiesModule) {
                    if (!EnemiesModule.isWaveInProgress || !EnemiesModule.isWaveInProgress()) {
                        EnemiesModule.startWave();
                    } else {
                        EventSystem.publish(GameEvents.STATUS_MESSAGE, "Wave already in progress!");
                    }
                }
            });
        }
        
        // Add click handler for the new game button
        const newGameButton = document.getElementById('new-game');
        if (newGameButton) {
            newGameButton.addEventListener('click', function() {
                if (window.GameLoop) {
                    GameLoop.reset();
                }
            });
        }
    };
}

// === DOM Ready initialization function ===
document.addEventListener('DOMContentLoaded', function() {
    console.log("Module fix initialization");
    
    // Add scripts that need to be loaded first
    const coreScripts = [
        'js/core/events.js',
        'js/core/game-loop.js',
        'js/core/save-system.js',
        'js/sudoku/board.js'
    ];
    
    // Load core scripts
    coreScripts.forEach(src => {
        if (!document.querySelector(`script[src="${src}"]`)) {
            const script = document.createElement('script');
            script.src = src;
            script.async = false;
            document.head.appendChild(script);
        }
    });
});