/**
 * completion.js - Handles detection of completed Sudoku units
 * This module checks for completed rows, columns, and 3x3 grids
 * and triggers the completion bonus system when units are completed.
 */

const SudokuCompletion = (function() {
    // Track completed units
    let completedRows = new Set();
    let completedColumns = new Set();
    let completedGrids = new Set();
    
    /**
     * Check for completed units (rows, columns, 3x3 grids)
     * Triggers completion bonus events for newly completed units
     */
    function checkCompletions() {
        // Get required data from SudokuBoard
        if (!window.SudokuBoard) {
            console.error("SudokuBoard module not found");
            return;
        }
        
        const board = SudokuBoard.getBoard();
        const pathCells = SudokuBoard.getPathCells();
        
        if (!board || !pathCells) {
            console.error("Required board data not available");
            return;
        }
        
        try {
            // Check rows
            checkRowCompletions(board, pathCells);
            
            // Check columns
            checkColumnCompletions(board, pathCells);
            
            // Check 3x3 grids
            checkGridCompletions(board, pathCells);
        } catch (error) {
            console.error("Error in checkCompletions:", error);
        }
    }
    
    /**
     * Check each row for completion
     * @param {number[][]} board - Current board state
     * @param {Set<string>} pathCells - Set of path cells to exclude
     */
    function checkRowCompletions(board, pathCells) {
        for (let row = 0; row < 9; row++) {
            // Get all non-path cells in this row
            const nonPathCells = [];
            for (let col = 0; col < 9; col++) {
                if (!pathCells.has(`${row},${col}`)) {
                    nonPathCells.push({row, col});
                }
            }
            
            // Skip if there are no non-path cells in this row
            if (nonPathCells.length === 0) continue;
            
            // Check if all non-path cells have numbers and form a valid Sudoku row
            let isComplete = true;
            const usedNumbers = new Set();
            
            for (const cell of nonPathCells) {
                const value = board[cell.row][cell.col];
                if (value === 0) {
                    // Empty cell means row is not complete
                    isComplete = false;
                    break;
                }
                
                // Check if this number is already used in the row
                if (usedNumbers.has(value)) {
                    // Duplicate number means row is not valid
                    isComplete = false;
                    break;
                }
                
                usedNumbers.add(value);
            }
            
            // Row is complete if all cells are filled and numbers are unique
            if (isComplete && usedNumbers.size === nonPathCells.length) {
                if (!completedRows.has(row)) {
                    completedRows.add(row);
                    console.log(`Row ${row} completed!`);
                    
                    // Trigger the completion bonus system
                    if (window.CompletionBonusModule && 
                        typeof CompletionBonusModule.onUnitCompleted === 'function') {
                        CompletionBonusModule.onUnitCompleted('row', row);
                    }
                }
            } else if (!isComplete && completedRows.has(row)) {
                completedRows.delete(row);
            }
        }
    }
    
    /**
     * Check each column for completion
     * @param {number[][]} board - Current board state
     * @param {Set<string>} pathCells - Set of path cells to exclude
     */
    function checkColumnCompletions(board, pathCells) {
        for (let col = 0; col < 9; col++) {
            // Get all non-path cells in this column
            const nonPathCells = [];
            for (let row = 0; row < 9; row++) {
                if (!pathCells.has(`${row},${col}`)) {
                    nonPathCells.push({row, col});
                }
            }
            
            // Skip if there are no non-path cells in this column
            if (nonPathCells.length === 0) continue;
            
            // Check if all non-path cells have numbers and form a valid Sudoku column
            let isComplete = true;
            const usedNumbers = new Set();
            
            for (const cell of nonPathCells) {
                const value = board[cell.row][cell.col];
                if (value === 0) {
                    // Empty cell means column is not complete
                    isComplete = false;
                    break;
                }
                
                // Check if this number is already used in the column
                if (usedNumbers.has(value)) {
                    // Duplicate number means column is not valid
                    isComplete = false;
                    break;
                }
                
                usedNumbers.add(value);
            }
            
            // Column is complete if all cells are filled and numbers are unique
            if (isComplete && usedNumbers.size === nonPathCells.length) {
                if (!completedColumns.has(col)) {
                    completedColumns.add(col);
                    console.log(`Column ${col} completed!`);
                    
                    // Trigger the completion bonus system
                    if (window.CompletionBonusModule && 
                        typeof CompletionBonusModule.onUnitCompleted === 'function') {
                        CompletionBonusModule.onUnitCompleted('column', col);
                    }
                }
            } else if (!isComplete && completedColumns.has(col)) {
                completedColumns.delete(col);
            }
        }
    }
    
    /**
     * Check each 3x3 grid for completion
     * @param {number[][]} board - Current board state
     * @param {Set<string>} pathCells - Set of path cells to exclude
     */
    function checkGridCompletions(board, pathCells) {
        for (let gridRow = 0; gridRow < 3; gridRow++) {
            for (let gridCol = 0; gridCol < 3; gridCol++) {
                // Get all non-path cells in this grid
                const nonPathCells = [];
                for (let i = 0; i < 3; i++) {
                    for (let j = 0; j < 3; j++) {
                        const row = gridRow * 3 + i;
                        const col = gridCol * 3 + j;
                        if (!pathCells.has(`${row},${col}`)) {
                            nonPathCells.push({row, col});
                        }
                    }
                }
                
                // Skip if there are no non-path cells in this grid
                if (nonPathCells.length === 0) continue;
                
                // Check if all non-path cells have numbers and form a valid Sudoku 3x3 grid
                let isComplete = true;
                const usedNumbers = new Set();
                
                for (const cell of nonPathCells) {
                    const value = board[cell.row][cell.col];
                    if (value === 0) {
                        // Empty cell means grid is not complete
                        isComplete = false;
                        break;
                    }
                    
                    // Check if this number is already used in the grid
                    if (usedNumbers.has(value)) {
                        // Duplicate number means grid is not valid
                        isComplete = false;
                        break;
                    }
                    
                    usedNumbers.add(value);
                }
                
                // Grid is complete if all cells are filled and numbers are unique
                const gridKey = `${gridRow}-${gridCol}`;
                
                if (isComplete && usedNumbers.size === nonPathCells.length) {
                    if (!completedGrids.has(gridKey)) {
                        completedGrids.add(gridKey);
                        console.log(`Grid ${gridKey} completed!`);
                        
                        // Trigger the completion bonus system
                        if (window.CompletionBonusModule && 
                            typeof CompletionBonusModule.onUnitCompleted === 'function') {
                            CompletionBonusModule.onUnitCompleted('grid', gridKey);
                        }
                    }
                } else if (!isComplete && completedGrids.has(gridKey)) {
                    completedGrids.delete(gridKey);
                }
            }
        }
    }
    
    /**
     * Check if the entire Sudoku is complete
     * @returns {boolean} Whether the Sudoku is complete
     */
    function isComplete() {
        // Get required data
        const board = SudokuBoard.getBoard();
        const pathCells = SudokuBoard.getPathCells();
        
        // Check if all non-path cells are filled
        for (let row = 0; row < 9; row++) {
            for (let col = 0; col < 9; col++) {
                if (board[row][col] === 0 && !pathCells.has(`${row},${col}`)) {
                    return false;
                }
            }
        }
        
        // Validate the board according to Sudoku rules
        if (window.SudokuValidator) {
            return SudokuValidator.isBoardValid(board, pathCells);
        }
        
        // If validator is not available, assume it's complete if all cells are filled
        return true;
    }
    
    /**
     * Get the completion status
     * @returns {Object} Status of completed rows, columns, and grids
     */
    function getCompletionStatus() {
        return {
            rows: Array.from(completedRows),
            columns: Array.from(completedColumns),
            grids: Array.from(completedGrids)
        };
    }
    
    /**
     * Reset the completion status
     */
    function reset() {
        completedRows.clear();
        completedColumns.clear();
        completedGrids.clear();
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for game initialization
        EventSystem.subscribe(GameEvents.GAME_INIT, reset);
        
        // Listen for new game
        EventSystem.subscribe(GameEvents.GAME_START, reset);
        
        // Listen for board generation
        EventSystem.subscribe(GameEvents.SUDOKU_GENERATED, reset);
        
        // Listen for tower placement and removal to check completions
        EventSystem.subscribe(GameEvents.TOWER_PLACED, checkCompletions);
        EventSystem.subscribe(GameEvents.TOWER_REMOVED, checkCompletions);
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        checkCompletions,
        isComplete,
        getCompletionStatus,
        reset
    };
})();

// Make module available globally
window.SudokuCompletion = SudokuCompletion;