/**
 * types.js - Defines tower types and their properties
 * This module contains the configuration for different tower types
 * including their stats, costs, and emoji representations.
 */

const TowerTypes = (function() {
    // Tower types with their properties
    const towerTypes = {
        // Number towers
        1: { 
            emoji: '1️⃣', 
            damage: 60, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 30,
            description: "Attacks enemies with value 1"
        },
        2: { 
            emoji: '2️⃣', 
            damage: 70, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 30,
            description: "Attacks enemies with value 2" 
        },
        3: { 
            emoji: '3️⃣', 
            damage: 80, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 30,
            description: "Attacks enemies with value 3" 
        },
        4: { 
            emoji: '4️⃣', 
            damage: 90, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 35,
            description: "Attacks enemies with value 4" 
        },
        5: { 
            emoji: '5️⃣', 
            damage: 100, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 35,
            description: "Attacks enemies with value 5" 
        },
        6: { 
            emoji: '6️⃣', 
            damage: 110, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 35,
            description: "Attacks enemies with value 6" 
        },
        7: { 
            emoji: '7️⃣', 
            damage: 120, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 40,
            description: "Attacks enemies with value 7" 
        },
        8: { 
            emoji: '8️⃣', 
            damage: 130, 
            range: 2.5, 
            attackSpeed: 0.7, 
            cost: 40,
            description: "Attacks enemies with value 8" 
        },
        9: { 
            emoji: '9️⃣', 
            damage: 140, 
            range: 3.0, 
            attackSpeed: 0.7, 
            cost: 40,
            description: "Attacks enemies with value 9" 
        },
        // Special tower
        'special': { 
            emoji: '🔮', 
            damage: 80, 
            range: 4.0, 
            attackSpeed: 0.3, 
            cost: 100,
            description: "Attacks all enemy types" 
        }
    };
    
    /**
     * Get a tower type by ID
     * @param {string|number} towerType - Tower type ID
     * @returns {Object|null} Tower type data or null if not found
     */
    function getTowerType(towerType) {
        return towerTypes[towerType] ? { ...towerTypes[towerType] } : null;
    }
    
    /**
     * Get the cost of a tower type
     * @param {string|number} towerType - Tower type ID
     * @returns {number} Cost of the tower or 0 if not found
     */
    function getTowerCost(towerType) {
        return towerTypes[towerType] ? towerTypes[towerType].cost : 0;
    }
    
    /**
     * Get all tower types
     * @returns {Object} Copy of all tower types
     */
    function getAllTowerTypes() {
        return { ...towerTypes };
    }
    
    /**
     * Calculate upgrade cost for a tower
     * @param {string|number} towerType - Tower type ID
     * @param {number} currentLevel - Current tower level
     * @returns {number} Cost to upgrade the tower
     */
    function getUpgradeCost(towerType, currentLevel) {
        const baseTower = towerTypes[towerType];
        if (!baseTower) return 0;
        
        // Upgrade cost scales with level
        return Math.floor(baseTower.cost * 0.75 * currentLevel);
    }
    
    /**
     * Get upgraded stats for a tower
     * @param {Object} tower - Current tower object
     * @returns {Object} New stats after upgrade
     */
    function getUpgradedStats(tower) {
        return {
            damage: Math.floor(tower.damage * 1.8),
            range: Math.floor(tower.range * 1.3),
            attackSpeed: tower.attackSpeed * 0.7
        };
    }
    
    // Public API
    return {
        getTowerType,
        getTowerCost,
        getAllTowerTypes,
        getUpgradeCost,
        getUpgradedStats
    };
})();

// Make module available globally
window.TowerTypes = TowerTypes;