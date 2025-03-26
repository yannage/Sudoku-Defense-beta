/**
 * tower-selector.js - Handles tower selection UI
 * This module manages the tower selection panel and user interaction
 * with tower options.
 */

const TowerSelector = (function() {
    // Private variables
    let towerOptions = [];
    let selectedTowerType = null;
    
    /**
     * Initialize the tower selector
     */
    function init() {
        // Get all tower options from the DOM
        towerOptions = document.querySelectorAll('.tower-option');
        
        if (towerOptions.length === 0) {
            console.error("No tower options found in the DOM");
            return;
        }
        
        // Set up event listeners for tower options
        setupTowerOptionListeners();
        
        console.log("TowerSelector initialized with", towerOptions.length, "options");
    }
    
    /**
     * Set up event listeners for tower options
     */
    function setupTowerOptionListeners() {
        towerOptions.forEach(option => {
            // Remove any existing listeners by cloning and replacing
            const newOption = option.cloneNode(true);
            option.parentNode.replaceChild(newOption, option);
            
            // Add click event listener
            newOption.addEventListener('click', function() {
                selectTowerOption(this);
            });
        });
    }
    
    /**
     * Handle tower option selection
     * @param {HTMLElement} optionElement - The clicked tower option element
     */
    function selectTowerOption(optionElement) {
        // Get tower type from data attribute
        const towerType = optionElement.dataset.towerType;
        
        // Remove selected class from all options
        towerOptions.forEach(opt => {
            opt.classList.remove('selected');
        });
        
        // Add selected class to clicked option
        optionElement.classList.add('selected');
        
        // Update selected tower
        selectedTowerType = towerType;
        
        // Get tower cost from TowersModule
        let cost = 0;
        if (window.TowersModule && typeof TowersModule.getTowerCost === 'function') {
            cost = TowersModule.getTowerCost(towerType);
        }
        
        // Update Player module's selected tower
        if (window.PlayerModule) {
            PlayerModule.selectTower(towerType);
        }
        
        // Display selection message
        const towerName = towerType === 'special' ? 'Special' : towerType;
        EventSystem.publish(GameEvents.STATUS_MESSAGE, 
            `Selected ${towerName} Tower. Cost: ${cost}`);
    }
    
    /**
     * Get the currently selected tower type
     * @returns {string|null} The selected tower type or null if none
     */
    function getSelectedTowerType() {
        return selectedTowerType;
    }
    
    /**
     * Select a tower type programmatically
     * @param {string} towerType - The tower type to select
     */
    function selectTower(towerType) {
        // Find the option with matching tower type
        const option = Array.from(towerOptions).find(
            opt => opt.dataset.towerType === towerType
        );
        
        if (option) {
            selectTowerOption(option);
        }
    }
    
    /**
     * Update tower options to show which ones are affordable
     * @param {number} currency - Current currency
     */
    function updateAffordableTowers(currency) {
        if (!window.TowersModule) return;
        
        towerOptions.forEach(option => {
            const towerType = option.dataset.towerType;
            const cost = TowersModule.getTowerCost(towerType);
            
            // Add or remove "affordable" class
            if (currency >= cost) {
                option.classList.add('affordable');
                option.classList.remove('unaffordable');
            } else {
                option.classList.remove('affordable');
                option.classList.add('unaffordable');
            }
        });
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for currency changes to update affordable towers
        EventSystem.subscribe(GameEvents.CURRENCY_CHANGE, updateAffordableTowers);
    }
    
    // Initialize on DOM content loaded
    document.addEventListener('DOMContentLoaded', function() {
        init();
        initEventListeners();
    });
    
    // Public API
    return {
        init,
        getSelectedTowerType,
        selectTower,
        updateAffordableTowers
    };
})();

// Make module available globally
window.TowerSelector = TowerSelector;