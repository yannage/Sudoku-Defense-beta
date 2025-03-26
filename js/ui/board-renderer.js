/**
 * board-renderer.js - Handles rendering the Sudoku board and game elements
 * This module manages the visual representation of the game board,
 * towers, enemies, and their animations.
 */

const BoardRenderer = (function() {
    // Private variables
    let boardElement = null;
    let cellSize = 0;
    
    /**
     * Initialize the board renderer
     */
    function init() {
        // Get the board element
        boardElement = document.getElementById('sudoku-board');
        
        if (!boardElement) {
            console.error("Board element not found");
            return;
        }
        
        // Calculate cell size
        cellSize = boardElement.clientWidth / 9;
        
        // Set up the Sudoku board
        setupBoard();
        
        // Add event listeners
        setupEventListeners();
        
        console.log("BoardRenderer initialized with cell size:", cellSize);
    }
    
    /**
     * Set up the Sudoku board
     */
    function setupBoard() {
        console.log("Setting up board");
        
        // Clear any existing board
        clearBoard();
        
        // Create cells
        for (let row = 0; row < 9; row++) {
            for (let col = 0; col < 9; col++) {
                const cell = document.createElement('div');
                cell.className = 'sudoku-cell';
                cell.dataset.row = row;
                cell.dataset.col = col;
                
                // Add click event listener
                cell.addEventListener('click', function() {
                    handleCellClick(row, col);
                });
                
                boardElement.appendChild(cell);
            }
        }
        
        // Count cells to ensure all were created
        console.log("Created " + boardElement.childElementCount + " cells");
        
        // Update board with initial values
        updateBoard();
    }
    
    /**
     * Clear the Sudoku board
     */
    function clearBoard() {
        console.log("Clearing board");
        while (boardElement.firstChild) {
            boardElement.removeChild(boardElement.firstChild);
        }
    }
    
    /**
     * Update the Sudoku board display
     */
    function updateBoard() {
        if (!window.SudokuBoard) {
            console.error("SudokuBoard module not found");
            return;
        }
        
        console.log("Updating board display");
        const board = SudokuBoard.getBoard();
        const fixedCells = SudokuBoard.getFixedCells();
        const pathCells = SudokuBoard.getPathCells();
        
        // Update each cell
        for (let row = 0; row < 9; row++) {
            for (let col = 0; col < 9; col++) {
                const cellElement = boardElement.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
                
                if (!cellElement) {
                    console.warn(`Cell element not found for row ${row}, col ${col}`);
                    continue;
                }
                
                // Clear previous classes
                cellElement.classList.remove('fixed', 'path');
                
                // Set value
                const value = board[row][col];
                cellElement.textContent = value > 0 ? value : '';
                
                // Mark fixed cells
                if (fixedCells[row][col]) {
                    cellElement.classList.add('fixed');
                }
                
                // Mark path cells - a cell can be both a path and have a number
                if (pathCells.has(`${row},${col}`)) {
                    cellElement.classList.add('path');
                }
                
                // Check for tower
                if (window.TowersModule) {
                    const tower = TowersModule.getTowerAt(row, col);
                    
                    if (tower && !pathCells.has(`${row},${col}`)) {
                        // Clear number and show tower emoji
                        cellElement.textContent = tower.emoji;
                        
                        // Add level indicator if tower level > 1
                        if (tower.level > 1) {
                            const levelIndicator = document.createElement('span');
                            levelIndicator.className = 'tower-level';
                            levelIndicator.textContent = tower.level;
                            
                            // Remove existing level indicator
                            const existingIndicator = cellElement.querySelector('.tower-level');
                            if (existingIndicator) {
                                existingIndicator.remove();
                            }
                            
                            cellElement.appendChild(levelIndicator);
                        }
                    }
                }
            }
        }
    }