/**
 * generator.js - Handles Sudoku puzzle generation
 * This module creates valid Sudoku puzzles and enemy paths.
 */

const SudokuGenerator = (function() {
    // Difficulty settings (number of cells to reveal)
    const difficultySettings = {
        easy: 40,
        medium: 30,
        hard: 25
    };
    
    /**
     * Check if a number can be placed in a specific position
     * @param {number[][]} grid - The Sudoku grid
     * @param {number} row - Row index
     * @param {number} col - Column index
     * @param {number} num - Number to check
     * @returns {boolean} Whether the number can be placed
     */
    function isValid(grid, row, col, num) {
        // Check row
        for (let x = 0; x < 9; x++) {
            if (grid[row][x] === num) {
                return false;
            }
        }
        
        // Check column
        for (let x = 0; x < 9; x++) {
            if (grid[x][col] === num) {
                return false;
            }
        }
        
        // Check 3x3 box
        let boxRow = Math.floor(row / 3) * 3;
        let boxCol = Math.floor(col / 3) * 3;
        
        for (let i = 0; i < 3; i++) {
            for (let j = 0; j < 3; j++) {
                if (grid[boxRow + i][boxCol + j] === num) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * Find an empty cell in the grid
     * @param {number[][]} grid - The Sudoku grid
     * @returns {[number, number]|null} Coordinates of empty cell or null if none found
     */
    function findEmptyCell(grid) {
        for (let row = 0; row < 9; row++) {
            for (let col = 0; col < 9; col++) {
                if (grid[row][col] === 0) {
                    return [row, col];
                }
            }
        }
        return null; // No empty cells
    }
    
    /**
     * Solve the Sudoku grid using backtracking
     * @param {number[][]} grid - The Sudoku grid to solve
     * @returns {boolean} Whether the puzzle was solved
     */
    function solveSudoku(grid) {
        let emptyCell = findEmptyCell(grid);
        if (!emptyCell) return true; // No empty cells left - puzzle solved
        
        const [row, col] = emptyCell;
        
        // Try each number 1-9
        for (let num = 1; num <= 9; num++) {
            if (isValid(grid, row, col, num)) {
                grid[row][col] = num;
                
                if (solveSudoku(grid)) {
                    return true;
                }
                
                grid[row][col] = 0; // Backtrack if the solution doesn't work
            }
        }
        
        return false; // Trigger backtracking
    }
    
    /**
     * Generate a complete, random Sudoku solution
     * @returns {number[][]} Completed Sudoku grid
     */
    function generateCompleteSolution() {
        // Start with an empty grid
        const grid = Array(9).fill().map(() => Array(9).fill(0));
        
        // Fill diagonal 3x3 boxes (these can be filled independently)
        for (let box = 0; box < 3; box++) {
            let nums = [1, 2, 3, 4, 5, 6, 7, 8, 9];
            shuffle(nums);
            
            for (let i = 0; i < 3; i++) {
                for (let j = 0; j < 3; j++) {
                    grid[box * 3 + i][box * 3 + j] = nums[i * 3 + j];
                }
            }
        }
        
        // Solve the rest of the puzzle using backtracking
        solveSudoku(grid);
        
        return grid;
    }
    
    /**
     * Create a puzzle from a complete solution by removing numbers
     * @param {number[][]} solution - Complete Sudoku solution
     * @param {Set<string>} pathCells - Set of cells reserved for the path
     * @param {number} numToReveal - Number of cells to reveal
     * @returns {Object} Board and fixed cells
     */
    function createPuzzleFromSolution(solution, pathCells, numToReveal) {
        // Create copies to work with
        const puzzle = JSON.parse(JSON.stringify(solution));
        const fixed = Array(9).fill().map(() => Array(9).fill(false));
        
        // Create a list of all positions
        let positions = [];
        for (let i = 0; i < 9; i++) {
            for (let j = 0; j < 9; j++) {
                positions.push([i, j]);
            }
        }
        
        // Shuffle positions
        shuffle(positions);
        
        // Keep track of cells to reveal
        let revealed = 0;
        
        // First, clear all path cells
        for (let pos of pathCells) {
            const [row, col] = pos.split(',').map(Number);
            puzzle[row][col] = 0;
            fixed[row][col] = false;
        }
        
        // Mark cells for revealing
        for (let [row, col] of positions) {
            // Skip path cells
            if (pathCells.has(`${row},${col}`)) {
                continue;
            }
            
            if (revealed < numToReveal) {
                // Keep this cell visible
                fixed[row][col] = true;
                revealed++;
            } else {
                // Hide this cell
                puzzle[row][col] = 0;
                fixed[row][col] = false;
            }
        }
        
        return { puzzle, fixed };
    }
    
    /**
     * Shuffle an array in place
     * @param {Array} array - Array to shuffle
     */
    function shuffle(array) {
        for (let i = array.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [array[i], array[j]] = [array[j], array[i]];
        }
    }
    
    /**
     * Generate a path for enemies to follow
     * Creates a non-overlapping path from a starting point to an end point
     * @returns {Set<string>} Set of path cell coordinates as "row,col" strings
     */
    function generateEnemyPath() {
        const pathCells = new Set();
        
        // Only use horizontal and vertical movements to avoid diagonal overlaps
        const directions = [
            [-1, 0], // up
            [1, 0],  // down
            [0, 1]   // right - only move right, never left to prevent overlaps
        ];
        
        // Start at a random position on the left edge
        let startRow = Math.floor(Math.random() * 9);
        let currentRow = startRow;
        let currentCol = 0;
        
        // Choose an end row for the right edge
        let endRow = Math.floor(Math.random() * 9);
        
        // Mark the starting position
        pathCells.add(`${currentRow},${currentCol}`);
        
        // Generate path until we reach the last column
        while (currentCol < 8) {
            let possibleMoves = [];
            
            // Check each direction for valid moves
            for (let [dr, dc] of directions) {
                let newRow = currentRow + dr;
                let newCol = currentCol + dc;
                
                if (newRow >= 0 && newRow < 9 && 
                    newCol >= 0 && newCol < 9 && 
                    !pathCells.has(`${newRow},${newCol}`)) {
                    possibleMoves.push([dr, dc]);
                }
            }
            
            // If no valid moves, try to move right
            if (possibleMoves.length === 0) {
                const newCol = currentCol + 1;
                if (newCol < 9 && !pathCells.has(`${currentRow},${newCol}`)) {
                    currentCol = newCol;
                    pathCells.add(`${currentRow},${currentCol}`);
                } else {
                    // If we can't progress, break out
                    break;
                }
                continue;
            }
            
            // Choose a random valid move
            const [dr, dc] = possibleMoves[Math.floor(Math.random() * possibleMoves.length)];
            currentRow += dr;
            currentCol += dc;
            pathCells.add(`${currentRow},${currentCol}`);
        }
        
        // If we haven't reached the end row in the last column, add a straight path to it
        if (currentCol === 8 && currentRow !== endRow) {
            const step = currentRow < endRow ? 1 : -1;
            for (let r = currentRow + step; step > 0 ? r <= endRow : r >= endRow; r += step) {
                pathCells.add(`${r},${currentCol}`);
            }
        }
        
        return pathCells;
    }
    
    /**
     * Check if we can connect two cells without crossing the path
     * @param {number} row1 - First cell row
     * @param {number} col1 - First cell column
     * @param {number} row2 - Second cell row
     * @param {number} col2 - Second cell column
     * @param {Set<string>} existingPath - Set of existing path cells
     * @returns {boolean} Whether cells can be connected
     */
    function canConnect(row1, col1, row2, col2, existingPath) {
        // For simplicity, only allow straight line connections
        if (row1 !== row2 && col1 !== col2) {
            return false;
        }
        
        // Check for obstacles in the path
        if (row1 === row2) {
            // Horizontal connection
            const minCol = Math.min(col1, col2);
            const maxCol = Math.max(col1, col2);
            for (let c = minCol + 1; c < maxCol; c++) {
                if (existingPath.has(`${row1},${c}`)) {
                    return false;
                }
            }
        } else {
            // Vertical connection
            const minRow = Math.min(row1, row2);
            const maxRow = Math.max(row1, row2);
            for (let r = minRow + 1; r < maxRow; r++) {
                if (existingPath.has(`${r},${col1}`)) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * Get cells needed to connect two points
     * @param {number} row1 - First cell row
     * @param {number} col1 - First cell column
     * @param {number} row2 - Second cell row
     * @param {number} col2 - Second cell column
     * @returns {string[]} Array of cell coordinates as strings
     */
    function getConnectingCells(row1, col1, row2, col2) {
        const cells = [];
        
        if (row1 === row2) {
            // Horizontal connection
            const minCol = Math.min(col1, col2);
            const maxCol = Math.max(col1, col2);
            for (let c = minCol + 1; c <= maxCol; c++) {
                cells.push(`${row1},${c}`);
            }
        } else if (col1 === col2) {
            // Vertical connection
            const minRow = Math.min(row1, row2);
            const maxRow = Math.max(row1, row2);
            for (let r = minRow + 1; r <= maxRow; r++) {
                cells.push(`${r},${col1}`);
            }
        }
        
        return cells;
    }
    
    /**
     * Generate a Sudoku puzzle with given difficulty
     * @param {string} difficulty - Puzzle difficulty (easy, medium, hard)
     * @returns {Object} Generated puzzle with board, solution, fixedCells
     */
    function generatePuzzle(difficulty = 'medium') {
        // Generate a path for enemies first
        const path = generateEnemyPath();
        
        // Generate a complete solution
        const solution = generateCompleteSolution();
        
        // Determine cells to reveal based on difficulty
        const cellsToReveal = difficultySettings[difficulty] || difficultySettings.medium;
        
        // Create puzzle from solution
        const { puzzle, fixed } = createPuzzleFromSolution(solution, path, cellsToReveal);
        
        return {
            board: puzzle,
            solution: solution,
            fixedCells: fixed,
            pathCells: path
        };
    }
    
    // Public API
    return {
        generatePuzzle,
        generateEnemyPath,
        difficultySettings
    };
})();

// Make module available globally
window.SudokuGenerator = SudokuGenerator;