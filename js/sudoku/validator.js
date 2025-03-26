/**
 * validator.js - Handles validation of Sudoku rules
 * This module provides functions to check if moves are valid
 * according to Sudoku rules and identifies possible values.
 */

const SudokuValidator = (function() {
    /**
     * Check if a move is valid according to Sudoku rules
     * @param {number[][]} board - Current board state
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @param {number} value - Value to check
     * @returns {boolean} Whether the move is valid
     */
    function isValidMove(board, row, col, value) {
        // Check row
        for (let i = 0; i < 9; i++) {
            if (i !== col && board[row][i] === value) {
                return false;
            }
        }
        
        // Check column
        for (let i = 0; i < 9; i++) {
            if (i !== row && board[i][col] === value) {
                return false;
            }
        }
        
        // Check 3x3 box
        let boxRow = Math.floor(row / 3) * 3;
        let boxCol = Math.floor(col / 3) * 3;
        
        for (let i = 0; i < 3; i++) {
            for (let j = 0; j < 3; j++) {
                if ((boxRow + i !== row || boxCol + j !== col) && 
                    board[boxRow + i][boxCol + j] === value) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * Get possible values for a cell
     * @param {number[][]} board - Current board state
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @returns {number[]} Array of valid values (1-9)
     */
    function getPossibleValues(board, row, col) {
        const possibleValues = [];
        
        for (let num = 1; num <= 9; num++) {
            if (isValidMove(board, row, col, num)) {
                possibleValues.push(num);
            }
        }
        
        return possibleValues;
    }
    
    /**
     * Check if the entire board is valid
     * @param {number[][]} board - Current board state
     * @param {Set<string>} [pathCells] - Optional set of path cells to exclude
     * @returns {boolean} Whether the board is valid
     */
    function isBoardValid(board, pathCells = new Set()) {
        // Check rows
        for (let row = 0; row < 9; row++) {
            const usedNumbers = new Set();
            for (let col = 0; col < 9; col++) {
                if (pathCells.has(`${row},${col}`)) continue;
                
                const value = board[row][col];
                if (value === 0) continue;
                
                if (usedNumbers.has(value)) {
                    return false;
                }
                
                usedNumbers.add(value);
            }
        }
        
        // Check columns
        for (let col = 0; col < 9; col++) {
            const usedNumbers = new Set();
            for (let row = 0; row < 9; row++) {
                if (pathCells.has(`${row},${col}`)) continue;
                
                const value = board[row][col];
                if (value === 0) continue;
                
                if (usedNumbers.has(value)) {
                    return false;
                }
                
                usedNumbers.add(value);
            }
        }
        
        // Check 3x3 boxes
        for (let boxRow = 0; boxRow < 3; boxRow++) {
            for (let boxCol = 0; boxCol < 3; boxCol++) {
                const usedNumbers = new Set();
                
                for (let i = 0; i < 3; i++) {
                    for (let j = 0; j < 3; j++) {
                        const row = boxRow * 3 + i;
                        const col = boxCol * 3 + j;
                        
                        if (pathCells.has(`${row},${col}`)) continue;
                        
                        const value = board[row][col];
                        if (value === 0) continue;
                        
                        if (usedNumbers.has(value)) {
                            return false;
                        }
                        
                        usedNumbers.add(value);
                    }
                }
            }
        }
        
        return true;
    }
    
    /**
     * Validate if a solution is correct
     * @param {number[][]} board - Current board state
     * @param {number[][]} solution - Solution to compare against
     * @param {Set<string>} [pathCells] - Optional set of path cells to exclude
     * @returns {boolean} Whether the board matches the solution
     */
    function validateSolution(board, solution, pathCells = new Set()) {
        for (let row = 0; row < 9; row++) {
            for (let col = 0; col < 9; col++) {
                if (pathCells.has(`${row},${col}`)) continue;
                
                if (board[row][col] !== 0 && board[row][col] !== solution[row][col]) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * Check if a specific cell value matches the solution
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @param {number} value - Value to check
     * @param {number[][]} solution - Solution to compare against
     * @returns {boolean} Whether the value matches the solution
     */
    function isCorrectValue(row, col, value, solution) {
        return solution[row][col] === value;
    }
    
    // Public API
    return {
        isValidMove,
        getPossibleValues,
        isBoardValid,
        validateSolution,
        isCorrectValue
    };
})();

// Make module available globally
window.SudokuValidator = SudokuValidator;