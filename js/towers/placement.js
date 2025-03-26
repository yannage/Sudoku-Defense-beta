/**
 * placement.js - Handles tower placement logic
 * This module manages tower creation, positioning, and validation.
 */

const TowerPlacement = (function() {
    // Private variables
    let towers = [];
    let towerId = 0;
    let cellSize = 0;
    let incorrectTowers = new Set();
    
    /**
     * Initialize the tower placement module
     * @param {Object} options - Initialization options
     */
    function init(options = {}) {
        towers = [];
        towerId = 0;
        cellSize = options.cellSize || 55; // Default cell size
        incorrectTowers.clear();
        console.log("TowerPlacement initialized with cellSize:", cellSize);
    }
    
    /**
     * Create a new tower
     * @param {number|string} type - Tower type
     * @param {number} row - Row index on the grid
     * @param {number} col - Column index on the grid
     * @returns {Object|null} The created tower or null if creation failed
     */
    function createTower(type, row, col) {
        if (!window.TowerTypes || !window.SudokuBoard || !window.PlayerModule) {
            console.error("Required modules not found");
            return null;
        }
        
        console.log("TowerPlacement.createTower called with type:", type, "row:", row, "col:", col);
        
        const typeData = TowerTypes.getTowerType(type);
        
        if (!typeData) {
            console.error("Invalid tower type:", type);
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Invalid tower type!");
            return null;
        }
        
        // Check if player has enough currency
        const playerState = PlayerModule.getState();
        if (playerState.currency < typeData.cost) {
            console.log("Not enough currency to build tower");
            EventSystem.publish(GameEvents.STATUS_MESSAGE, `Not enough currency to build this tower! Need ${typeData.cost}`);
            return null;
        }
        
        // Check if the cell is fixed or on a path
        const fixedCells = SudokuBoard.getFixedCells();
        const pathCells = SudokuBoard.getPathCells();
        
        if (fixedCells && fixedCells[row] && fixedCells[row][col]) {
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Cannot place a tower on a fixed Sudoku cell!");
            return null;
        }
        
        if (pathCells && pathCells.has(`${row},${col}`)) {
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Cannot place a tower on the enemy path!");
            return null;
        }
        
        // Check if there's already a tower at this position
        if (getTowerAt(row, col)) {
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "There's already a tower in this cell!");
            return null;
        }
        
        // For number towers, check if the placement is correct according to the solution
        let isCorrect = true;
        const numberValue = parseInt(type);
        
        if (!isNaN(numberValue) && numberValue >= 1 && numberValue <= 9) {
            // Get the solution
            const solution = SudokuBoard.getSolution();
            
            // Check if the placement matches the solution
            if (solution && solution[row] && solution[row][col] !== numberValue) {
                isCorrect = false;
                EventSystem.publish(GameEvents.STATUS_MESSAGE, 
                    `Warning: This tower doesn't match the solution. It will be removed after the wave with 50% refund.`);
            }
        }
        
        // Calculate tower position
        const x = col * cellSize + cellSize / 2;
        const y = row * cellSize + cellSize / 2;
        
        const tower = {
            id: `tower_${++towerId}`,
            type: type,
            emoji: typeData.emoji,
            damage: typeData.damage,
            range: typeData.range * cellSize,
            attackSpeed: typeData.attackSpeed,
            attackCooldown: 0,
            level: 1,
            row: row,
            col: col,
            x: x,
            y: y,
            target: null,
            isCorrect: isCorrect
        };
        
        // Spend currency
        PlayerModule.spendCurrency(typeData.cost);
        
        // Add to towers array
        towers.push(tower);
        
        // For number towers, set the board value
        if (!isNaN(numberValue) && numberValue >= 1 && numberValue <= 9) {
            // Set the cell value in the Sudoku board
            // Use the proper method that will trigger completion checks
            if (SudokuBoard && typeof SudokuBoard.setCellValue === 'function') {
                SudokuBoard.setCellValue(row, col, numberValue);
            }
            
            // If incorrect, track it
            if (!isCorrect) {
                incorrectTowers.add(tower.id);
            }
        }
        
        // Publish tower placed event
        EventSystem.publish(GameEvents.TOWER_PLACED, tower);
        
        return tower;
    }
    
    /**
     * Remove a tower
     * @param {string} towerId - ID of the tower to remove
     * @returns {boolean} Whether the tower was removed
     */
    function removeTower(towerId) {
        const tower = towers.find(t => t.id === towerId);
        
        if (!tower) {
            return false;
        }
        
        // Remove from towers array
        towers = towers.filter(t => t.id !== towerId);
        
        // Remove number from Sudoku grid
        // Use setCellValue to clear the cell and trigger completion checks
        if (window.SudokuBoard && typeof SudokuBoard.setCellValue === 'function') {
            SudokuBoard.setCellValue(tower.row, tower.col, 0);
        }
        
        // Remove from incorrect towers set if it's there
        if (incorrectTowers.has(tower.id)) {
            incorrectTowers.delete(tower.id);
        }
        
        // Publish tower removed event
        EventSystem.publish(GameEvents.TOWER_REMOVED, tower);
        
        return true;
    }
    
    /**
     * Remove incorrect towers after a wave
     * @returns {number} Amount of currency refunded
     */
    function removeIncorrectTowers() {
        if (incorrectTowers.size === 0) return 0;
        
        let refundAmount = 0;
        const towersToRemove = [];
        
        // Identify towers to remove and calculate refund
        towers.forEach(tower => {
            if (incorrectTowers.has(tower.id)) {
                towersToRemove.push(tower);
                
                // Calculate 50% refund
                const towerData = TowerTypes.getTowerType(tower.type);
                if (towerData) {
                    const baseRefund = Math.floor(towerData.cost * 0.5);
                    const upgradeRefund = Math.floor(baseRefund * (tower.level - 1) * 0.75);
                    refundAmount += baseRefund + upgradeRefund;
                }
            }
        });
        
        // Process refund
        if (refundAmount > 0 && window.PlayerModule) {
            PlayerModule.addCurrency(refundAmount);
            EventSystem.publish(GameEvents.STATUS_MESSAGE, 
                `${towersToRemove.length} incorrect towers removed. Refunded ${refundAmount} currency.`);
        }
        
        // Remove towers
        towersToRemove.forEach(tower => {
            removeTower(tower.id);
        });
        
        // Clear tracking set
        incorrectTowers.clear();
        
        return refundAmount;
    }
    
    /**
     * Get all towers
     * @returns {Object[]} Array of towers
     */
    function getTowers() {
        return [...towers];
    }
    
    /**
     * Get a tower by position
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @returns {Object|null} The tower at the position or null if no tower found
     */
    function getTowerAt(row, col) {
        return towers.find(t => t.row === row && t.col === col);
    }
    
    /**
     * Get a tower by ID
     * @param {string} id - Tower ID
     * @returns {Object|null} The tower with the ID or null if not found
     */
    function getTowerById(id) {
        return towers.find(t => t.id === id);
    }
    
    /**
     * Set the cell size
     * @param {number} size - Cell size in pixels
     */
    function setCellSize(size) {
        cellSize = size;
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
        
        // Listen for wave completion to remove incorrect towers
        EventSystem.subscribe(GameEvents.WAVE_COMPLETE, function() {
            removeIncorrectTowers();
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        createTower,
        removeTower,
        removeIncorrectTowers,
        getTowers,
        getTowerAt,
        getTowerById,
        setCellSize,
        getIncorrectTowers: function() { return [...incorrectTowers]; }
    };
})();

// Make module available globally
window.TowerPlacement = TowerPlacement;