/**
 * upgrades.js - Handles tower upgrade functionality
 * This module manages the upgrading of towers including cost calculation,
 * stat improvements, and upgrade UI.
 */

const TowerUpgrades = (function() {
    /**
     * Upgrade a tower
     * @param {string} towerId - ID of the tower to upgrade
     * @returns {boolean} Whether the tower was upgraded
     */
    function upgradeTower(towerId) {
        if (!window.TowerPlacement || !window.TowerTypes || !window.PlayerModule) {
            console.error("Required modules not found");
            return false;
        }
        
        const tower = TowerPlacement.getTowerById(towerId);
        
        if (!tower) {
            console.error("Tower not found:", towerId);
            return false;
        }
        
        // Calculate upgrade cost
        const upgradeCost = TowerTypes.getUpgradeCost(tower.type, tower.level);
        
        // Check if player has enough currency
        if (!PlayerModule.spendCurrency(upgradeCost)) {
            EventSystem.publish(GameEvents.STATUS_MESSAGE, 
                `Not enough currency to upgrade this tower! Need ${upgradeCost}`);
            return false;
        }
        
        // Get upgraded stats
        const upgradedStats = TowerTypes.getUpgradedStats(tower);
        
        // Apply upgrade effects
        tower.level++;
        tower.damage = upgradedStats.damage;
        tower.range = upgradedStats.range;
        tower.attackSpeed = upgradedStats.attackSpeed;
        
        // Publish tower upgrade event
        EventSystem.publish(GameEvents.TOWER_UPGRADE, tower);
        
        // Show upgrade message
        EventSystem.publish(GameEvents.STATUS_MESSAGE, 
            `Tower upgraded to level ${tower.level}! Damage: ${tower.damage}, Range: ${Math.floor(tower.range / 50)}, Attack Speed: ${(1 / tower.attackSpeed).toFixed(1)}/s`);
        
        return true;
    }
    
    /**
     * Show upgrade UI for a tower
     * @param {string} towerId - ID of the tower to show upgrade UI for
     */
    function showUpgradeUI(towerId) {
        if (!window.TowerPlacement || !window.TowerTypes) {
            return;
        }
        
        const tower = TowerPlacement.getTowerById(towerId);
        
        if (!tower) {
            return;
        }
        
        // Calculate upgrade cost
        const upgradeCost = TowerTypes.getUpgradeCost(tower.type, tower.level);
        
        // Get current player currency
        const playerCurrency = PlayerModule.getState().currency;
        
        // Get upgraded stats
        const upgradedStats = TowerTypes.getUpgradedStats(tower);
        
        // Create upgrade info message
        const upgradeInfo = {
            towerId: tower.id,
            currentLevel: tower.level,
            newLevel: tower.level + 1,
            currentDamage: tower.damage,
            newDamage: upgradedStats.damage,
            currentRange: Math.floor(tower.range / 50),
            newRange: Math.floor(upgradedStats.range / 50),
            currentAttackSpeed: (1 / tower.attackSpeed).toFixed(1),
            newAttackSpeed: (1 / upgradedStats.attackSpeed).toFixed(1),
            cost: upgradeCost,
            canAfford: playerCurrency >= upgradeCost
        };
        
        // Publish event to show upgrade UI
        EventSystem.publish("tower:upgrade:show", upgradeInfo);
    }
    
    /**
     * Get upgrade cost for a tower
     * @param {string} towerId - ID of the tower
     * @returns {number} Cost to upgrade or 0 if tower not found
     */
    function getUpgradeCost(towerId) {
        if (!window.TowerPlacement || !window.TowerTypes) {
            return 0;
        }
        
        const tower = TowerPlacement.getTowerById(towerId);
        
        if (!tower) {
            return 0;
        }
        
        return TowerTypes.getUpgradeCost(tower.type, tower.level);
    }
    
    /**
     * Get potential upgraded stats for a tower
     * @param {string} towerId - ID of the tower
     * @returns {Object|null} New stats after upgrade or null if tower not found
     */
    function getUpgradedStats(towerId) {
        if (!window.TowerPlacement || !window.TowerTypes) {
            return null;
        }
        
        const tower = TowerPlacement.getTowerById(towerId);
        
        if (!tower) {
            return null;
        }
        
        return TowerTypes.getUpgradedStats(tower);
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for tower click events to show upgrade UI
        EventSystem.subscribe("tower:clicked", function(towerId) {
            showUpgradeUI(towerId);
        });
        
        // Listen for upgrade confirmation
        EventSystem.subscribe("tower:upgrade:confirm", function(towerId) {
            upgradeTower(towerId);
        });
    }
    
    // Initialize event listeners
    initEventListeners();
    
    // Public API
    return {
        upgradeTower,
        showUpgradeUI,
        getUpgradeCost,
        getUpgradedStats
    };
})();

// Make module available globally
window.TowerUpgrades = TowerUpgrades;