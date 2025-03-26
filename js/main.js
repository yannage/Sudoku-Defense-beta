/**
 * main.js - Main entry point for the Sudoku Tower Defense game
 * This file handles the game initialization and module loading.
 */

const SudokuTowerDefense = (function() {
    // Enable debug mode
    const DEBUG = true;
    
    // Required modules with their loading status
    const modules = {
        // Core Modules
        'core/events.js': false,
        'core/game-loop.js': false,
        'core/save-system.js': false,
        
        // Sudoku Modules
        'sudoku/board.js': false,
        'sudoku/generator.js': false,
        'sudoku/validator.js': false,
        'sudoku/completion.js': false,
        
        // Tower Modules
        'towers/types.js': false,
        'towers/placement.js': false,
        'towers/attacks.js': false,
        'towers/upgrades.js': false,
        
        // Enemy Modules
        'enemies/types.js': false,
        'enemies/movement.js': false,
        'enemies/waves.js': false,
        
        // Bonus Modules
        'bonuses/completion-bonuses.js': false,
        'bonuses/wave-bonuses.js': false,
        
        // UI Modules
        'ui/board-renderer.js': false,
        'ui/tower-selector.js': false,
        'ui/animations.js': false,
        'ui/modals.js': false,
        
        // Player Module
        'player.js': false
    };
    
    // Dependencies between modules
    const dependencies = {
        'core/game-loop.js': ['core/events.js'],
        'core/save-system.js': ['core/events.js'],
        
        'sudoku/board.js': ['core/events.js', 'sudoku/generator.js'],
        'sudoku/completion.js': ['sudoku/board.js', 'sudoku/validator.js'],
        
        'player.js': ['core/events.js'],
        
        'towers/placement.js': ['towers/types.js', 'sudoku/board.js', 'player.js'],
        'towers/attacks.js': ['towers/types.js', 'enemies/types.js'],
        'towers/upgrades.js': ['towers/types.js', 'towers/placement.js', 'player.js'],
        
        'enemies/movement.js': ['enemies/types.js', 'sudoku/board.js'],
        'enemies/waves.js': ['enemies/types.js', 'enemies/movement.js', 'player.js'],
        
        'bonuses/completion-bonuses.js': ['core/events.js', 'sudoku/completion.js'],
        'bonuses/wave-bonuses.js': ['core/events.js', 'enemies/waves.js', 'player.js'],
        
        'ui/board-renderer.js': ['core/events.js', 'sudoku/board.js'],
        'ui/tower-selector.js': ['core/events.js', 'towers/types.js', 'player.js'],
        'ui/animations.js': ['towers/attacks.js', 'enemies/movement.js'],
        'ui/modals.js': ['core/events.js']
    };
    
    // Debug log function
    function debugLog(message) {
        if (DEBUG) {
            console.log(`[DEBUG] ${message}`);
        }
    }
    
    /**
     * Initialize the game
     */
    function init() {
        debugLog("Initializing Sudoku Tower Defense...");
        
        // Load modules in order
        loadModules();
        
        // Start the game once all modules are loaded
        checkAllModulesLoaded();
    }
    
    /**
     * Load all required modules
     */
    function loadModules() {
        // First load core modules and modules without dependencies
        for (const modulePath in modules) {
            if (!dependencies[modulePath] || dependencies[modulePath].length === 0) {
                loadModule(modulePath);
            }
        }
    }
    
    /**
     * Load a single module
     * @param {string} modulePath - Path to the module
     */
    function loadModule(modulePath) {
        // Check if module is already loaded
        if (modules[modulePath]) {
            return;
        }
        
        // Check dependencies
        if (dependencies[modulePath]) {
            const deps = dependencies[modulePath];
            for (const dep of deps) {
                if (!modules[dep]) {
                    // Dependency not loaded yet, load it first
                    loadModule(dep);
                }
            }
        }
        
        debugLog(`Loading module: ${modulePath}`);
        
        // Create script element
        const script = document.createElement('script');
        script.src = `js/${modulePath}`;
        script.async = false;
        
        // Set up load handler
        script.onload = function() {
            modules[modulePath] = true;
            debugLog(`Module loaded: ${modulePath}`);
            checkAllModulesLoaded();
            
            // Load dependent modules
            for (const modPath in dependencies) {
                if (dependencies[modPath].includes(modulePath) && !modules[modPath]) {
                    // Check if all dependencies of this module are loaded
                    const allDepsLoaded = dependencies[modPath].every(dep => modules[dep]);
                    if (allDepsLoaded) {
                        loadModule(modPath);
                    }
                }
            }
        };
        
        // Set up error handler
        script.onerror = function() {
            debugLog(`Failed to load module: ${modulePath}`);
        };
        
        // Add to document
        document.head.appendChild(script);
    }
    
    /**
     * Check if all modules are loaded, and start the game if they are
     */
    function checkAllModulesLoaded() {
        const allLoaded = Object.values(modules).every(loaded => loaded);
        
        if (allLoaded) {
            startGame();
        }
    }
    
    /**
     * Start the game
     */
    function startGame() {
        debugLog("All modules loaded, starting game...");
        
        // Initialize UI first
        if (window.BoardRenderer) {
            BoardRenderer.init();
        }
        
        if (window.TowerSelector) {
            TowerSelector.init();
        }
        
        // Initialize player module
        if (window.PlayerModule) {
            PlayerModule.init();
        }
        
        // Initialize game systems
        if (window.GameLoop) {
            GameLoop.init();
        }
        
        debugLog("Game started successfully");
    }
    
    // Public API
    return {
        init,
        debug: {
            getModuleStatus: function() { return {...modules}; },
            getDependencies: function() { return {...dependencies}; }
        }
    };
})();

// Initialize the game on DOM content loaded
document.addEventListener('DOMContentLoaded', function() {
    SudokuTowerDefense.init();
});