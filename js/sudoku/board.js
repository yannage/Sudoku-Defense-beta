/**
 * board.js - Handles the Sudoku board creation and basic operations
 * This module manages the board state, cell values, and provides methods
 * for accessing and modifying the board.
 */

const SudokuBoard = (function() {
    // Private variables
    let board = Array(9).fill().map(() => Array(9).fill(0));
    let solution = Array(9).fill().map(() => Array(9).fill(0));
    let fixedCells = Array(9).fill().map(() => Array(9).fill(false));
    let pathCells = new Set(); // Cells that form the enemy path
    let difficulty = 'medium'; // easy, medium, hard
    
    /**
     * Initialize the board
     * @param {Object} options - Options for board initialization
     */
    function init(options = {}) {
        board = Array(9).fill().map(() => Array(9).fill(0));
        solution = Array(9).fill().map(() => Array(9).fill(0));
        fixedCells = Array(9).fill().map(() => Array(9).fill(false));
        pathCells.clear();
        
        difficulty = options.difficulty || 'medium';
        
        // Generate a new board/solution
        if (window.SudokuGenerator) {
            const generated = SudokuGenerator.generatePuzzle(difficulty);
            board = generated.board;
            solution = generated.solution;
            fixedCells = generated.fixedCells;
        }
        
        // Generate the enemy path
        if (window.SudokuGenerator) {
            pathCells = SudokuGenerator.generateEnemyPath();
        }
        
        // Notify that the board has been initialized
        EventSystem.publish(GameEvents.SUDOKU_GENERATED, {
            board: board,
            solution: solution,
            fixedCells: fixedCells,
            pathCells: Array.from(pathCells).map(pos => pos.split(',').map(Number))
        });
    }
    
    /**
     * Get the current board state
     * @returns {number[][]} Current board state
     */
    function getBoard() {
        return board;
    }
    
    /**
     * Get the solution
     * @returns {number[][]} Solution board
     */
    function getSolution() {
        return solution;
    }
    
    /**
     * Get the fixed cells
     * @returns {boolean[][]} Fixed cells
     */
    function getFixedCells() {
        return fixedCells;
    }
    
    /**
     * Get the path cells
     * @returns {Set<string>} Path cells
     */
    function getPathCells() {
        return pathCells;
    }
    
    /**
     * Convert path cells to an array of coordinates
     * @returns {number[][]} Array of [row, col] coordinates
     */
    function getPathArray() {
        return Array.from(pathCells).map(pos => pos.split(',').map(Number));
    }
    
    /**
     * Set the value of a cell
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @param {number} value - Value to set
     * @returns {boolean} Whether the move was valid
     */
    function setCellValue(row, col, value) {
        console.log(`Attempting to set cell (${row},${col}) to value ${value}`);
        
        // Check if the cell is fixed
        if (fixedCells[row][col]) {
            console.log("Cell is fixed, cannot modify");
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Cannot place a tower on a fixed Sudoku cell!");
            return false;
        }
        
        // Check if the cell is on the enemy path
        if (pathCells.has(`${row},${col}`)) {
            console.log("Cell is on path, cannot modify");
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Cannot place a tower on the enemy path!");
            return false;
        }
        
        // If we're clearing a cell (value = 0), always allow it
        if (value === 0) {
            board[row][col] = 0;
            
            // Check for completions after clearing a cell
            if (window.SudokuCompletion) {
                SudokuCompletion.checkCompletions();
            }
            
            return true;
        }
        
        // Check if the move is valid according to Sudoku rules
        if (window.SudokuValidator && !SudokuValidator.isValidMove(board, row, col, value)) {
            console.log("Move is invalid according to Sudoku rules");
            EventSystem.publish(GameEvents.SUDOKU_CELL_INVALID, { row, col, value });
            
            // Get valid numbers for better user feedback
            const validNumbers = SudokuValidator.getPossibleValues(board, row, col);
            if (validNumbers.length > 0) {
                EventSystem.publish(GameEvents.STATUS_MESSAGE, 
                    `Invalid tower placement: Cannot place ${value} here. Valid options: ${validNumbers.join(', ')}`);
            } else {
                EventSystem.publish(GameEvents.STATUS_MESSAGE, "Invalid tower placement according to Sudoku rules!");
            }
            
            return false;
        }
        
        // Set the cell value
        board[row][col] = value;
        console.log(`Successfully set cell (${row},${col}) to ${value}`);
        
        // Publish event
        EventSystem.publish(GameEvents.SUDOKU_CELL_VALID, { row, col, value });
        
        // Check for completions
        if (window.SudokuCompletion) {
            SudokuCompletion.checkCompletions();
            
            // Check if the Sudoku is complete
            if (SudokuCompletion.isComplete()) {
                EventSystem.publish(GameEvents.SUDOKU_COMPLETE);
            }
        }
        
        return true;
    }
    
    /**
     * Set the game difficulty
     * @param {string} newDifficulty - The new difficulty (easy, medium, hard)
     */
    function setDifficulty(newDifficulty) {
        if (['easy', 'medium', 'hard'].includes(newDifficulty)) {
            difficulty = newDifficulty;
        }
    }
    
    /**
     * Reset the board to a new puzzle
     */
    function reset() {
        init({ difficulty: difficulty });
    }
    
    // Initialize event listeners
    function initEventListeners() {
        // Listen for game initialization
        EventSystem.subscribe(GameEvents.GAME_INIT, init);
        
        // Listen for new game
        EventSystem.subscribe(GameEvents.GAME_START, reset);
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        reset,
        getBoard,
        getSolution,
        getFixedCells,
        getPathCells,
        getPathArray,
        setCellValue,
        setDifficulty,
        getDifficulty: function() { return difficulty; }
    };
})();

// Make module available globally
window.SudokuBoard = SudokuBoard;