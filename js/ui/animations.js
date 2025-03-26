/**
 * animations.js - Handles visual effects and animations
 * This module manages projectile animations, tower attack effects,
 * and other visual feedback.
 */

const AnimationSystem = (function() {
    // Private variables
    let projectiles = [];
    let projectileId = 0;
    let lastFrameTime = 0;
    let boardElement = null;
    let cellSize = 0;
    
    /**
     * Initialize the animation system
     */
    function init() {
        projectiles = [];
        
        // Get the board element and its dimensions
        boardElement = document.getElementById('sudoku-board');
        if (boardElement) {
            cellSize = boardElement.clientWidth / 9;
        }
        
        // Create projectile container
        ensureProjectileContainer();
        
        // Set up event listeners
        setupEventListeners();
        
        console.log("AnimationSystem initialized with cellSize:", cellSize);
    }
    
    /**
     * Ensure the projectile container exists
     */
    function ensureProjectileContainer() {
        if (!boardElement) return;
        
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
     * Create a tower attack effect
     * @param {Object} tower - The attacking tower
     * @param {Object} enemy - The target enemy
     */
    function createTowerAttackEffect(tower, enemy) {
        // Add glow effect to the tower
        addTowerGlowEffect(tower);
        
        // Create projectile from tower to enemy
        createProjectile(tower, enemy);
    }
    
    /**
     * Add glow effect to a tower
     * @param {Object} tower - The tower to add effect to
     */
    function addTowerGlowEffect(tower) {
        // Find the tower element
        const towerElement = document.querySelector(`.sudoku-cell[data-row="${tower.row}"][data-col="${tower.col}"]`);
        
        if (!towerElement) return;
        
        // Add attacking class with glow effect
        towerElement.classList.add('tower-attacking');
        
        // Remove the class after animation completes
        setTimeout(() => {
            towerElement.classList.remove('tower-attacking');
        }, 300);
    }
    
    /**
     * Create a projectile from tower to enemy
     * @param {Object} tower - The source tower
     * @param {Object} enemy - The target enemy
     */
    function createProjectile(tower, enemy) {
        // Calculate positions
        const towerX = tower.col * cellSize + cellSize / 2;
        const towerY = tower.row * cellSize + cellSize / 2;
        
        // Create projectile
        const projectile = {
            id: `projectile_${++projectileId}`,
            startX: towerX,
            startY: towerY,
            targetX: enemy.x,
            targetY: enemy.y,
            progress: 0,
            speed: 0.005, // Speed of projectile animation
            target: enemy.id
        };
        
        // Add to projectiles array
        projectiles.push(projectile);
        
        // Create visual element
        const projectileElement = document.createElement('div');
        projectileElement.id = projectile.id;
        projectileElement.className = 'tower-projectile';
        projectileElement.textContent = '⚫';
        projectileElement.style.position = 'absolute';
        projectileElement.style.transform = `translate(${projectile.startX}px, ${projectile.startY}px)`;
        projectileElement.style.fontSize = '10px';
        projectileElement.style.zIndex = '25';
        
        // Add to projectile container
        const container = document.getElementById('projectile-container');
        if (container) {
            container.appendChild(projectileElement);
        }
    }
    
    /**
     * Create an enemy damaged effect
     * @param {Object} enemy - The damaged enemy
     */
    function createEnemyDamagedEffect(enemy) {
        // Find the enemy element
        const enemyElement = document.getElementById(enemy.id);
        if (!enemyElement) return;
        
        // Add damaged class
        enemyElement.classList.add('enemy-damaged');
        
        // Remove class after animation completes
        setTimeout(() => {
            enemyElement.classList.remove('enemy-damaged');
        }, 300);
    }
    
    /**
     * Animation loop for projectiles
     * @param {number} timestamp - Current animation frame timestamp
     */
    function animationLoop(timestamp) {
        // Calculate delta time
        const deltaTime = timestamp - (lastFrameTime || timestamp);
        lastFrameTime = timestamp;
        
        // Update projectiles
        updateProjectiles(deltaTime);
        
        // Continue animation loop
        requestAnimationFrame(animationLoop);
    }
    
    /**
     * Update all projectiles
     * @param {number} deltaTime - Time elapsed since last update
     */
    function updateProjectiles(deltaTime) {
        // Get the container
        const container = document.getElementById('projectile-container');
        if (!container) return;
        
        // Process each projectile
        for (let i = projectiles.length - 1; i >= 0; i--) {
            const projectile = projectiles[i];
            
            // Update progress
            projectile.progress += projectile.speed * deltaTime;
            
            if (projectile.progress >= 1) {
                // Projectile reached target
                removeProjectile(projectile.id);
                projectiles.splice(i, 1);
                continue;
            }
            
            // Update position
            const x = projectile.startX + (projectile.targetX - projectile.startX) * projectile.progress;
            const y = projectile.startY + (projectile.targetY - projectile.startY) * projectile.progress;
            
            // Update visual element
            const element = document.getElementById(projectile.id);
            if (element) {
                element.style.transform = `translate(${x}px, ${y}px)`;
            }
        }
    }
    
    /**
     * Remove a projectile element
     * @param {string} id - Projectile ID to remove
     */
    function removeProjectile(id) {
        const element = document.getElementById(id);
        if (element) {
            element.remove();
        }
    }
    
    /**
     * Clear all projectiles
     */
    function clearAllProjectiles() {
        const container = document.getElementById('projectile-container');
        if (container) {
            container.innerHTML = '';
        }
        projectiles = [];
    }
    
    /**
     * Update the cell size
     * Called when the window is resized
     */
    function updateCellSize() {
        if (!boardElement) {
            boardElement = document.getElementById('sudoku-board');
        }
        
        if (boardElement) {
            cellSize = boardElement.clientWidth / 9;
        }
    }
    
    /**
     * Set up event listeners
     */
    function setupEventListeners() {
        // Listen for tower attack events
        EventSystem.subscribe(GameEvents.TOWER_ATTACK, function(data) {
            if (data && data.tower && data.enemy) {
                createTowerAttackEffect(data.tower, data.enemy);
            }
        });
        
        // Listen for enemy damage events
        EventSystem.subscribe(GameEvents.ENEMY_DAMAGE, function(data) {
            if (data && data.enemy) {
                createEnemyDamagedEffect(data.enemy);
            }
        });
        
        // Listen for enemy defeated events to remove projectiles targeting that enemy
        EventSystem.subscribe(GameEvents.ENEMY_DEFEATED, function(data) {
            if (data && data.enemy) {
                // Remove projectiles targeting this enemy
                for (let i = projectiles.length - 1; i >= 0; i--) {
                    if (projectiles[i].target === data.enemy.id) {
                        removeProjectile(projectiles[i].id);
                        projectiles.splice(i, 1);
                    }
                }
            }
        });
        
        // Listen for wave completion to clear all projectiles
        EventSystem.subscribe(GameEvents.WAVE_COMPLETE, clearAllProjectiles);
        
        // Listen for game pause to pause animations
        EventSystem.subscribe(GameEvents.GAME_PAUSE, clearAllProjectiles);
        
        // Listen for window resize
        window.addEventListener('resize', updateCellSize);
    }
    
    // Initialize
    document.addEventListener('DOMContentLoaded', function() {
        init();
        // Start animation loop
        requestAnimationFrame(animationLoop);
    });
    
    // Add CSS styles for animations
    function addAnimationStyles() {
        const style = document.createElement('style');
        style.textContent = `
            /* Tower attack effect (glow) */
            .tower-attacking {
                animation: tower-attack-pulse 0.3s ease-in-out;
                filter: drop-shadow(0 0 5px #ffff00) drop-shadow(0 0 10px #ff9900);
                z-index: 15;
            }
            
            @keyframes tower-attack-pulse {
                0% { transform: scale(1); }
                50% { transform: scale(1.2); }
                100% { transform: scale(1); }
            }
            
            /* Projectile styling */
            .tower-projectile {
                color: #000;
                filter: drop-shadow(0 0 2px #fff);
                pointer-events: none;
                transform-origin: center center;
            }
            
            /* Enemy damaged effect */
            .enemy-damaged {
                animation: enemy-damaged-flash 0.3s ease-in-out;
                filter: brightness(2);
            }
            
            @keyframes enemy-damaged-flash {
                0% { transform: scale(1); filter: brightness(1); }
                50% { transform: scale(1.3); filter: brightness(2); }
                100% { transform: scale(1); filter: brightness(1); }
            }
        `;
        
        document.head.appendChild(style);
    }
    
    // Add animation styles
    addAnimationStyles();
    
    // Public API
    return {
        init,
        createTowerAttackEffect,
        createEnemyDamagedEffect,
        clearAllProjectiles,
        updateCellSize
    };
})();

// Make module available globally
window.AnimationSystem = AnimationSystem;