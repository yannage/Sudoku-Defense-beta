/**
 * completion-bonuses.js - Handles bonus effects for completing Sudoku units
 * This module rewards players for completing rows, columns, and 3x3 grids
 * with their choice of damage, points, or currency bonuses
 */

const CompletionBonusModule = (function() {
    // Bonus types and their multipliers
    const BONUS_TYPES = {
        DAMAGE: {
            multiplier: 1.35,  // 35% damage increase
            icon: '⚔️',
            description: 'Towers do 35% more damage'
        },
        POINTS: {
            multiplier: 2.0,   // Double points from enemies defeated
            icon: '🏆',
            description: 'Double points earned from defeated enemies'
        },
        CURRENCY: {
            multiplier: 1.75,  // 75% more currency
            icon: '💰',
            description: '75% more currency from defeated enemies'
        }
    };
    
    // Track active bonuses
    const rowBonuses = {};     // Format: "row-0": {type: "DAMAGE", expiry: null}
    const columnBonuses = {};  // Format: "col-3": {type: "POINTS", expiry: null}
    const gridBonuses = {};    // Format: "grid-1-2": {type: "CURRENCY", expiry: null}
    
    /**
     * Called when a unit (row, column, or grid) is completed
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     */
    function onUnitCompleted(unitType, unitIndex) {
        console.log(`Unit completed: ${unitType} ${unitIndex}`);
        
        // Pause the game (optional - remove if you don't want to pause)
        if (window.GameLoop && typeof GameLoop.pause === 'function') {
            GameLoop.pause();
        }
        
        // Display the choice modal
        showBonusChoiceModal(unitType, unitIndex);
    }
    
    /**
     * Show the bonus choice modal
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     */
    function showBonusChoiceModal(unitType, unitIndex) {
        // Create modal if it doesn't exist
        let modal = document.getElementById('bonus-choice-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'bonus-choice-modal';
            modal.className = 'bonus-choice-modal';
            document.body.appendChild(modal);
        }
        
        // Set modal content
        modal.innerHTML = `
            <div class="bonus-choice-content">
                <h3>${capitalizeFirst(unitType)} ${getDisplayIndex(unitType, unitIndex)} Completed!</h3>
                <p>Choose a bonus effect:</p>
                <div class="bonus-options">
                    ${createBonusOptionHTML('DAMAGE', unitType, unitIndex)}
                    ${createBonusOptionHTML('POINTS', unitType, unitIndex)}
                    ${createBonusOptionHTML('CURRENCY', unitType, unitIndex)}
                </div>
            </div>
        `;
        
        // Add event listeners to the buttons
        const buttons = modal.querySelectorAll('.bonus-option-button');
        buttons.forEach(button => {
            button.addEventListener('click', function() {
                const bonusType = this.dataset.bonusType;
                applyBonus(unitType, unitIndex, bonusType);
                modal.classList.remove('active');
                
                // Resume game if it was paused
                if (window.GameLoop && typeof GameLoop.resume === 'function') {
                    GameLoop.resume();
                }
            });
        });
        
        // Show the modal
        modal.classList.add('active');
        
        // Add CSS if not already in stylesheet
        addBonusModalStyles();
    }
    
    /**
     * Create HTML for a bonus option
     * @param {string} bonusType - Bonus type (DAMAGE, POINTS, CURRENCY)
     * @param {string} unitType - Type of unit
     * @param {number|string} unitIndex - Index of the unit
     * @returns {string} HTML for the bonus option
     */
    function createBonusOptionHTML(bonusType, unitType, unitIndex) {
        const bonus = BONUS_TYPES[bonusType];
        return `
            <div class="bonus-option">
                <button class="bonus-option-button" data-bonus-type="${bonusType}">
                    <span class="bonus-icon">${bonus.icon}</span>
                    <span class="bonus-name">${bonusType}</span>
                </button>
                <p class="bonus-description">${bonus.description}</p>
            </div>
        `;
    }
    
    /**
     * Apply the chosen bonus to the unit
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     * @param {string} bonusType - Type of bonus (DAMAGE, POINTS, CURRENCY)
     */
    function applyBonus(unitType, unitIndex, bonusType) {
        const bonusKey = `${unitType}-${unitIndex}`;
        const bonusData = {
            type: bonusType,
            expiry: null // Permanent until row is broken
        };
        
        // Store the bonus choice
        if (unitType === 'row') {
            rowBonuses[bonusKey] = bonusData;
        } else if (unitType === 'column') {
            columnBonuses[bonusKey] = bonusData;
        } else if (unitType === 'grid') {
            gridBonuses[bonusKey] = bonusData;
        }
        
        // Apply visual effect to the completed unit
        applyVisualEffect(unitType, unitIndex, bonusType);
        
        // Show confirmation message
        EventSystem.publish(GameEvents.STATUS_MESSAGE, 
            `${capitalizeFirst(unitType)} ${getDisplayIndex(unitType, unitIndex)} bonus: ${BONUS_TYPES[bonusType].description}`);
    }
    
    /**
     * Apply visual effect to cells in a completed unit
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     * @param {string} bonusType - Type of bonus (DAMAGE, POINTS, CURRENCY)
     */
    function applyVisualEffect(unitType, unitIndex, bonusType) {
        // Get the color for this bonus type
        const color = getBonusColor(bonusType);
        
        // Apply to all cells in the unit
        if (unitType === 'row') {
            const row = parseInt(unitIndex);
            for (let col = 0; col < 9; col++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) {
                    applyBonusStyles(cell, bonusType, color);
                }
            }
        } else if (unitType === 'column') {
            const col = parseInt(unitIndex);
            for (let row = 0; row < 9; row++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) {
                    applyBonusStyles(cell, bonusType, color);
                }
            }
        } else if (unitType === 'grid') {
            const [gridRow, gridCol] = unitIndex.split('-').map(Number);
            for (let r = 0; r < 3; r++) {
                for (let c = 0; c < 3; c++) {
                    const row = gridRow * 3 + r;
                    const col = gridCol * 3 + c;
                    const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                    if (cell) {
                        applyBonusStyles(cell, bonusType, color);
                    }
                }
            }
        }
        
        // Add animation effect
        animateCompletedUnit(unitType, unitIndex, bonusType);
    }
    
    /**
     * Apply bonus styles to a cell
     * @param {HTMLElement} cell - The cell element
     * @param {string} bonusType - Type of bonus (DAMAGE, POINTS, CURRENCY)
     * @param {string} color - CSS color for the bonus
     */
    function applyBonusStyles(cell, bonusType, color) {
        // Clear previous bonus styles
        cell.classList.remove('bonus-damage', 'bonus-points', 'bonus-currency');
        
        // Add appropriate class
        cell.classList.add(`bonus-${bonusType.toLowerCase()}`);
        
        // Apply styles directly for immediate effect
        cell.style.boxShadow = `0 0 8px ${color}`;
        cell.style.border = `2px solid ${color}`;
    }
    
    /**
     * Animate a completed unit
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     * @param {string} bonusType - Type of bonus (DAMAGE, POINTS, CURRENCY)
     */
    function animateCompletedUnit(unitType, unitIndex, bonusType) {
        // Get cells in the unit
        const cells = [];
        
        if (unitType === 'row') {
            const row = parseInt(unitIndex);
            for (let col = 0; col < 9; col++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) cells.push(cell);
            }
        } else if (unitType === 'column') {
            const col = parseInt(unitIndex);
            for (let row = 0; row < 9; row++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) cells.push(cell);
            }
        } else if (unitType === 'grid') {
            const [gridRow, gridCol] = unitIndex.split('-').map(Number);
            for (let r = 0; r < 3; r++) {
                for (let c = 0; c < 3; c++) {
                    const row = gridRow * 3 + r;
                    const col = gridCol * 3 + c;
                    const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                    if (cell) cells.push(cell);
                }
            }
        }
        
        // Add flash animation to each cell with delay
        cells.forEach((cell, i) => {
            setTimeout(() => {
                cell.classList.add('bonus-flash');
                setTimeout(() => {
                    cell.classList.remove('bonus-flash');
                }, 500);
            }, i * 50);
        });
    }
    
    /**
     * Remove visual effects from cells in a unit
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     */
    function removeVisualEffect(unitType, unitIndex) {
        // Remove styles from all cells in the unit
        if (unitType === 'row') {
            const row = parseInt(unitIndex);
            for (let col = 0; col < 9; col++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) {
                    removeBonusStyles(cell);
                }
            }
        } else if (unitType === 'column') {
            const col = parseInt(unitIndex);
            for (let row = 0; row < 9; row++) {
                const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                if (cell) {
                    removeBonusStyles(cell);
                }
            }
        } else if (unitType === 'grid') {
            const [gridRow, gridCol] = unitIndex.split('-').map(Number);
            for (let r = 0; r < 3; r++) {
                for (let c = 0; c < 3; c++) {
                    const row = gridRow * 3 + r;
                    const col = gridCol * 3 + c;
                    const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                    if (cell) {
                        removeBonusStyles(cell);
                    }
                }
            }
        }
    }
    
    /**
     * Remove bonus styles from a cell
     * @param {HTMLElement} cell - The cell element
     */
    function removeBonusStyles(cell) {
        cell.classList.remove('bonus-damage', 'bonus-points', 'bonus-currency');
        cell.style.boxShadow = '';
        cell.style.border = '';
    }
    
    /**
     * Get color for a bonus type
     * @param {string} bonusType - Type of bonus (DAMAGE, POINTS, CURRENCY)
     * @returns {string} CSS color
     */
    function getBonusColor(bonusType) {
        switch (bonusType) {
            case 'DAMAGE': return '#ff4d4d'; // Red for damage
            case 'POINTS': return '#4d4dff'; // Blue for points
            case 'CURRENCY': return '#ffd700'; // Gold for currency
            default: return '#ffffff';
        }
    }
    
    /**
     * Apply effects to tower attacks based on active bonuses
     * @param {Object} tower - The tower making the attack
     * @param {Object} enemy - The enemy being attacked
     * @param {number} basePoints - Base points for defeating the enemy
     * @param {number} baseCurrency - Base currency for defeating the enemy
     * @returns {Object} Modified damage, points, and currency values
     */
    function applyEffects(tower, enemy, basePoints, baseCurrency) {
        let damageMult = 1.0;
        let pointsMult = 1.0;
        let currencyMult = 1.0;
        
        // Check row bonuses
        const rowKey = `row-${tower.row}`;
        if (rowBonuses[rowKey]) {
            const bonusType = rowBonuses[rowKey].type;
            if (bonusType === 'DAMAGE') damageMult *= BONUS_TYPES.DAMAGE.multiplier;
            if (bonusType === 'POINTS') pointsMult *= BONUS_TYPES.POINTS.multiplier;
            if (bonusType === 'CURRENCY') currencyMult *= BONUS_TYPES.CURRENCY.multiplier;
        }
        
        // Check column bonuses
        const colKey = `column-${tower.col}`;
        if (columnBonuses[colKey]) {
            const bonusType = columnBonuses[colKey].type;
            if (bonusType === 'DAMAGE') damageMult *= BONUS_TYPES.DAMAGE.multiplier;
            if (bonusType === 'POINTS') pointsMult *= BONUS_TYPES.POINTS.multiplier;
            if (bonusType === 'CURRENCY') currencyMult *= BONUS_TYPES.CURRENCY.multiplier;
        }
        
        // Check grid bonuses
        const gridRow = Math.floor(tower.row / 3);
        const gridCol = Math.floor(tower.col / 3);
        const gridKey = `grid-${gridRow}-${gridCol}`;
        if (gridBonuses[gridKey]) {
            const bonusType = gridBonuses[gridKey].type;
            if (bonusType === 'DAMAGE') damageMult *= BONUS_TYPES.DAMAGE.multiplier;
            if (bonusType === 'POINTS') pointsMult *= BONUS_TYPES.POINTS.multiplier;
            if (bonusType === 'CURRENCY') currencyMult *= BONUS_TYPES.CURRENCY.multiplier;
        }
        
        return {
            damage: Math.floor(tower.damage * damageMult),
            points: Math.floor(basePoints * pointsMult),
            currency: Math.floor(baseCurrency * currencyMult)
        };
    }
    
    /**
     * Check if a unit is still complete
     * @param {string} unitType - Type of unit ('row', 'column', or 'grid')
     * @param {number|string} unitIndex - Index of the unit
     * @returns {boolean} Whether the unit is still complete
     */
    function checkUnitCompletion(unitType, unitIndex) {
        // Rely on SudokuCompletion to determine if a unit is complete
        if (!window.SudokuCompletion || typeof SudokuCompletion.getCompletionStatus !== 'function') {
            return false;
        }
        
        const completionStatus = SudokuCompletion.getCompletionStatus();
        const bonusKey = `${unitType}-${unitIndex}`;
        
        let isComplete = false;
        
        if (unitType === 'row') {
            isComplete = completionStatus.rows.includes(parseInt(unitIndex));
            
            if (!isComplete && rowBonuses[bonusKey]) {
                delete rowBonuses[bonusKey];
                removeVisualEffect(unitType, unitIndex);
            }
        } else if (unitType === 'column') {
            isComplete = completionStatus.columns.includes(parseInt(unitIndex));
            
            if (!isComplete && columnBonuses[bonusKey]) {
                delete columnBonuses[bonusKey];
                removeVisualEffect(unitType, unitIndex);
            }
        } else if (unitType === 'grid') {
            isComplete = completionStatus.grids.includes(unitIndex);
            
            if (!isComplete && gridBonuses[bonusKey]) {
                delete gridBonuses[bonusKey];
                removeVisualEffect(unitType, unitIndex);
            }
        }
        
        return isComplete;
    }
    
    /**
     * Check all active bonuses to see if units are still complete
     */
    function checkBoardCompletions() {
        // Check all rows, columns, and grids
        for (const key in rowBonuses) {
            const rowIndex = key.split('-')[1];
            checkUnitCompletion('row', rowIndex);
        }
        
        for (const key in columnBonuses) {
            const colIndex = key.split('-')[1];
            checkUnitCompletion('column', colIndex);
        }
        
        for (const key in gridBonuses) {
            const gridIndex = key.split('-')[1];
            checkUnitCompletion('grid', gridIndex);
        }
    }
    
    /**
     * Add styles for the bonus modal to the document
     */
    function addBonusModalStyles() {
        // Check if styles are already added
        if (document.getElementById('bonus-modal-styles')) {
            return;
        }
        
        // Create style element
        const style = document.createElement('style');
        style.id = 'bonus-modal-styles';
        style.textContent = `
            /* Modal styling */
            .bonus-choice-modal {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(0, 0, 0, 0.7);
                display: flex;
                justify-content: center;
                align-items: center;
                z-index: 1000;
                opacity: 0;
                pointer-events: none;
                transition: opacity 0.3s;
            }
            
            .bonus-choice-modal.active {
                opacity: 1;
                pointer-events: all;
            }
            
            .bonus-choice-content {
                background-color: white;
                padding: 25px;
                border-radius: 8px;
                max-width: 500px;
                width: 90%;
                text-align: center;
            }
            
            .bonus-options {
                display: flex;
                justify-content: space-around;
                margin-top: 20px;
            }
            
            .bonus-option {
                flex: 1;
                margin: 0 10px;
                display: flex;
                flex-direction: column;
                align-items: center;
            }
            
            .bonus-option-button {
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 15px;
                background-color: #f5f5f5;
                border: 2px solid #ddd;
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.2s;
                width: 100%;
            }
            
            .bonus-option-button:hover {
                transform: translateY(-3px);
                box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            }
            
            .bonus-icon {
                font-size: 24px;
                margin-bottom: 8px;
            }
            
            .bonus-name {
                font-weight: bold;
            }
            
            .bonus-description {
                font-size: 12px;
                margin-top: 8px;
                color: #666;
            }
            
            /* Tower bonus styling */
            .bonus-damage {
                border: 2px solid #ff4d4d !important;
                box-shadow: 0 0 8px #ff4d4d !important;
            }
            
            .bonus-points {
                border: 2px solid #4d4dff !important;
                box-shadow: 0 0 8px #4d4dff !important;
            }
            
            .bonus-currency {
                border: 2px solid #ffd700 !important;
                box-shadow: 0 0 8px #ffd700 !important;
            }
            
            /* Animation for completed units */
            @keyframes bonus-flash {
                0% { transform: scale(1); background-color: rgba(255,255,255,0.5); }
                50% { transform: scale(1.1); background-color: rgba(255,255,255,0.8); }
                100% { transform: scale(1); background-color: rgba(255,255,255,0); }
            }
            
            .bonus-flash {
                animation: bonus-flash 0.5s ease-in-out;
                z-index: 30;
                pointer-events: none;
            }
        `;
        
        document.head.appendChild(style);
    }
    
    // Helper functions for display
    function capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }
    
    function getDisplayIndex(unitType, unitIndex) {
        if (unitType === 'grid') {
            const [row, col] = unitIndex.split('-').map(Number);
            return `${row+1},${col+1}`;
        }
        return parseInt(unitIndex) + 1;
    }
    
    // Initialize
    function init() {
        // Add modal styles
        addBonusModalStyles();
        
        // Set up event listeners
        EventSystem.subscribe(GameEvents.GAME_INIT, function() {
            // Clear all bonuses when game is initialized
            Object.keys(rowBonuses).forEach(key => delete rowBonuses[key]);
            Object.keys(columnBonuses).forEach(key => delete columnBonuses[key]);
            Object.keys(gridBonuses).forEach(key => delete gridBonuses[key]);
        });
        
        // Listen for board changes to check completions
        EventSystem.subscribe(GameEvents.TOWER_PLACED, checkBoardCompletions);
        EventSystem.subscribe(GameEvents.TOWER_REMOVED, checkBoardCompletions);
    }
    
    // Initialize the module
    init();
    
    // Public API
    return {
        onUnitCompleted,
        applyEffects,
        checkBoardCompletions,
        getBonuses: function() {
            return {
                rows: { ...rowBonuses },
                columns: { ...columnBonuses },
                grids: { ...gridBonuses }
            };
        }
    };
})();

// Make module available globally
window.CompletionBonusModule = CompletionBonusModule;