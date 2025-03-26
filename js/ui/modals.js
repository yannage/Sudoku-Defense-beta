/**
 * modals.js - Handles game modals and dialogs
 * This module manages modal dialogs for game events like level completion,
 * game over, and tower upgrade confirmations.
 */

const ModalSystem = (function() {
    /**
     * Show a game over modal
     * @param {Object} data - Game over data including score
     */
    function showGameOverModal(data) {
        // Create or get the modal
        let modal = document.getElementById('game-over-modal');
        if (!modal) {
            modal = createModal('game-over-modal');
        }
        
        // Set content
        const content = modal.querySelector('.modal-content');
        content.innerHTML = `
            <h2>Game Over!</h2>
            <p>Final Score: <span class="score-value">${data.score}</span></p>
            ${data.highScore ? `<p>High Score: <span class="high-score-value">${data.highScore}</span></p>` : ''}
            <button id="new-game-button">New Game</button>
        `;
        
        // Add event listeners
        const newGameButton = content.querySelector('#new-game-button');
        if (newGameButton) {
            newGameButton.addEventListener('click', function() {
                hideModal(modal);
                if (window.GameLoop) {
                    GameLoop.reset();
                }
            });
        }
        
        // Show the modal
        showModal(modal);
    }
    
    /**
     * Show a level complete modal
     * @param {Object} data - Level data including level number and score
     */
    function showLevelCompleteModal(data) {
        // Create or get the modal
        let modal = document.getElementById('level-complete-modal');
        if (!modal) {
            modal = createModal('level-complete-modal');
        }
        
        // Set content
        const content = modal.querySelector('.modal-content');
        content.innerHTML = `
            <h2 id="level-complete-title">Level ${data.level} Complete!</h2>
            <p id="level-complete-score">Current Score: ${data.score}</p>
            <button id="continue-button">Continue</button>
        `;
        
        // Add event listeners
        const continueButton = content.querySelector('#continue-button');
        if (continueButton) {
            continueButton.addEventListener('click', function() {
                hideModal(modal);
                if (window.GameLoop) {
                    GameLoop.resume();
                }
            });
        }
        
        // Show the modal
        showModal(modal);
    }
    
    /**
     * Show a tower upgrade modal
     * @param {Object} data - Tower upgrade info
     */
    function showTowerUpgradeModal(data) {
        // Create or get the modal
        let modal = document.getElementById('tower-upgrade-modal');
        if (!modal) {
            modal = createModal('tower-upgrade-modal');
        }
        
        // Set content
        const content = modal.querySelector('.modal-content');
        content.innerHTML = `
            <h2>Upgrade Tower</h2>
            <div class="upgrade-stats">
                <div class="stat-row">
                    <div class="stat-label">Level</div>
                    <div class="stat-current">${data.currentLevel}</div>
                    <div class="stat-arrow">→</div>
                    <div class="stat-new">${data.newLevel}</div>
                </div>
                <div class="stat-row">
                    <div class="stat-label">Damage</div>
                    <div class="stat-current">${data.currentDamage}</div>
                    <div class="stat-arrow">→</div>
                    <div class="stat-new">${data.newDamage}</div>
                </div>
                <div class="stat-row">
                    <div class="stat-label">Range</div>
                    <div class="stat-current">${data.currentRange}</div>
                    <div class="stat-arrow">→</div>
                    <div class="stat-new">${data.newRange}</div>
                </div>
                <div class="stat-row">
                    <div class="stat-label">Attack Speed</div>
                    <div class="stat-current">${data.currentAttackSpeed}/s</div>
                    <div class="stat-arrow">→</div>
                    <div class="stat-new">${data.newAttackSpeed}/s</div>
                </div>
            </div>
            <p class="upgrade-cost">Cost: <span class="currency-value">${data.cost}</span></p>
            <div class="upgrade-buttons">
                <button id="confirm-upgrade" ${!data.canAfford ? 'disabled' : ''}>${data.canAfford ? 'Upgrade' : 'Not Enough Currency'}</button>
                <button id="cancel-upgrade">Cancel</button>
            </div>
        `;
        
        // Add event listeners
        const confirmButton = content.querySelector('#confirm-upgrade');
        if (confirmButton) {
            confirmButton.addEventListener('click', function() {
                hideModal(modal);
                EventSystem.publish('tower:upgrade:confirm', data.towerId);
            });
        }
        
        const cancelButton = content.querySelector('#cancel-upgrade');
        if (cancelButton) {
            cancelButton.addEventListener('click', function() {
                hideModal(modal);
            });
        }
        
        // Show the modal
        showModal(modal);
    }
    
    /**
     * Create a modal element
     * @param {string} id - Modal ID
     * @returns {HTMLElement} The created modal
     */
    function createModal(id) {
        const modal = document.createElement('div');
        modal.id = id;
        modal.className = 'modal';
        
        const modalContent = document.createElement('div');
        modalContent.className = 'modal-content';
        
        modal.appendChild(modalContent);
        document.body.appendChild(modal);
        
        return modal;
    }
    
    /**
     * Show a modal
     * @param {HTMLElement} modal - Modal element to show
     */
    function showModal(modal) {
        // Pause the game if it's running
        if (window.GameLoop && typeof GameLoop.pause === 'function') {
            GameLoop.pause();
        }
        
        // Add active class to show the modal with animation
        modal.classList.add('active');
    }
    
    /**
     * Hide a modal
     * @param {HTMLElement} modal - Modal element to hide
     */
    function hideModal(modal) {
        modal.classList.remove('active');
    }
    
    /**
     * Add modal styles to the document
     */
    function addModalStyles() {
        const style = document.createElement('style');
        style.textContent = `
            /* Modal base styles */
            .modal {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(0, 0, 0, 0.7);
                display: flex;
                justify-content: center;
                align-items: center;
                z-index: 100;
                opacity: 0;
                pointer-events: none;
                transition: opacity 0.3s;
            }
            
            .modal.active {
                opacity: 1;
                pointer-events: all;
            }
            
            .modal-content {
                background-color: white;
                padding: 30px;
                border-radius: 8px;
                text-align: center;
                max-width: 80%;
                transform: translateY(-20px);
                transition: transform 0.3s;
            }
            
            .modal.active .modal-content {
                transform: translateY(0);
            }
            
            /* Game over specific styles */
            #game-over-modal h2 {
                color: #ff6b6b;
                margin-bottom: 15px;
            }
            
            .score-value, .high-score-value {
                font-weight: bold;
                color: #4CAF50;
            }
            
            /* Level complete specific styles */
            #level-complete-modal h2 {
                color: #4CAF50;
                margin-bottom: 15px;
            }
            
            /* Tower upgrade specific styles */
            .upgrade-stats {
                margin: 20px 0;
                border: 1px solid #eee;
                padding: 10px;
                border-radius: 5px;
            }
            
            .stat-row {
                display: flex;
                justify-content: space-between;
                margin-bottom: 8px;
            }
            
            .stat-label {
                text-align: left;
                font-weight: bold;
                flex: 2;
            }
            
            .stat-current, .stat-new {
                flex: 1;
            }
            
            .stat-arrow {
                flex: 0.5;
                color: #888;
            }
            
            .stat-new {
                color: #4CAF50;
                font-weight: bold;
            }
            
            .upgrade-cost {
                margin: 15px 0;
                font-size: 1.1em;
            }
            
            .currency-value {
                font-weight: bold;
                color: #ff9800;
            }
            
            .upgrade-buttons {
                display: flex;
                justify-content: center;
                gap: 10px;
            }
            
            #confirm-upgrade:disabled {
                background-color: #ccc;
                cursor: not-allowed;
            }
            
            button {
                padding: 10px 16px;
                background-color: #4CAF50;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 1rem;
                font-weight: bold;
                transition: background-color 0.2s, transform 0.1s;
            }
            
            button:hover:not(:disabled) {
                background-color: #3e8e41;
                transform: translateY(-2px);
            }
            
            #cancel-upgrade {
                background-color: #f44336;
            }
            
            #cancel-upgrade:hover {
                background-color: #d32f2f;
            }
        `;
        
        document.head.appendChild(style);
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for game over event
        EventSystem.subscribe(GameEvents.GAME_OVER, showGameOverModal);
        
        // Listen for Sudoku completion event
        EventSystem.subscribe(GameEvents.SUDOKU_COMPLETE, function(data) {
            // Wait a bit before showing the level complete modal
            setTimeout(() => {
                const level = window.LevelsModule ? LevelsModule.getCurrentLevel() : 1;
                const score = window.PlayerModule ? PlayerModule.getState().score : 0;
                
                showLevelCompleteModal({
                    level: level,
                    score: score
                });
            }, 500);
        });
        
        // Listen for tower upgrade show event
        EventSystem.subscribe('tower:upgrade:show', showTowerUpgradeModal);
    }
    
    // Initialize
    function init() {
        addModalStyles();
        initEventListeners();
    }
    
    // Initialize on DOM content loaded
    document.addEventListener('DOMContentLoaded', init);
    
    // Public API
    return {
        showGameOverModal,
        showLevelCompleteModal,
        showTowerUpgradeModal,
        showModal,
        hideModal
    };
})();

// Make module available globally
window.ModalSystem = ModalSystem;