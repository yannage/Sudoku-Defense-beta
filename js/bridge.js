// bridge.js - Add this file to connect UI and game modules
const GameBridge = (function() {
    function initUIHandlers() {
        // Set up tower selection
        const towerOptions = document.querySelectorAll('.tower-option');
        towerOptions.forEach(option => {
            option.addEventListener('click', function() {
                const towerType = this.dataset.towerType;
                // Remove selection from all options
                towerOptions.forEach(opt => opt.classList.remove('selected'));
                // Add selection to clicked option
                this.classList.add('selected');
                // Inform player module
                if (window.PlayerModule) {
                    PlayerModule.selectTower(towerType);
                }
            });
        });
        
        // Set up cell click handlers for tower placement
        const boardElement = document.getElementById('sudoku-board');
        if (boardElement) {
            boardElement.addEventListener('click', function(event) {
                const cell = event.target.closest('.sudoku-cell');
                if (cell) {
                    const row = parseInt(cell.dataset.row);
                    const col = parseInt(cell.dataset.col);
                    
                    // Get selected tower from PlayerModule
                    if (window.PlayerModule && window.TowerPlacement) {
                        const selectedTower = PlayerModule.getSelectedTower();
                        if (selectedTower) {
                            TowerPlacement.createTower(selectedTower, row, col);
                            // Update UI after tower placement
                            if (window.BoardRenderer) {
                                BoardRenderer.updateBoard();
                            }
                        }
                    }
                }
            });
        }
        
        // Set up game control buttons
        const startWaveButton = document.getElementById('start-wave');
        if (startWaveButton) {
            startWaveButton.addEventListener('click', function() {
                if (window.EnemyWaves) {
                    EnemyWaves.startWave();
                }
            });
        }
    }
    
    // Initialize when DOM is loaded
    document.addEventListener('DOMContentLoaded', function() {
        // Wait for modules to load
        setTimeout(initUIHandlers, 500);
    });
    
    return {
        initUIHandlers
    };
})();

window.GameBridge = GameBridge;