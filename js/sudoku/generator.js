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
        
        // Keep track of visited columns to ensure we always make progress
        const visitedColumns = new Set([0]);
        
        // Generate path until we reach the last column
        while (currentCol < 8) {
            let possibleMoves = [];
            
            // Check each direction
            for (let [dr, dc] of directions) {
                let newRow = currentRow + dr;
                let newCol = currentCol + dc;
                
                // Check if the new position is valid
                if (
                    newRow >= 0 && newRow < 9 && 
                    newCol >= 0 && newCol < 9 && 
                    !pathCells.has(`${newRow},${newCol}`)
                ) {
                    // If we're already at the target column, only allow vertical moves
                    if (currentCol === 7 && newCol > currentCol) {
                        // We've reached column 7, only allow moving to endRow
                        if (newRow === endRow) {
                            possibleMoves = [[dr, dc]];
                            break;
                        }
                    } else {
                        // Otherwise, consider this move
                        possibleMoves.push([dr, dc]);
                    }
                }
            }
            
            // If no valid moves, force a move right
            if (possibleMoves.length === 0) {
                // Try to move right
                let newRow = currentRow;
                let newCol = currentCol + 1;
                
                if (newCol < 9 && !pathCells.has(`${newRow},${newCol}`)) {
                    currentRow = newRow;
                    currentCol = newCol;
                    pathCells.add(`${currentRow},${currentCol}`);
                    visitedColumns.add(currentCol);
                    continue;
                } else {
                    // If we can't move right, try to find any non-visited cell
                    let found = false;
                    for (let r = 0; r < 9; r++) {
                        for (let c = currentCol; c < 9; c++) {
                            if (!pathCells.has(`${r},${c}`)) {
                                // Check if we can connect to this cell without crossing the path
                                if (canConnect(currentRow, currentCol, r, c, pathCells)) {
                                    // Add connecting cells
                                    const connectingCells = getConnectingCells(currentRow, currentCol, r, c);
                                    for (const cell of connectingCells) {
                                        pathCells.add(cell);
                                    }
                                    currentRow = r;
                                    currentCol = c;
                                    found = true;
                                    break