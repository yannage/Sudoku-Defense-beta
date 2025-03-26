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
        
        // Create containers for enemies and projectiles
        createEnemyContainer();
        createProjectileContainer();
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
    
    /**
     * Handle a cell click
     * @param {number} row - Row index of clicked cell
     * @param {number} col - Column index of clicked cell
     */
    function handleCellClick(row, col) {
        console.log(`Cell clicked: (${row}, ${col})`);
        
        // Check if a tower type is selected
        if (window.TowerSelector && TowerSelector.getSelectedTowerType()) {
            const towerType = TowerSelector.getSelectedTowerType();
            
            // Attempt to place tower
            if (window.TowersModule) {
                const tower = TowersModule.createTower(towerType, row, col);
                
                if (tower) {
                    // Tower placed successfully, update board
                    updateBoard();
                }
            }
        } else {
            // No tower selected, show message
            EventSystem.publish(GameEvents.STATUS_MESSAGE, "Select a tower type first!");
        }
    }
    
    /**
     * Create container for enemies
     */
    function createEnemyContainer() {
        // Check if container already exists
        let enemyContainer = document.getElementById('enemy-container');
        
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
            
            boardElement.appendChild(enemyContainer);
        }
    }
    
    /**
     * Create container for projectiles
     */
    function createProjectileContainer() {
        // Check if container already exists
        let projectileContainer = document.getElementById('projectile-container');
        
        if (!projectileContainer) {
            projectileContainer = document.createElement('div');
            projectileContainer.id = 'projectile-container';
            projectileContainer.style.position = 'absolute';
            projectileContainer.style.top = '0';
            projectileContainer.style.left = '0';
            projectileContainer.style.width = '100%';
            projectileContainer.style.height = '100%';
            projectileContainer.style.pointerEvents = 'none';
            projectileContainer.style.zIndex = '20';
            
            boardElement.appendChild(projectileContainer);
        }
    }
    
    /**
     * Render enemies on the board
     */
    function renderEnemies() {
        if (!window.EnemiesModule) return;
        
        // Get the enemies container
        let enemyContainer = document.getElementById('enemy-container');
        
        // Create container if it doesn't exist
        if (!enemyContainer) {
            createEnemyContainer();
            enemyContainer = document.getElementById('enemy-container');
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
    }
    
    /**
     * Highlight cells for the given number
     * @param {number} number - Number to highlight
     */
    function highlightNumber(number) {
        // Remove existing highlights
        document.querySelectorAll('.sudoku-cell.number-highlighted').forEach(cell => {
            cell.classList.remove('number-highlighted');
        });
        
        if (number < 1 || number > 9) return;
        
        // Highlight cells with the given number
        document.querySelectorAll(`.sudoku-cell`).forEach(cell => {
            if (cell.textContent === String(number)) {
                cell.classList.add('number-highlighted');
            }
        });
    }
    
    /**
     * Mark a tower as incorrect
     * @param {number} row - Row index
     * @param {number} col - Column index
     */
    function markIncorrectTower(row, col) {
        const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
        
        if (cell) {
            cell.classList.add('incorrect-tower');
            
            // Add warning indicator
            if (!cell.querySelector('.incorrect-marker')) {
                const marker = document.createElement('div');
                marker.className = 'incorrect-marker';
                marker.textContent = '❌';
                marker.style.opacity = '0.3';
                cell.appendChild(marker);
            }
        }
    }
    
    /**
     * Clear incorrect tower marking
     * @param {number} row - Row index
     * @param {number} col - Column index
     */
    function clearIncorrectTower(row, col) {
        const cell = document.querySelector(`.sudoku-cell[data-row="${row}"][data-col="${col}"]`);
        
        if (cell) {
            cell.classList.remove('incorrect-tower');
            
            // Remove warning indicator
            const marker = cell.querySelector('.incorrect-marker');
            if (marker) {
                marker.remove();
            }
        }
    }
    
    /**
     * Set up event listeners
     */
    function setupEventListeners() {
        // Listen for Sudoku generation to update the board
        EventSystem.subscribe(GameEvents.SUDOKU_GENERATED, function() {
            updateBoard();
        });
        
        // Listen for tower placement to update the board
        EventSystem.subscribe(GameEvents.TOWER_PLACED, function() {
            updateBoard();
        });
        
        // Listen for tower removal to update the board
        EventSystem.subscribe(GameEvents.TOWER_REMOVED, function() {
            updateBoard();
        });
        
        // Listen for tower upgrade to update level indicator
        EventSystem.subscribe(GameEvents.TOWER_UPGRADE, function() {
            updateBoard();
        });
        
        // Listen for number highlighting
        EventSystem.subscribe('number:highlight', function(number) {
            highlightNumber(number);
        });
        
        // Listen for invalid cell marking
        EventSystem.subscribe(GameEvents.SUDOKU_CELL_INVALID, function(data) {
            markIncorrectTower(data.row, data.col);
        });
        
        // Listen for window resize to update cell size
        window.addEventListener('resize', function() {
            if (boardElement) {
                cellSize = boardElement.clientWidth / 9;
            }
        });
        
        // Set up game control buttons
        setupControlButtons();
    }
    
    /**
     * Set up event listeners for control buttons
     */
    function setupControlButtons() {
        // Start wave button
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
        
        // Pause game button
        const pauseButton = document.getElementById('pause-game');
        if (pauseButton) {
            pauseButton.addEventListener('click', function() {
                if (window.GameLoop) {
                    if (GameLoop.isPaused()) {
                        GameLoop.resume();
                        pauseButton.textContent = 'Pause';
                    } else {
                        GameLoop.pause();
                        pauseButton.textContent = 'Resume';
                    }
                }
            });
        }
        
        // Stats button
        const statsButton = document.getElementById('stats-button');
        if (statsButton) {
            statsButton.addEventListener('click', function() {
                // Publish event for showing stats modal
                EventSystem.publish('stats:show');
            });
        }
        
        // New game button
        const newGameButton = document.getElementById('new-game');
        if (newGameButton) {
            newGameButton.addEventListener('click', function() {
                if (window.GameLoop && typeof GameLoop.reset === 'function') {
                    GameLoop.reset();
                }
            });
        }
    }
    
    // Public API
    return {
        init,
        setupBoard,
        clearBoard,
        updateBoard,
        handleCellClick,
        renderEnemies,
        highlightNumber,
        markIncorrectTower,
        clearIncorrectTower,
        setupEventListeners
    };
})();

// Make module available globally
window.BoardRenderer = BoardRenderer;