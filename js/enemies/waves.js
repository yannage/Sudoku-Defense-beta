/**
 * waves.js - Handles enemy wave generation and management
 * This module creates and manages waves of enemies.
 */

const EnemyWaves = (function() {
    // Private variables
    let enemies = [];
    let enemyId = 0;
    let waveNumber = 1;
    let isWaveActive = false;
    let spawnInterval = null;
    let enemiesRemaining = 0;
    
    /**
     * Initialize the waves module
     * @param {Object} options - Initialization options
     */
    function init(options = {}) {
        enemies = [];
        enemyId = 0;
        waveNumber = 1;
        isWaveActive = false;
        enemiesRemaining = 0;
        
        // Stop any active spawn interval
        if (spawnInterval) {
            clearInterval(spawnInterval);
            spawnInterval = null;
        }
    }
    
    /**
     * Create a new enemy
     * @param {number|string} type - Enemy type
     * @returns {Object} The created enemy
     */
    function createEnemy(type) {
        if (!window.EnemyTypes || !window.EnemyMovement) {
            console.error("Required modules not found");
            return null;
        }
        
        // Get enemy type data
        const typeData = EnemyTypes.getEnemyType(type);
        if (!typeData) {
            console.error("Invalid enemy type:", type);
            return null;
        }
        
        // Apply wave difficulty scaling
        const scaledData = EnemyTypes.applyWaveScaling(typeData, waveNumber);
        
        // Get starting position
        const startPos = EnemyMovement.getStartingPosition();
        
        // Create the enemy
        const enemy = {
            id: `enemy_${++enemyId}`,
            type: type,
            emoji: scaledData.emoji,
            health: scaledData.health,
            maxHealth: scaledData.maxHealth,
            speed: scaledData.speed,
            reward: scaledData.reward,
            points: scaledData.points,
            x: startPos.x,
            y: startPos.y,
            pathIndex: startPos.pathIndex,
            progress: startPos.progress,
            active: true
        };
        
        // Add to enemies array
        enemies.push(enemy);
        
        // Publish enemy spawn event
        EventSystem.publish(GameEvents.ENEMY_SPAWN, enemy);
        
        return enemy;
    }
    
    /**
     * Start a wave of enemies
     */
    function startWave() {
        if (isWaveActive) {
            return;
        }
        
        // Make sure we have a path
        const path = EnemyMovement.getPath();
        if (path.length === 0) {
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Cannot start wave: No path defined!");
            return;
        }
        
        isWaveActive = true;
        
        // Calculate number of enemies based on wave number
        const baseEnemyCount = 6;
        const enemyCount = baseEnemyCount + Math.floor((waveNumber - 1) * 3);
        enemiesRemaining = enemyCount;
        
        // Publish wave start event
        EventSystem.publish(GameEvents.WAVE_START, {
            waveNumber: waveNumber,
            enemyCount: enemyCount
        });
        
        EventSystem.publish(GameEvents.STATUS_MESSAGE, `Wave ${waveNumber} started! Enemies: ${enemyCount}`);
        
        let enemiesSpawned = 0;
        
        // Clear any existing interval
        if (spawnInterval) {
            clearInterval(spawnInterval);
        }
        
        // Spawn enemies at an interval
        spawnInterval = setInterval(() => {
            if (enemiesSpawned >= enemyCount) {
                clearInterval(spawnInterval);
                spawnInterval = null;
                return;
            }
            
            // Determine enemy type
            let enemyType;
            
            // Get available enemy types for this wave
            const availableTypes = EnemyTypes.getAvailableTypesForWave(waveNumber);
            const typeKeys = Object.keys(availableTypes);
            
            // Boss enemy at the end of each wave (last 10% of enemies)
            if (enemiesSpawned >= enemyCount * 0.9 && 'boss' in availableTypes) {
                enemyType = 'boss';
            } else {
                // Random enemy type based on available types
                // Filter out 'boss' for normal enemies
                const normalTypes = typeKeys.filter(type => type !== 'boss');
                enemyType = normalTypes[Math.floor(Math.random() * normalTypes.length)];
            }
            
            createEnemy(enemyType);
            enemiesSpawned++;
        }, 1000 / Math.sqrt(waveNumber)); // Spawn faster in higher waves
    }
    
    /**
     * Update all enemies
     * @param {number} deltaTime - Time elapsed since last update in seconds
     */
    function update(deltaTime) {
        if (!isWaveActive) {
            return;
        }
        
        let activeEnemies = 0;
        
        // Update each enemy
        for (let i = 0; i < enemies.length; i++) {
            const enemy = enemies[i];
            
            if (!enemy.active) {
                continue;
            }
            
            activeEnemies++;
            
            // Move enemy along the path
            const reachedEnd = EnemyMovement.moveEnemy(enemy, deltaTime);
            
            if (reachedEnd) {
                // Enemy reached the end of the path
                enemyReachedEnd(enemy);
            } else {
                // Publish enemy move event
                EventSystem.publish(GameEvents.ENEMY_MOVE, enemy);
            }
        }
        
        // Check if wave is complete (no active enemies and none remaining to spawn)
        if (activeEnemies === 0 && enemiesRemaining === 0 && !spawnInterval) {
            waveComplete();
        }
    }
    
    /**
     * Handle an enemy reaching the end of the path
     * @param {Object} enemy - The enemy that reached the end
     */
    function enemyReachedEnd(enemy) {
        enemy.active = false;
        
        // Remove from enemies array
        enemies = enemies.filter(e => e.id !== enemy.id);
        
        // Publish event
        EventSystem.publish(GameEvents.ENEMY_REACHED_END, enemy);
        
        // Decrement enemies remaining
        enemiesRemaining--;
    }
    
    /**
     * Damage an enemy
     * @param {string} enemyId - ID of the enemy to damage
     * @param {number} damage - Amount of damage to deal
     * @returns {boolean} Whether the enemy was killed
     */
    function damageEnemy(enemyId, damage) {
        const enemy = enemies.find(e => e.id === enemyId);
        
        if (!enemy || !enemy.active) {
            return false;
        }
        
        enemy.health -= damage;
        
        // Publish enemy damage event
        EventSystem.publish(GameEvents.ENEMY_DAMAGE, {
            enemy: enemy,
            damage: damage
        });
        
        // Check if enemy is defeated
        if (enemy.health <= 0) {
            defeatEnemy(enemy);
            return true;
        }
        
        return false;
    }
    
    /**
     * Defeat an enemy
     * @param {Object} enemy - The enemy to defeat
     */
    function defeatEnemy(enemy) {
        enemy.active = false;
        
        // Remove from enemies array
        enemies = enemies.filter(e => e.id !== enemy.id);
        
        // Publish enemy defeated event
        EventSystem.publish(GameEvents.ENEMY_DEFEATED, {
            enemy: enemy,
            reward: enemy.reward,
            points: enemy.points
        });
        
        // Decrement enemies remaining
        enemiesRemaining--;
    }
    
    /**
     * Handle wave completion
     */
    function waveComplete() {
        isWaveActive = false;
        
        // Clear any enemies that might still be around
        enemies = [];
        
        // Publish wave complete event
        EventSystem.publish(GameEvents.WAVE_COMPLETE, {
            waveNumber: waveNumber
        });
        
        // Increment wave number
        waveNumber++;
        
        // Generate new path for the next wave
        setTimeout(() => {
            if (window.SudokuBoard && typeof SudokuBoard.getPathCells === 'function') {
                // Clear existing path
                const pathCells = SudokuBoard.getPathCells();
                if (pathCells && typeof pathCells.clear === 'function') {
                    pathCells.clear();
                }
                
                // Generate new path
                if (window.SudokuGenerator && typeof SudokuGenerator.generateEnemyPath === 'function') {
                    const newPath = SudokuGenerator.generateEnemyPath();
                    EnemyMovement.setPath(Array.from(newPath).map(pos => pos.split(',').map(Number)));
                    
                    // Notify other modules of the path change
                    EventSystem.publish('path:updated', EnemyMovement.getPath());
                }
            }
        }, 500);
    }
    
    /**
     * Set the wave number
     * @param {number} num - New wave number
     */
    function setWaveNumber(num) {
        if (typeof num === 'number' && num > 0) {
            waveNumber = num;
        }
    }
    
    /**
     * Get all active enemies
     * @returns {Object[]} Array of active enemies
     */
    function getEnemies() {
        return enemies.filter(e => e.active);
    }
    
    /**
     * Get the current wave number
     * @returns {number} Current wave number
     */
    function getWaveNumber() {
        return waveNumber;
    }
    
    /**
     * Check if a wave is currently active
     * @returns {boolean} Whether a wave is active
     */
    function isWaveInProgress() {
        return isWaveActive;
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for game initialization
        EventSystem.subscribe(GameEvents.GAME_INIT, function(options) {
            init(options);
        });
        
        // Listen for new game
        EventSystem.subscribe(GameEvents.GAME_START, function() {
            init();
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        startWave,
        update,
        damageEnemy,
        getEnemies,
        getWaveNumber,
        setWaveNumber,
        isWaveInProgress
    };
})();

// Make module available globally
window.EnemyWaves = EnemyWaves;
window.EnemiesModule = window.EnemyWaves;