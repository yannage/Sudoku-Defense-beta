/**
 * movement.js - Handles enemy movement along paths
 * This module manages enemy position updates and path following.
 */

const EnemyMovement = (function() {
    // Private variables
    let cellSize = 0;
    let path = [];
    
    /**
     * Initialize the enemy movement module
     * @param {Object} options - Initialization options
     */
    function init(options = {}) {
        cellSize = options.cellSize || 55; // Default cell size
        
        // Get the initial path
        if (window.SudokuBoard && typeof SudokuBoard.getPathArray === 'function') {
            path = SudokuBoard.getPathArray();
        }
    }
    
    /**
     * Move an enemy along the path
     * @param {Object} enemy - The enemy to move
     * @param {number} deltaTime - Time elapsed since last update
     * @returns {boolean} Whether the enemy reached the end of the path
     */
    function moveEnemy(enemy, deltaTime) {
        if (!enemy || !enemy.active) {
            return false;
        }
        
        if (enemy.pathIndex >= path.length - 1) {
            // Enemy reached the end of the path
            return true;
        }
        
        // Calculate movement speed based on enemy speed and deltaTime
        const moveSpeed = enemy.speed * 50 * deltaTime;
        
        // Get current path segment
        const currentCell = path[enemy.pathIndex];
        const nextCell = path[enemy.pathIndex + 1];
        
        // Calculate cell centers
        const currentX = currentCell[1] * cellSize + cellSize / 2;
        const currentY = currentCell[0] * cellSize + cellSize / 2;
        const nextX = nextCell[1] * cellSize + cellSize / 2;
        const nextY = nextCell[0] * cellSize + cellSize / 2;
        
        // Update progress along current path segment
        enemy.progress += moveSpeed / Math.sqrt(
            Math.pow(nextX - currentX, 2) + Math.pow(nextY - currentY, 2)
        );
        
        // Move to next path segment if progress is complete
        if (enemy.progress >= 1) {
            enemy.pathIndex++;
            enemy.progress = 0;
            
            // Check if enemy reached the end
            if (enemy.pathIndex >= path.length - 1) {
                return true;
            }
        }
        
        // Interpolate position between current and next cells
        const currentSegment = path[enemy.pathIndex];
        const nextSegment = path[enemy.pathIndex + 1];
        
        const startX = currentSegment[1] * cellSize + cellSize / 2;
        const startY = currentSegment[0] * cellSize + cellSize / 2;
        const endX = nextSegment[1] * cellSize + cellSize / 2;
        const endY = nextSegment[0] * cellSize + cellSize / 2;
        
        enemy.x = startX + (endX - startX) * enemy.progress;
        enemy.y = startY + (endY - startY) * enemy.progress;
        
        return false;
    }
    
    /**
     * Calculate the initial position for a new enemy
     * @returns {Object} The starting position {x, y, pathIndex, progress}
     */
    function getStartingPosition() {
        if (path.length === 0) {
            console.error("Path is empty, cannot get starting position");
            return { x: 0, y: 0, pathIndex: 0, progress: 0 };
        }
        
        const startCell = path[0];
        const x = startCell[1] * cellSize + cellSize / 2;
        const y = startCell[0] * cellSize + cellSize / 2;
        
        return {
            x: x,
            y: y,
            pathIndex: 0,
            progress: 0
        };
    }
    
    /**
     * Set the current path
     * @param {number[][]} newPath - New path as array of [row, col] coordinates
     */
    function setPath(newPath) {
        if (Array.isArray(newPath) && newPath.length > 0) {
            path = [...newPath];
        }
    }
    
    /**
     * Get the current path
     * @returns {number[][]} The current path
     */
    function getPath() {
        return [...path];
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
        // Listen for path updates
        EventSystem.subscribe('path:updated', function(newPath) {
            setPath(newPath);
        });
        
        // Listen for game initialization
        EventSystem.subscribe(GameEvents.GAME_INIT, function(options) {
            init(options);
        });
        
        // Listen for Sudoku board generation to get the path
        EventSystem.subscribe(GameEvents.SUDOKU_GENERATED, function(data) {
            if (data.pathCells) {
                setPath(data.pathCells);
            }
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        init,
        moveEnemy,
        getStartingPosition,
        setPath,
        getPath,
        setCellSize
    };
})();

// Make module available globally
window.EnemyMovement = EnemyMovement;